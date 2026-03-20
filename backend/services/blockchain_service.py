import os
import logging
import uuid
import time
from datetime import datetime
from urllib.parse import urlparse

import requests
from dotenv import load_dotenv
from services.blockchain_payload_builder import build_payload

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

logger = logging.getLogger('blockchain_service')
logger.setLevel(logging.INFO)

NBF_BASE_URL = os.getenv('NBF_BASE_URL') or os.getenv('NBF_API_BASE_URL') or 'http://localhost:9000/api/invoke'
TIMEOUT = int(os.getenv('NBF_TIMEOUT') or os.getenv('NBF_REQUEST_TIMEOUT') or 2)
MAX_RETRIES = int(os.getenv('NBF_MAX_RETRIES') or os.getenv('NBF_RETRY_COUNT') or 1)


def _mock_blockchain_response(error: str | None = None) -> dict:
    return {
        'success': False,
        'transaction_id': f'MOCK_TXN_{uuid.uuid4()}',
        'raw': None,
        'fallback': True,
        'error': error,
    }


def _should_skip_live_blockchain() -> bool:
    parsed = urlparse(NBF_BASE_URL)
    hostname = (parsed.hostname or '').lower()

    if not hostname:
        return True

    # Demo/local development should not block API health on an external system.
    if hostname in {'localhost', '127.0.0.1'}:
        return True

    if hostname.endswith('example.com'):
        return True

    return False


def send_to_blockchain(payload: dict) -> dict:
    if not isinstance(payload, dict) or 'function' not in payload or 'args' not in payload:
        logger.error('Invalid payload for blockchain: %s', payload)
        return _mock_blockchain_response('INVALID_PAYLOAD')

    if _should_skip_live_blockchain():
        logger.info('Skipping live blockchain call for demo/local environment: %s', NBF_BASE_URL)
        return _mock_blockchain_response('BLOCKCHAIN_SKIPPED')

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
                    'transaction_id': body.get('transaction_id', f'MOCK_TXN_{uuid.uuid4()}'),
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

    fallback_txn = f'MOCK_TXN_{uuid.uuid4()}'
    logger.warning('Blockchain API all retries failed, returning fallback txn_id %s', fallback_txn)
    return {
        'success': False,
        'transaction_id': fallback_txn,
        'raw': None,
        'fallback': True,
    }


def log_event(event_type: str, entity_id: str, data: dict, metadata: dict = None) -> dict:
    try:
        payload = build_payload(event_type, entity_id, data, metadata)
        logger.info('Prepared blockchain event payload: %s', payload)
        return send_to_blockchain(payload)
    except ValueError as ex:
        logger.error('Blockchain payload validation failed: %s', str(ex))
        return _mock_blockchain_response(str(ex))


def log_to_blockchain(event_type: str, payload: dict) -> dict:
    entity_id = str(
        payload.get('transaction_id')
        or payload.get('claim_id')
        or payload.get('user_id')
        or f'{event_type}_{uuid.uuid4()}'
    )
    return log_event(
        event_type=event_type,
        entity_id=entity_id,
        data=payload,
        metadata={'source': 'gig_insurance_backend'},
    )


def log_verification(user_id: int) -> dict:
    return log_event(
        event_type='identity_verification',
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
