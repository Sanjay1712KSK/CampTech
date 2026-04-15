import logging
import os
from uuid import uuid4
from datetime import UTC, datetime

import requests
from dotenv import load_dotenv
from sqlalchemy.orm import Session

from models.models import BlockchainRecord

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

logger = logging.getLogger('gig_insurance_backend.blockchain_service')

BLOCKCHAIN_MODE = (os.getenv('BLOCKCHAIN_MODE') or 'mock').strip().lower()
NBFLITE_BASE_URL = (os.getenv('NBFLITE_BASE_URL') or '').strip()
NBFLITE_API_KEY = (os.getenv('NBFLITE_API_KEY') or '').strip()
NBFLITE_TIMEOUT = int(os.getenv('NBFLITE_TIMEOUT') or 5)


def _safe_int(value) -> int | None:
    try:
        return int(value) if value is not None else None
    except (TypeError, ValueError):
        return None


def _resolve_reference_id(payload: dict) -> str | None:
    for key in ('reference_id', 'claim_id', 'policy_id', 'request_id', 'transaction_id', 'user_id'):
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value)
    return None


def mock_store(record_type: str, data: dict) -> dict:
    tx_hash = f'mock_{uuid4().hex}'
    return {
        'tx_hash': tx_hash,
        'status': 'stored_mock',
        'network': 'mock',
        'raw': None,
        'fallback': True,
    }


def nbflite_store(record_type: str, data: dict) -> dict:
    if not NBFLITE_BASE_URL:
        logger.warning('NBFLite mode requested but NBFLITE_BASE_URL is missing. Falling back to mock storage.')
        result = mock_store(record_type, data)
        result['status'] = 'stored_mock_fallback'
        result['error'] = 'NBFLITE_BASE_URL_MISSING'
        return result

    payload = {
        'type': record_type,
        'data': data,
    }

    try:
        response = requests.post(
            NBFLITE_BASE_URL,
            json=payload,
            headers={'Authorization': NBFLITE_API_KEY},
            timeout=NBFLITE_TIMEOUT,
        )
        response.raise_for_status()
        body = response.json() if response.content else {}
        tx_hash = str(
            body.get('tx_hash')
            or body.get('transaction_hash')
            or body.get('transaction_id')
            or f'nbflite_{uuid4().hex}'
        )
        return {
            'tx_hash': tx_hash,
            'status': str(body.get('status') or 'stored_nbflite'),
            'network': 'nbflite',
            'raw': body,
            'fallback': False,
            'block_number': body.get('block_number'),
        }
    except Exception as exc:
        logger.exception('NBFLite store failed for record_type=%s. Falling back to mock mode.', record_type)
        result = mock_store(record_type, data)
        result['status'] = 'stored_mock_fallback'
        result['error'] = str(exc)
        result['network'] = 'nbflite_fallback'
        return result


def _persist_record(db: Session | None, record_type: str, data: dict, result: dict) -> BlockchainRecord | None:
    if db is None:
        return None

    payload = data or {}
    tx_hash = str(result.get('tx_hash') or f'mock_{uuid4().hex}')
    record = BlockchainRecord(
        user_id=_safe_int(payload.get('user_id')),
        policy_id=_safe_int(payload.get('policy_id')),
        claim_history_id=_safe_int(payload.get('claim_history_id')),
        digilocker_request_id=_safe_int(payload.get('digilocker_request_id')),
        record_type=record_type,
        reference_id=_resolve_reference_id(payload),
        tx_hash=tx_hash,
        data=payload,
        transaction_type=record_type,
        transaction_hash=tx_hash,
        network=str(result.get('network') or BLOCKCHAIN_MODE or 'mock'),
        block_number=str(result.get('block_number')) if result.get('block_number') is not None else None,
        status=str(result.get('status') or 'stored'),
        payload=payload,
    )
    db.add(record)
    db.flush()
    return record


def store_on_blockchain(record_type: str, data: dict, db: Session | None = None) -> dict:
    record_type = str(record_type or 'generic_record').strip().lower()
    payload = dict(data or {})

    if BLOCKCHAIN_MODE == 'nbflite':
        result = nbflite_store(record_type, payload)
    else:
        result = mock_store(record_type, payload)

    record = _persist_record(db, record_type, payload, result)
    tx_hash = str(result.get('tx_hash'))
    response = {
        'success': not bool(result.get('fallback', False)),
        'tx_hash': tx_hash,
        'transaction_id': tx_hash,
        'status': result.get('status'),
        'network': result.get('network'),
        'raw': result.get('raw'),
        'record_id': record.id if record else None,
        'timestamp': datetime.now(UTC).replace(tzinfo=None).isoformat(),
    }
    if result.get('error'):
        response['error'] = result.get('error')
    return response


def log_event(
    event_type: str,
    entity_id: str,
    data: dict,
    metadata: dict | None = None,
    db: Session | None = None,
) -> dict:
    payload = dict(data or {})
    if entity_id and 'reference_id' not in payload:
        payload['reference_id'] = entity_id
    if metadata:
        payload['metadata'] = metadata
    return store_on_blockchain(record_type=event_type, data=payload, db=db)


def log_to_blockchain(event_type: str, payload: dict, db: Session | None = None) -> dict:
    entity_id = str(
        payload.get('reference_id')
        or payload.get('transaction_id')
        or payload.get('claim_id')
        or payload.get('policy_id')
        or payload.get('request_id')
        or payload.get('user_id')
        or f'{event_type}_{uuid4().hex}'
    )
    return log_event(
        event_type=event_type,
        entity_id=entity_id,
        data=payload,
        metadata={'source': 'gig_insurance_backend'},
        db=db,
    )


def log_verification(user_id: int, db: Session | None = None, digilocker_request_id: int | None = None) -> dict:
    return store_on_blockchain(
        record_type='identity_verification',
        data={
            'user_id': user_id,
            'digilocker_request_id': digilocker_request_id,
            'reference_id': f'user_{user_id}',
            'status': 'VERIFIED',
        },
        db=db,
    )


def create_policy_record(
    user_id: int,
    premium: float,
    baseline_income: float,
    policy_id: int | None = None,
    db: Session | None = None,
) -> dict:
    return store_on_blockchain(
        record_type='policy',
        data={
            'user_id': user_id,
            'policy_id': policy_id,
            'reference_id': policy_id or f'user_{user_id}_policy',
            'premium': premium,
            'baseline_income': baseline_income,
        },
        db=db,
    )


def log_claim(claim_id: str, details: dict, db: Session | None = None) -> dict:
    payload = dict(details or {})
    payload.setdefault('claim_id', claim_id)
    payload.setdefault('reference_id', claim_id)
    return store_on_blockchain(record_type='claim', data=payload, db=db)


def record_payout(claim_id: str, amount: float, user_id: int | None = None, db: Session | None = None) -> dict:
    return store_on_blockchain(
        record_type='payout',
        data={
            'user_id': user_id,
            'claim_id': claim_id,
            'reference_id': claim_id,
            'amount': amount,
            'status': 'PAID',
        },
        db=db,
    )
