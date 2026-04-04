from datetime import date

from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from services.environment_service import get_environment
from services.fraud_engine import validate_claim
from services.ml_service import (
    expected_loss_prediction,
    get_latest_user_behavior,
    record_claim_learning,
    update_model_weights,
    update_user_behavior,
)
from services.policy_service import create_claim_record, get_claimable_policy
from services.premium_engine import baseline_value, calculate_weekly_premium, resolve_city_from_coordinates
from services.risk_engine import calculate_risk


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _today_income_payload(user_id: int, db: Session) -> dict:
    record = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .first()
    )
    if not record:
        return {
            'earnings': 0.0,
            'orders_completed': 0,
            'hours_worked': 0.0,
            'disruption_type': 'none',
            'platform': 'swiggy',
        }
    return {
        'earnings': float(record.earnings),
        'orders_completed': int(record.orders_completed),
        'hours_worked': float(record.hours_worked),
        'disruption_type': record.disruption_type,
        'platform': record.platform,
    }


def check_user_eligibility(user_id: int, db: Session) -> dict:
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc())
        .all()
    )
    if len(records) < 7:
        return {'eligible': False, 'reason': 'At least 7 days of gig data is required'}

    baseline = baseline_value(user_id, db)
    if baseline <= 0:
        return {'eligible': False, 'reason': 'Valid baseline income is required'}

    return {'eligible': True, 'reason': ''}


def _reject_response(
    *,
    status: str,
    reason: str,
    claim_id: str,
    expected_income: float | None,
    actual_income: float | None,
    predicted_loss: float | None,
    fraud_score: float | None,
    confidence: float | None,
    reasons: list[str] | None = None,
) -> dict:
    return {
        'claim_status': status,
        'reason': reason,
        'status': status,
        'expected_income': expected_income,
        'actual_income': actual_income,
        'weekly_loss': 0.0,
        'loss': 0.0,
        'payout': 0.0,
        'predicted_loss': predicted_loss,
        'fraud_score': fraud_score,
        'confidence': confidence,
        'claim_id': claim_id,
        'reasons': reasons or [reason],
    }


def _compute_fraud_assessment(
    *,
    baseline_income: float,
    predicted_loss: float,
    actual_loss: float,
    active_triggers: list[str],
    behavior_snapshot: dict,
    validation_result: dict,
) -> dict:
    safe_baseline = max(float(baseline_income or 0.0), 1.0)
    base_anomaly = abs(float(actual_loss) - float(predicted_loss)) / safe_baseline

    avg_loss = float((behavior_snapshot or {}).get('avg_loss', 0.0) or 0.0)
    behavior_deviation = 0.0 if avg_loss <= 0 else abs(float(actual_loss) - avg_loss) / safe_baseline

    validation_signals = (validation_result or {}).get('signals') or {}
    trigger_mismatch = 0.0
    if not active_triggers:
        trigger_mismatch = 1.0
    elif not bool(validation_result.get('is_valid', True)):
        trigger_mismatch = max(
            float(validation_signals.get('weather_check', 0.0) or 0.0),
            float(validation_signals.get('location_check', 0.0) or 0.0),
            float(validation_signals.get('activity_check', 0.0) or 0.0),
        )

    fraud_score = min(
        1.0,
        (0.5 * base_anomaly)
        + (0.3 * min(behavior_deviation, 1.0))
        + (0.2 * min(trigger_mismatch, 1.0)),
    )

    if fraud_score < 0.4:
        claim_status = 'APPROVED'
    elif fraud_score <= 0.7:
        claim_status = 'FLAGGED'
    else:
        claim_status = 'REJECTED'

    confidence = min(
        1.0,
        0.45
        + (0.25 if active_triggers else 0.0)
        + (0.2 if behavior_snapshot else 0.0)
        + (0.1 if validation_signals else 0.0),
    )

    reasons: list[str] = []
    if base_anomaly >= 0.25:
        reasons.append('Actual loss differs significantly from ML-predicted loss')
    if behavior_deviation >= 0.25:
        reasons.append('Claim deviates from the user loss behavior pattern')
    if trigger_mismatch >= 0.25:
        reasons.append('Trigger pattern does not fully support the claim')
    if not reasons:
        reasons.append('Claim pattern is consistent with expected disruption behavior')

    return {
        'fraud_score': _round(fraud_score),
        'confidence': _round(confidence),
        'claim_status': claim_status,
        'reasons': reasons,
    }


def process_claim(user_id: int, db: Session, lat: float, lon: float) -> dict:
    eligibility = check_user_eligibility(user_id, db)
    if not eligibility['eligible']:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=date.today().strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=1.0,
            status='REJECTED',
            reasons=[eligibility['reason']],
        )
        return _reject_response(
            status='REJECTED',
            reason=eligibility['reason'],
            claim_id=f'claim_{claim.id}',
            expected_income=None,
            actual_income=None,
            predicted_loss=None,
            fraud_score=1.0,
            confidence=1.0,
        )

    policy = get_claimable_policy(user_id, db)
    if policy is None or not policy.premium_paid:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=date.today().strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=1.0,
            status='REJECTED',
            reasons=['No completed policy week is available to claim yet'],
        )
        return _reject_response(
            status='REJECTED',
            reason='No completed policy week is available to claim yet',
            claim_id=f'claim_{claim.id}',
            expected_income=None,
            actual_income=None,
            predicted_loss=None,
            fraud_score=1.0,
            confidence=1.0,
        )

    environment_data = get_environment(lat, lon, db=db, user_id=user_id)
    environment_data['city'] = resolve_city_from_coordinates(lat, lon)
    today_income = _today_income_payload(user_id, db)
    expected_income = _round(baseline_value(user_id, db))
    actual_income = _round(float(today_income.get('earnings', 0.0) or 0.0))

    risk_result = calculate_risk(environment_data, user_id=user_id, db=db, today_income=today_income)
    premium_result = calculate_weekly_premium(user_id=user_id, lat=lat, lon=lon, db=db)
    fraud_result = validate_claim(
        user_id=user_id,
        db=db,
        environment_data=environment_data,
        today_income=today_income,
    )

    active_triggers = [str(item) for item in (risk_result.get('active_triggers') or [])]
    loss = _round(max(0.0, expected_income - actual_income))
    predicted_loss = expected_loss_prediction(
        float(risk_result.get('risk_score', 0.0) or 0.0),
        expected_income,
    )
    claim_date = policy.end_date
    behavior_snapshot = get_latest_user_behavior(db, user_id=user_id)
    fraud_assessment = _compute_fraud_assessment(
        baseline_income=expected_income,
        predicted_loss=predicted_loss,
        actual_loss=loss,
        active_triggers=active_triggers,
        behavior_snapshot=behavior_snapshot,
        validation_result=fraud_result,
    )

    if not active_triggers:
        reasons = ['No active disruption triggers were detected', *fraud_assessment['reasons']]
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=policy.start_date.strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=float(fraud_assessment['fraud_score']),
            status='REJECTED',
            reasons=reasons,
        )
        record_claim_learning(
            db,
            user_id=user_id,
            policy_id=policy.id,
            risk_snapshot_id=None,
            claim_date=claim_date,
            status='REJECTED',
            risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
            baseline_income=expected_income,
            actual_loss=0.0,
            approved_payout=0.0,
            triggers=active_triggers,
            reasons=reasons,
            fraud_score=float(fraud_assessment['fraud_score']),
            review_notes='Claim rejected because no active triggers were present',
        )
        update_model_weights(db, user_id=user_id)
        update_user_behavior(db, user_id=user_id)
        db.commit()
        return _reject_response(
            status='REJECTED',
            reason=reasons[0],
            claim_id=f'claim_{claim.id}',
            expected_income=expected_income,
            actual_income=actual_income,
            predicted_loss=predicted_loss,
            fraud_score=float(fraud_assessment['fraud_score']),
            confidence=float(fraud_assessment['confidence']),
            reasons=reasons,
        )

    if fraud_assessment['claim_status'] != 'APPROVED':
        status = 'FLAGGED' if fraud_assessment['claim_status'] == 'FLAGGED' else 'REJECTED'
        reasons = fraud_assessment['reasons']
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=policy.start_date.strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=float(fraud_assessment['fraud_score']),
            status=status,
            reasons=reasons,
        )
        record_claim_learning(
            db,
            user_id=user_id,
            policy_id=policy.id,
            risk_snapshot_id=None,
            claim_date=claim_date,
            status=status,
            risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
            baseline_income=expected_income,
            actual_loss=0.0,
            approved_payout=0.0,
            triggers=active_triggers,
            reasons=reasons,
            fraud_score=float(fraud_assessment['fraud_score']),
            review_notes='Anomaly-based fraud scoring blocked approval',
        )
        update_model_weights(db, user_id=user_id)
        update_user_behavior(db, user_id=user_id)
        db.commit()
        return _reject_response(
            status=status,
            reason=reasons[0],
            claim_id=f'claim_{claim.id}',
            expected_income=expected_income,
            actual_income=actual_income,
            predicted_loss=predicted_loss,
            fraud_score=float(fraud_assessment['fraud_score']),
            confidence=float(fraud_assessment['confidence']),
            reasons=reasons,
        )

    if loss <= 0:
        reasons = ['No eligible income loss detected']
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=policy.start_date.strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=float(fraud_assessment['fraud_score']),
            status='REJECTED',
            reasons=reasons,
        )
        record_claim_learning(
            db,
            user_id=user_id,
            policy_id=policy.id,
            risk_snapshot_id=None,
            claim_date=claim_date,
            status='REJECTED',
            risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
            baseline_income=expected_income,
            actual_loss=0.0,
            approved_payout=0.0,
            triggers=active_triggers,
            reasons=reasons,
            fraud_score=float(fraud_assessment['fraud_score']),
            review_notes='Expected income was not higher than actual income',
        )
        update_model_weights(db, user_id=user_id)
        update_user_behavior(db, user_id=user_id)
        db.commit()
        return _reject_response(
            status='REJECTED',
            reason=reasons[0],
            claim_id=f'claim_{claim.id}',
            expected_income=expected_income,
            actual_income=actual_income,
            predicted_loss=predicted_loss,
            fraud_score=float(fraud_assessment['fraud_score']),
            confidence=float(fraud_assessment['confidence']),
            reasons=reasons,
        )

    payout = _round(loss * 0.8)
    payout = min(payout, _round(float(premium_result.get('coverage', payout) or payout)))
    approval_reason = 'Claim approved using income loss, active triggers, ML prediction, and anomaly fraud checks'
    claim = create_claim_record(
        user_id=user_id,
        db=db,
        week=policy.start_date.strftime('%G-W%V'),
        loss=loss,
        payout=payout,
        fraud_score=float(fraud_assessment['fraud_score']),
        status='APPROVED',
        reasons=[approval_reason, *fraud_assessment['reasons']],
    )
    record_claim_learning(
        db,
        user_id=user_id,
        policy_id=policy.id,
        risk_snapshot_id=None,
        claim_date=claim_date,
        status='APPROVED',
        risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
        baseline_income=expected_income,
        actual_loss=loss,
        approved_payout=payout,
        triggers=active_triggers,
        reasons=[approval_reason, *fraud_assessment['reasons']],
        fraud_score=float(fraud_assessment['fraud_score']),
        review_notes='Approved claim used for adaptive learning',
    )
    update_model_weights(db, user_id=user_id)
    update_user_behavior(db, user_id=user_id)
    db.commit()
    return {
        'claim_status': 'APPROVED',
        'reason': approval_reason,
        'status': 'APPROVED',
        'expected_income': expected_income,
        'actual_income': actual_income,
        'claim_id': f'claim_{claim.id}',
        'weekly_loss': loss,
        'loss': loss,
        'payout': payout,
        'predicted_loss': predicted_loss,
        'fraud_score': float(fraud_assessment['fraud_score']),
        'confidence': float(fraud_assessment['confidence']),
        'reasons': [approval_reason, *fraud_assessment['reasons']],
    }
