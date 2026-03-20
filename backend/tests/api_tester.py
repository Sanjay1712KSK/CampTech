import json
import time
from typing import Any

import requests


BASE_URL = 'http://127.0.0.1:8000'
TIMEOUT_SECONDS = 10

SIGNUP_PAYLOAD = {
    'name': 'Guidewire User',
    'email': 'guidewire_user@test.com',
    'phone': '9123456789',
    'password': 'securePass123',
}

LOGIN_PAYLOAD = {
    'email': 'guidewire_user@test.com',
    'password': 'securePass123',
}

ENVIRONMENT_PARAMS = {
    'lat': 13.0827,
    'lon': 80.2707,
}

VALID_AADHAAR_NUMBER = '123456789012'
MOCK_AADHAAR_NAME = 'Sanju'


def pretty_json(payload: Any) -> str:
    try:
        return json.dumps(payload, indent=2, ensure_ascii=True)
    except TypeError:
        return str(payload)


def print_response(label: str, status_code: int | None, elapsed_ms: int | None, body: Any) -> None:
    status_text = f'HTTP {status_code}' if status_code is not None else 'NO RESPONSE'
    timing_text = f' | {elapsed_ms}ms' if elapsed_ms is not None else ''
    print(f'[RESPONSE] {label} -> {status_text}{timing_text}')
    print(pretty_json(body))


def perform_request(
    session: requests.Session,
    method: str,
    path: str,
    *,
    label: str,
    json_body: dict[str, Any] | None = None,
    params: dict[str, Any] | None = None,
) -> tuple[bool, Any, int | None, int | None]:
    url = f'{BASE_URL}{path}'
    started = time.perf_counter()

    try:
        response = session.request(
            method=method,
            url=url,
            json=json_body,
            params=params,
            timeout=TIMEOUT_SECONDS,
        )
        elapsed_ms = int((time.perf_counter() - started) * 1000)
    except requests.RequestException as exc:
        print(f'[ERROR] {label} failed -> {exc}')
        print_response(label, None, None, {'error': True, 'message': str(exc)})
        return False, None, None, None

    try:
        body = response.json()
    except ValueError:
        body = response.text

    if 200 <= response.status_code < 300:
        print(f'[TEST] {label} -> SUCCESS ({elapsed_ms}ms)')
        print_response(label, response.status_code, elapsed_ms, body)
        return True, body, response.status_code, elapsed_ms

    print(f'[ERROR] {label} failed -> HTTP {response.status_code}')
    print_response(label, response.status_code, elapsed_ms, body)
    return False, body, response.status_code, elapsed_ms


def extract_user_id(signup_body: Any, login_body: Any) -> int | None:
    for payload in (signup_body, login_body):
        if isinstance(payload, dict) and isinstance(payload.get('id'), int):
            return payload['id']
    return None


def run_signup(session: requests.Session) -> tuple[int | None, Any]:
    ok, body, _, _ = perform_request(
        session,
        'POST',
        '/auth/signup',
        label='Signup',
        json_body=SIGNUP_PAYLOAD,
    )
    return (body.get('id') if ok and isinstance(body, dict) else None), body


def run_login(session: requests.Session) -> tuple[int | None, Any]:
    ok, body, _, _ = perform_request(
        session,
        'POST',
        '/auth/login',
        label='Login',
        json_body=LOGIN_PAYLOAD,
    )
    return (body.get('id') if ok and isinstance(body, dict) else None), body


def run_digilocker(session: requests.Session, user_id: int | None) -> None:
    if user_id is None:
        print('[ERROR] DigiLocker skipped -> user_id unavailable')
        return

    ok, request_body, _, _ = perform_request(
        session,
        'POST',
        '/digilocker/request',
        label='DigiLocker Request',
        json_body={'user_id': user_id},
    )
    if not ok or not isinstance(request_body, dict):
        return

    request_id = request_body.get('request_id')
    if not request_id:
        print('[ERROR] DigiLocker failed -> request_id missing in response')
        return

    primary_payload = {
        'request_id': request_id,
        'document_type': 'aadhaar',
        'document_number': VALID_AADHAAR_NUMBER,
        'name': SIGNUP_PAYLOAD['name'],
    }
    ok, consent_body, _, elapsed_ms = perform_request(
        session,
        'POST',
        '/digilocker/consent',
        label='DigiLocker Consent',
        json_body=primary_payload,
    )

    if ok and isinstance(consent_body, dict) and consent_body.get('status') == 'VERIFIED':
        print(f'[TEST] DigiLocker -> VERIFIED ({elapsed_ms}ms)')
        return

    print('[ERROR] DigiLocker verification mismatch -> retrying with known valid mock identity')

    ok, consent_body, _, elapsed_ms = perform_request(
        session,
        'POST',
        '/digilocker/consent',
        label='DigiLocker Consent Retry',
        json_body={
            'request_id': request_id,
            'document_type': 'aadhaar',
            'document_number': VALID_AADHAAR_NUMBER,
            'name': MOCK_AADHAAR_NAME,
        },
    )

    if ok and isinstance(consent_body, dict) and consent_body.get('status') == 'VERIFIED':
        print(f'[TEST] DigiLocker -> VERIFIED ({elapsed_ms}ms)')
    elif isinstance(consent_body, dict):
        print(f"[ERROR] DigiLocker failed -> {consent_body.get('reason', 'Unknown failure')}")


def run_environment(session: requests.Session) -> None:
    ok, _, _, elapsed_ms = perform_request(
        session,
        'GET',
        '/environment',
        label='Environment',
        params=ENVIRONMENT_PARAMS,
    )
    if ok:
        print(f'[TEST] Environment -> OK ({elapsed_ms}ms)')


def run_risk(session: requests.Session, user_id: int | None) -> None:
    params = dict(ENVIRONMENT_PARAMS)
    if user_id is not None:
        params['user_id'] = user_id

    ok, _, _, elapsed_ms = perform_request(
        session,
        'GET',
        '/risk',
        label='Risk',
        params=params,
    )
    if ok:
        print(f'[TEST] Risk -> OK ({elapsed_ms}ms)')


def run_gig_generate(session: requests.Session, user_id: int | None) -> None:
    if user_id is None:
        print('[ERROR] Gig Data skipped -> user_id unavailable')
        return

    ok, body, _, elapsed_ms = perform_request(
        session,
        'POST',
        '/gig/generate-data',
        label='Gig Data',
        json_body={'user_id': user_id, 'days': 30},
    )
    if ok and isinstance(body, dict):
        generated = body.get('generated', 0)
        print(f'[TEST] Gig Data -> GENERATED {generated} days ({elapsed_ms}ms)')


def run_gig_history(session: requests.Session, user_id: int | None) -> None:
    if user_id is None:
        print('[ERROR] Gig History skipped -> user_id unavailable')
        return

    ok, body, _, elapsed_ms = perform_request(
        session,
        'GET',
        '/gig/income-history',
        label='Gig History',
        params={'user_id': user_id},
    )
    if ok:
        count = len(body) if isinstance(body, list) else 0
        print(f'[TEST] Gig History -> OK ({count} records, {elapsed_ms}ms)')


def run_today_income(session: requests.Session, user_id: int | None) -> None:
    if user_id is None:
        print('[ERROR] Today Income skipped -> user_id unavailable')
        return

    ok, _, _, elapsed_ms = perform_request(
        session,
        'GET',
        '/gig/today-income',
        label='Today Income',
        params={'user_id': user_id},
    )
    if ok:
        print(f'[TEST] Today Income -> OK ({elapsed_ms}ms)')


def run_baseline_income(session: requests.Session, user_id: int | None) -> None:
    if user_id is None:
        print('[ERROR] Baseline Income skipped -> user_id unavailable')
        return

    ok, _, _, elapsed_ms = perform_request(
        session,
        'GET',
        '/gig/baseline-income',
        label='Baseline Income',
        params={'user_id': user_id},
    )
    if ok:
        print(f'[TEST] Baseline Income -> OK ({elapsed_ms}ms)')


def main() -> None:
    print(f'API tester started for {BASE_URL}')
    print('-' * 60)

    with requests.Session() as session:
        signup_user_id, signup_body = run_signup(session)
        login_user_id, login_body = run_login(session)
        user_id = extract_user_id(signup_body, login_body)

        if user_id is None and signup_user_id is not None:
            user_id = signup_user_id
        if user_id is None and login_user_id is not None:
            user_id = login_user_id

        if user_id is not None:
            print(f'[INFO] Using user_id -> {user_id}')
        else:
            print('[ERROR] Could not determine user_id from signup/login responses')

        run_digilocker(session, user_id)
        run_environment(session)
        run_risk(session, user_id)
        run_gig_generate(session, user_id)
        run_gig_history(session, user_id)
        run_today_income(session, user_id)
        run_baseline_income(session, user_id)

    print('-' * 60)
    print('API tester finished')


if __name__ == '__main__':
    main()
