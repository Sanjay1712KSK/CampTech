import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


BACKEND_DIR = Path(__file__).resolve().parents[1]

import sys

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from database.db import Base  # noqa: E402
from fastapi.security.http import HTTPAuthorizationCredentials  # noqa: E402
from models import bank_account as bank_account_model  # noqa: F401,E402
from models import digilocker_request as digilocker_request_model  # noqa: F401,E402
from models import gig_account as gig_account_model  # noqa: F401,E402
from models import gig_income as gig_income_model  # noqa: F401,E402
from models import insurance as insurance_model  # noqa: F401,E402
from models import profile as profile_model  # noqa: F401,E402
from models import user_model as user_model  # noqa: F401,E402
from models import verification as verification_model  # noqa: F401,E402
from routes import auth as auth_routes  # noqa: E402
from routes import digilocker as digilocker_routes  # noqa: E402
from routes import gig as gig_routes  # noqa: E402
from schemas.digilocker_schema import DigiLockerRequestSchema, DigiLockerVerifySchema  # noqa: E402
from schemas.gig_schema import GigConnectRequest  # noqa: E402
from schemas.user_schema import (  # noqa: E402
    ForgotPasswordRequest,
    FirstLoginOtpRequest,
    FirstLoginOtpVerifyRequest,
    LoginRequest,
    RegistrationRequest,
    ResetPasswordRequest,
    SendOtpRequest,
    VerifyOtpRequest,
    VerifyResetOtpRequest,
)


class AuthOnboardingTests(unittest.TestCase):
    def setUp(self):
        self.temp_db = tempfile.NamedTemporaryFile(suffix='.db', delete=False)
        self.temp_db.close()
        self.engine = create_engine(
            f'sqlite:///{self.temp_db.name}',
            connect_args={'check_same_thread': False},
            future=True,
        )
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine, future=True)
        Base.metadata.create_all(bind=self.engine)
        self.db = self.SessionLocal()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()
        if os.path.exists(self.temp_db.name):
            os.unlink(self.temp_db.name)

    def test_complete_onboarding_and_reset_flow(self):
        signup = auth_routes.signup(
            RegistrationRequest(
                email='worker@example.com',
                country_code='+91',
                phone_number='9876543210',
                username='worker.one',
                password='Secure@123',
            ),
            db=self.db,
        )
        user_id = signup['user_id']

        with (
            patch('services.auth_service._generate_otp', side_effect=['111111', '222222']),
            patch(
                'services.auth_service.send_email_otp',
                return_value={'channel': 'email', 'destination': 'wo***@example.com', 'mock_otp': None},
            ),
            patch(
                'services.auth_service.send_sms_otp',
                return_value={'channel': 'phone', 'destination': '987***210', 'mock_otp': '222222'},
            ),
            patch(
                'services.auth_service.send_confirmation_email',
                return_value={'channel': 'email', 'destination': 'wo***@example.com', 'confirmation_link': 'mock'},
            ),
        ):
            otp = auth_routes.send_otp(
                SendOtpRequest(user_id=user_id, purpose='signup'),
                db=self.db,
            )
            self.assertEqual(otp['deliveries'][0]['channel'], 'email')
            phone_otp = next(item['mock_otp'] for item in otp['deliveries'] if item['channel'] == 'phone')

            verify = auth_routes.verify_otp(
                VerifyOtpRequest(user_id=user_id, email_otp='111111', phone_otp=phone_otp),
                db=self.db,
            )
        self.assertTrue(verify['email_verified'])
        self.assertTrue(verify['phone_verified'])

        confirm = auth_routes.confirm_account(token=verify['confirmation_token'], db=self.db)
        self.assertTrue(confirm['account_confirmed'])

        digilocker_request = digilocker_routes.digilocker_request(
            DigiLockerRequestSchema(user_id=user_id, doc_type='aadhaar'),
            db=self.db,
        )
        digilocker_verify = digilocker_routes.digilocker_verify(
            DigiLockerVerifySchema(
                request_id=digilocker_request['request_id'],
                consent_code=digilocker_request['oauth_state'],
            ),
            db=self.db,
        )
        self.assertEqual(digilocker_verify['status'], 'VERIFIED')

        with (
            patch('services.auth_service._generate_otp', return_value='555555'),
            patch(
                'services.auth_service.send_email_otp',
                return_value={'channel': 'email', 'destination': 'wo***@example.com', 'mock_otp': None},
            ),
        ):
            login = auth_routes.login(
                LoginRequest(identifier='worker.one', password='Secure@123'),
                db=self.db,
            )
            self.assertTrue(login['requires_two_factor'])

            first_login_send = auth_routes.send_first_login_otp(
                FirstLoginOtpRequest(
                    challenge_token=login['two_factor_token'],
                    channel='email',
                ),
                db=self.db,
            )
            self.assertEqual(first_login_send['purpose'], 'first_login')

            verified_login = auth_routes.verify_first_login_otp(
                FirstLoginOtpVerifyRequest(
                    challenge_token=login['two_factor_token'],
                    channel='email',
                    otp='555555',
                ),
                db=self.db,
            )

        token = verified_login['access_token']
        me = auth_routes.me(
            credentials=HTTPAuthorizationCredentials(scheme='Bearer', credentials=token),
            db=self.db,
        )
        self.assertTrue(me['is_digilocker_verified'])
        self.assertTrue(me['has_completed_first_login_2fa'])

        with patch('services.gig_service.SessionLocal', self.SessionLocal):
            connect = gig_routes.connect_gig_account_endpoint(
                GigConnectRequest(user_id=user_id, platform='swiggy', partner_id='SWG-123'),
                db=self.db,
            )
        self.assertEqual(connect['status'], 'CONNECTED')

        with (
            patch('services.auth_service._generate_otp', side_effect=['333333', '444444']),
            patch(
                'services.auth_service.send_email_otp',
                return_value={'channel': 'email', 'destination': 'wo***@example.com', 'mock_otp': None},
            ),
            patch(
                'services.auth_service.send_sms_otp',
                return_value={'channel': 'phone', 'destination': '987***210', 'mock_otp': '444444'},
            ),
        ):
            forgot = auth_routes.forgot_password(
                ForgotPasswordRequest(identifier='worker.one'),
                db=self.db,
            )
            reset_phone_otp = next(item['mock_otp'] for item in forgot['deliveries'] if item['channel'] == 'phone')

            verify_reset = auth_routes.verify_reset_otp(
                VerifyResetOtpRequest(
                    user_id=user_id,
                    email_otp='333333',
                    phone_otp=reset_phone_otp,
                ),
                db=self.db,
            )
        self.assertTrue(verify_reset['reset_token'])

        reset = auth_routes.reset_password(
            ResetPasswordRequest(
                reset_token=verify_reset['reset_token'],
                new_password='NewSecure@123',
            ),
            db=self.db,
        )
        self.assertEqual(reset['message'], 'Password reset successful')

        login_again = auth_routes.login(
            LoginRequest(identifier='worker.one', password='NewSecure@123'),
            db=self.db,
        )
        self.assertTrue(login_again['access_token'])
        self.assertFalse(login_again['requires_two_factor'])


if __name__ == '__main__':
    unittest.main()
