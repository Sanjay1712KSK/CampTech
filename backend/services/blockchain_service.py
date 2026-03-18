import os
import logging
import uuid
from datetime import datetime

import requests
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

logger = logging.getLogger('blockchain_service')
logger.setLevel(logging.INFO)

NBF_API_BASE_URL = os.getenv('NBF_API_BASE_URL', 'https://nbf.example.com/api')
NBF_API_KEY = os.getenv('NBF_API_KEY', 'test-api-key')

HEADERS = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {NBF_API_KEY}'
}


def _post(endpoint: str, payload: dict) -> dict:
    url = f"{NBF_API_BASE_URL.rstrip('/')}/{endpoint.lstrip('/')}"
    try:
        resp = requests.post(url, json=payload, headers=HEADERS, timeout=10)
        resp.raise_for_status()
        logger.info('NBF API success: %s %s', endpoint, resp.text)
        return resp.json()
    except requests.RequestException as ex:
        logger.warning('NBF API request failed: %s %s %s', endpoint, str(ex), payload)
        # Fallback: return best-effort simulation
        return {
            'status': 'simulated',
            'endpoint': endpoint,
            'payload': payload,
            'error': str(ex)
        }


def log_verification(user_id: int) -> dict:
    payload = {
        'user_id': user_id,
        'status': 'VERIFIED',
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }
    logger.info('Logging verification to blockchain: %s', payload)
    resp = _post('nbf/log-verification', payload)
    txn_id = resp.get('txn_id') or f"txn_mock_{uuid.uuid4()}"
    return {'status': 'simulated', 'txn_id': txn_id, 'provider': 'mock-blockchain'}


def create_policy(user_id: int, premium: float, baseline_income: float) -> dict:
    payload = {
        'user_id': user_id,
        'premium': premium,
        'baseline_income': baseline_income,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }
    logger.info('Creating policy on blockchain: %s', payload)
    return _post('nbf/create-policy', payload)


def log_event(event_type: str, conditions: dict, risk_score: float) -> dict:
    payload = {
        'event': event_type,
        'conditions': conditions,
        'risk_score': risk_score,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }
    logger.info('Logging event to blockchain: %s', payload)
    return _post('nbf/log-event', payload)


def record_payout(user_id: int, amount: float) -> dict:
    payload = {
        'user_id': user_id,
        'amount': amount,
        'status': 'PAID',
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }
    logger.info('Recording payout on blockchain: %s', payload)
    return _post('nbf/record-payout', payload)
