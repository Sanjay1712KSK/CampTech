import json

from sqlalchemy.orm import Session

from models.insurance import Claim
from models.user_model import User


def generate_support_response(user_id: int, query: str, db: Session) -> str:
    user = db.query(User).filter(User.id == int(user_id)).first()
    latest_claim = (
        db.query(Claim)
        .filter(Claim.user_id == int(user_id))
        .order_by(Claim.created_at.desc(), Claim.id.desc())
        .first()
    )
    normalized_query = query.strip().lower()
    user_name = user.name if user else 'there'

    if latest_claim is None:
        return (
            f'Hi {user_name}, I could not find a recent claim on your account. '
            'You can buy a weekly policy, wait for the policy period to end, and then submit a claim after a real disruption week.'
        )

    reasons = []
    if latest_claim.reasons_json:
        try:
            reasons = json.loads(latest_claim.reasons_json)
        except json.JSONDecodeError:
            reasons = [latest_claim.reasons_json]

    if latest_claim.status.upper() == 'REJECTED':
        primary_reason = reasons[0] if reasons else 'the validation checks were not satisfied'
        if 'why' in normalized_query or 'reject' in normalized_query:
            return (
                f'Your latest claim was rejected because {primary_reason.lower()}. '
                'Please review your disruption evidence, keep city-consistent work history, and wait until the policy period ends before claiming again.'
            )
        return (
            f'Your latest claim is currently rejected. The main reason is: {primary_reason}. '
            'Next steps: verify your DigiLocker profile, keep at least 7 days of gig data, and contact support if you believe the weather or income data is incorrect.'
        )

    if latest_claim.status.upper() == 'APPROVED':
        return (
            f'Good news, {user_name}. Your latest claim was approved with a payout of Rs {latest_claim.payout:.0f}. '
            'You can check your bank section for the credited amount and your profile for updated financial totals.'
        )

    if latest_claim.status.upper() == 'NEEDS_REVIEW':
        return (
            'Your claim has been escalated for manual review because the fraud signals were borderline. '
            'Please keep your location permissions on, verify your identity, and contact support with any additional disruption proof.'
        )

    return (
        'I found a recent claim on your account, but it still needs attention. '
        'Please review the claim status, policy dates, and bank details before trying again.'
    )
