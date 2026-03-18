import logging
from datetime import datetime, timezone

logger = logging.getLogger('gig_insurance_backend.blockchain_payload_builder')

ALLOWED_EVENT_TYPES = {
    'verification',
    'policy_creation',
    'claim_submission',
    'payment',
    'risk_update',
    'user_update',
}


def build_payload(event_type: str, entity_id: str, data: dict, metadata: dict = None) -> dict:
    if not isinstance(event_type, str) or not event_type.strip():
        raise ValueError('event_type must be a non-empty string')

    event_type = event_type.strip().lower()
    if event_type not in ALLOWED_EVENT_TYPES:
        raise ValueError(f"event_type '{event_type}' is not allowed")

    if not isinstance(entity_id, str) or not entity_id.strip():
        raise ValueError('entity_id must be a non-empty string')

    if not isinstance(data, dict) or not data:
        raise ValueError('data must be a non-empty dict')

    if metadata is not None and not isinstance(metadata, dict):
        raise ValueError('metadata must be a dict if provided')

    timestamp = datetime.now(timezone.utc).isoformat()

    payload = {
        'function': 'createRecord',
        'args': {
            'event_type': event_type,
            'entity_id': entity_id.strip(),
            'timestamp': timestamp,
            'data': data,
            'metadata': metadata or {},
        },
    }

    logger.info('Built blockchain payload: %s', payload)
    return payload
