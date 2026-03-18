import os
import logging
import uuid
import time
from datetime import datetime

import requests
from dotenv import load_dotenv
from services.blockchain_payload_builder import build_payload

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

logger = logging.getLogger('blockchain_service')
logger.setLevel(logging.INFO)

NBF_BASE_URL = os.getenv('NBF_BASE_URL', 'http://localhost:9000/api/invoke')
TIMEOUT = int(os.getenv('NBF_TIMEOUT', 5))
MAX_RETRIES = int(os.getenv('NBF_MAX_RETRIES', 3))


def send_to_blockchain(payload: dict) -> dict:
    if not isinstance(payload, dict) or 'function' not in payload or 'args' not in payload:
        logger.error('Invalid payload for blockchain: %s', payload)
        raise ValueError('Invalid blockchain payload')

    logger.info('Sending payload to blockchain endpoint %s', NBF_BASE_URL)
    logger.debug('Blockchain payload: %s', payload)

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = requests.post(NBF_BASE_URL, json=payload, timeout=TIMEOUT)

            if response.status_code == 200:
                body = response.json() if response.content else {}
                logger.info('Blockchain API success on attempt %d: %s', attempt, body)
                return {
                    'success': True,
                    'transaction_id': body.get('transaction_id'),
                    'raw': body,
                    'fallback': False,
                }

            logger.warning('Blockchain API non-200 status %d on attempt %d', response.status_code, attempt)

        except requests.exceptions.Timeout as ex:
            logger.warning('Blockchain API timeout on attempt %d: %s', attempt, str(ex))
        except requests.exceptions.ConnectionError as ex:
            logger.warning('Blockchain API connection error on attempt %d: %s', attempt, str(ex))
        except Exception as ex:
            logger.exception('Blockchain API unexpected error on attempt %d: %s', attempt, str(ex))

        sleep_seconds = 2 ** (attempt - 1)
        logger.info('Retrying blockchain API in %s seconds', sleep_seconds)
        time.sleep(sleep_seconds)

    fallback_txn = f"MOCK_TXN_{uuid.uuid4()}"
    logger.warning('Blockchain API all retries failed, returning fallback txn_id %s', fallback_txn)
    return {
        'success': False,
        'transaction_id': fallback_txn,
        'raw': None,
        'fallback': True,
    }


def log_event(event_type: str, entity_id: str, data: dict, metadata: dict = None) -> dict:
    payload = build_payload(event_type, entity_id, data, metadata)
    logger.info('Prepared blockchain event payload: %s', payload)
    return send_to_blockchain(payload)


def log_verification(user_id: int) -> dict:
    return log_event(
        event_type='verification',
        entity_id=f'user_{user_id}',
        data={'user_id': user_id, 'status': 'VERIFIED'},
        metadata={'source': 'gig_insurance_backend'}
    )


def create_policy(user_id: int, premium: float, baseline_income: float) -> dict:
    return log_event(
        event_type='policy_creation',
        entity_id=f'user_{user_id}',
        data={'premium': premium, 'baseline_income': baseline_income},
        metadata={'source': 'gig_insurance_backend'}
    )


def log_claim(claim_id: str, details: dict) -> dict:
    return log_event(
        event_type='claim_trigger',
        entity_id=f'claim_{claim_id}',
        data=details,
        metadata={'source': 'gig_insurance_backend'}
    )


def record_payout(claim_id: str, amount: float) -> dict:
    return log_event(
        event_type='payout',
        entity_id=f'claim_{claim_id}',
        data={'amount': amount, 'status': 'PAID'},
        metadata={'source': 'gig_insurance_backend'}
    )


def log_verification(user_id: int) -> dict:
    payload = build_payload(
        event_type='verification',
        entity_id=str(user_id),
        data={
            'user_id': user_id,
            'status': 'VERIFIED',
        },
        metadata={'source': 'gig_insurance_backend'}
    )

    logger.info('Sending blockchain payload: %s', payload)
    resp = _post('nbf/log-verification', payload)
    txn_id = resp.get('txn_id') or f"txn_mock_{uuid.uuid4()}"
    return {'status': 'simulated', 'txn_id': txn_id, 'provider': 'mock-blockchain'}


def create_policy(user_id: int, premium: float, baseline_income: float) -> dict:
    payload = build_payload(
        event_type='policy_creation',
        entity_id=str(user_id),
        data={
            'premium': premium,
            'baseline_income': baseline_income,
        },
        metadata={'source': 'gig_insurance_backend'}
    )
    logger.info('Creating policy on blockchain: %s', payload)
    return _post('nbf/create-policy', payload)


def log_event(event_type: str, conditions: dict, risk_score: float) -> dict:
    payload = build_payload(
        event_type='risk_update',
        entity_id='system',
        data={
            'event_type': event_type,
            'conditions': conditions,
            'risk_score': risk_score,
        },
        metadata={'source': 'gig_insurance_backend'}
    )
    logger.info('Logging event to blockchain: %s', payload)
    return _post('nbf/log-event', payload)


def record_payout(user_id: int, amount: float) -> dict:
    payload = build_payload(
        event_type='payment',
        entity_id=str(user_id),
        data={
            'amount': amount,
            'status': 'PAID',
        },
        metadata={'source': 'gig_insurance_backend'}
    )
    logger.info('Recording payout on blockchain: %s', payload)
    return _post('nbf/record-payout', payload)
