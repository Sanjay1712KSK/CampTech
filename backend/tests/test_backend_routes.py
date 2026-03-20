import os
import tempfile
import unittest
from datetime import date, timedelta
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import main
from database.db import Base
from models import bank_account as bank_account_model  # noqa: F401
from models import digilocker_request as digilocker_request_model  # noqa: F401
from models import gig_income as gig_income_model  # noqa: F401
from models import insurance as insurance_model  # noqa: F401
from models import user_model as user_model_module  # noqa: F401
from routes import auth as auth_routes
from routes import claim as claim_routes
from routes import digilocker as digilocker_routes
from routes import environment as environment_routes
from routes import gig as gig_routes
from routes import payment as payment_routes
from routes import premium as premium_routes
from routes import risk as risk_routes
from services.digilocker_service import MOCK_DOCUMENTS
from schemas.environment_schema import CoordinatesQuery
from schemas.digilocker_schema import DigiLockerConsentSchema, DigiLockerRequestSchema
from schemas.gig_schema import GenerateGigDataRequest
from schemas.insurance_schema import ClaimProcessRequest, LinkBankRequest, PayPremiumRequest
from schemas.user_schema import UserCreate, UserLogin, VerificationRequest
from services.policy_service import create_policy


class BackendRouteTests(unittest.TestCase):
    def setUp(self):
        self.temp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self.temp_db.close()
        self.engine = create_engine(
            f"sqlite:///{self.temp_db.name}",
            connect_args={"check_same_thread": False},
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

    def _signup_user(self, email="sanju@example.com", phone="9876543210"):
        payload = UserCreate(
            name="Sanju",
            email=email,
            phone=phone,
            password="password123",
        )
        return auth_routes.signup(payload, db=self.db)

    def test_home_and_health(self):
        self.assertEqual(main.home(), {"message": "Backend is running!!!"})
        self.assertEqual(main.health_check(), {"status": "ok"})

    def test_auth_signup_and_login(self):
        signup_result = self._signup_user()
        self.assertEqual(signup_result["email"], "sanju@example.com")

        login_result = auth_routes.login(
            UserLogin(email="sanju@example.com", password="password123"),
            db=self.db,
        )
        self.assertEqual(login_result["name"], "Sanju")

    def test_auth_verify_identity(self):
        signup_result = self._signup_user()
        user_id = signup_result["id"]

        with patch("services.verification_service.log_verification", return_value={"transaction_id": "MOCK-TXN"}):
            verify_result = auth_routes.verify_identity(
                VerificationRequest(user_id=user_id, document_type="aadhaar"),
                db=self.db,
            )

        self.assertEqual(verify_result["status"], "verified")
        self.assertEqual(verify_result["document_type"], "aadhaar")

    def test_environment_route(self):
        fake_environment = {
            "weather": {"temperature": 31.0, "humidity": 60.0, "wind_speed": 7.0, "rainfall": 1.5},
            "aqi": {"aqi": 2, "pm2_5": 18.0, "pm10": 27.0},
            "traffic": {"traffic_score": 1.3, "traffic_level": "MEDIUM"},
            "context": {"hour": 18, "day_type": "weekday"},
        }

        with patch.object(environment_routes, "get_environment", return_value=fake_environment):
            result = environment_routes.environment(CoordinatesQuery(lat=12.97, lon=77.59))

        self.assertEqual(result, fake_environment)

    def test_risk_route_without_user(self):
        fake_environment = {
            "weather": {"temperature": 42.0, "humidity": 60.0, "wind_speed": 12.0, "rainfall": 6.0},
            "aqi": {"aqi": 4, "pm2_5": 55.0, "pm10": 80.0},
            "traffic": {"traffic_score": 1.8, "traffic_level": "HIGH"},
            "context": {"hour": 22, "day_type": "weekday"},
        }

        with patch.object(risk_routes, "get_environment", return_value=fake_environment):
            result = risk_routes.risk(CoordinatesQuery(lat=12.97, lon=77.59), user_id=None)

        self.assertEqual(result["environment"], fake_environment)
        self.assertEqual(result["risk"]["risk_level"], "HIGH")
        self.assertIsNone(result["gig_context"])

    def test_risk_route_with_user(self):
        fake_environment = {
            "weather": {"temperature": 28.0, "humidity": 55.0, "wind_speed": 5.0, "rainfall": 0.0},
            "aqi": {"aqi": 2, "pm2_5": 20.0, "pm10": 30.0},
            "traffic": {"traffic_score": 1.0, "traffic_level": "LOW"},
            "context": {"hour": 10, "day_type": "weekday"},
        }
        fake_today = {
            "earnings": 540.0,
            "orders_completed": 12,
            "hours_worked": 6.5,
            "disruption_type": "none",
            "platform": "swiggy",
        }

        with patch.object(risk_routes, "get_environment", return_value=fake_environment), patch.object(
            risk_routes,
            "today_income",
            return_value=fake_today,
        ):
            result = risk_routes.risk(CoordinatesQuery(lat=12.97, lon=77.59), user_id=1)

        self.assertEqual(result["gig_context"]["earnings_today"], 540.0)
        self.assertEqual(result["gig_context"]["orders_completed"], 12)

    def test_gig_generate_and_today_income(self):
        signup_result = self._signup_user(email="gig@example.com", phone="9123456789")
        user_id = signup_result["id"]

        with patch("services.gig_service.SessionLocal", self.SessionLocal):
            generate_result = gig_routes.generate_data_endpoint(
                GenerateGigDataRequest(user_id=user_id, days=3)
            )
        self.assertEqual(generate_result["generated"], 3)

        history_result = gig_routes.income_history_endpoint(user_id=user_id, db=self.db)
        self.assertGreaterEqual(len(history_result), 1)
        self.assertEqual(history_result[0].user_id, user_id)

        today_result = gig_routes.today_income_endpoint(user_id=user_id, db=self.db)
        self.assertEqual(today_result.user_id, user_id)
        self.assertTrue(hasattr(today_result, "earnings"))

    def test_digilocker_request_consent_and_status(self):
        document = MOCK_DOCUMENTS[0]
        signup_result = self._signup_user(
            email="dl@example.com",
            phone="9234567890",
        )
        self.db.query(user_model_module.User).filter(user_model_module.User.id == signup_result["id"]).update(
            {"name": document["name"]}
        )
        self.db.commit()
        user_id = signup_result["id"]

        request_result = digilocker_routes.digilocker_request(
            DigiLockerRequestSchema(user_id=user_id),
            db=self.db,
        )
        request_id = request_result["request_id"]

        with patch("services.digilocker_service.log_verification", return_value={"transaction_id": "MOCK-TXN"}):
            consent_result = digilocker_routes.digilocker_consent(
                DigiLockerConsentSchema(
                    request_id=request_id,
                    document_type=document["document_type"],
                    document_number=document["document_number"],
                    name=document["name"],
                ),
                db=self.db,
            )

        self.assertEqual(consent_result["status"], "VERIFIED")

        status_result = digilocker_routes.digilocker_status(user_id=user_id, db=self.db)
        self.assertEqual(status_result["status"], "VERIFIED")

    def test_premium_calculation(self):
        signup_result = self._signup_user(email="premium@example.com", phone="9011111111")
        user_id = signup_result["id"]

        self.db.add_all([
            gig_income_model.GigIncome(
                user_id=user_id,
                date=date.today(),
                orders_completed=18,
                hours_worked=8.0,
                earnings=900.0,
                earnings_per_order=50.0,
                platform="swiggy",
                disruption_type="none",
            ),
            gig_income_model.GigIncome(
                user_id=user_id,
                date=date.today() - timedelta(days=1),
                orders_completed=17,
                hours_worked=7.5,
                earnings=860.0,
                earnings_per_order=50.0,
                platform="zomato",
                disruption_type="none",
            ),
        ])
        self.db.commit()

        fake_environment = {
            "weather": {"temperature": 30.0, "humidity": 60.0, "wind_speed": 5.0, "rainfall": 1.0},
            "aqi": {"aqi": 2, "pm2_5": 20.0, "pm10": 30.0},
            "traffic": {"traffic_score": 1.1, "traffic_level": "MEDIUM"},
            "context": {"hour": 10, "day_type": "weekday"},
        }
        with patch("services.premium_engine.get_environment", return_value=fake_environment):
            result = premium_routes.calculate_premium_endpoint(user_id=user_id, db=self.db)

        self.assertGreater(result["baseline"], 0)
        self.assertGreaterEqual(result["risk_score"], 0)
        self.assertGreaterEqual(result["weekly_premium"], 0)

    def test_link_bank_and_pay_premium(self):
        signup_result = self._signup_user(email="bank@example.com", phone="9022222222")
        user_id = signup_result["id"]

        link_result = payment_routes.link_bank_endpoint(
            LinkBankRequest(user_id=user_id, account_number="123456789012", ifsc="HDFC0001234"),
            db=self.db,
        )
        self.assertEqual(link_result["status"], "LINKED")

        with patch("routes.payment.log_to_blockchain", return_value={"transaction_id": "MOCK-TXN"}):
            payment_result = payment_routes.pay_premium_endpoint(
                PayPremiumRequest(user_id=user_id, amount=200.0),
                db=self.db,
            )

        self.assertEqual(payment_result["status"], "SUCCESS")
        self.assertEqual(payment_result["amount"], 200.0)
        self.assertLess(payment_result["balance"], link_result["balance"])
        self.assertIsNotNone(
            self.db.query(insurance_model.Policy).filter(insurance_model.Policy.user_id == user_id).first()
        )

    def test_claim_process_approved(self):
        signup_result = self._signup_user(email="claim@example.com", phone="9033333333")
        user_id = signup_result["id"]

        payment_routes.link_bank_endpoint(
            LinkBankRequest(user_id=user_id, account_number="555555555555", ifsc="SBIN0001234"),
            db=self.db,
        )

        policy_start = date.today() - timedelta(days=8)
        create_policy(user_id=user_id, db=self.db, start_date=policy_start)

        records = []
        for offset in range(5):
            records.append(
                gig_income_model.GigIncome(
                    user_id=user_id,
                    date=policy_start - timedelta(days=offset + 1),
                    orders_completed=19,
                    hours_worked=8.0,
                    earnings=1000.0 - (offset * 10),
                    earnings_per_order=50.0,
                    platform="swiggy",
                    disruption_type="none",
                    city="Chennai",
                )
            )

        policy_dates = [policy_start + timedelta(days=day) for day in range(8)]
        weekly_earnings = [420.0, 380.0, 410.0, 360.0, 390.0, 340.0, 370.0, 350.0]
        for day, amount in zip(policy_dates, weekly_earnings):
            records.append(
                gig_income_model.GigIncome(
                    user_id=user_id,
                    date=day,
                    orders_completed=6,
                    hours_worked=6.0,
                    earnings=amount,
                    earnings_per_order=50.0,
                    platform="swiggy",
                    disruption_type="rain",
                    rainfall=7.0,
                    traffic_level="HIGH",
                    traffic_score=1.7,
                    city="Chennai",
                )
            )

        self.db.add_all(records)
        self.db.commit()

        fake_environment = {
            "weather": {"temperature": 26.0, "humidity": 88.0, "wind_speed": 8.0, "rainfall": 7.0},
            "aqi": {"aqi": 2, "pm2_5": 18.0, "pm10": 28.0},
            "traffic": {"traffic_score": 1.7, "traffic_level": "HIGH"},
            "context": {"hour": 18, "day_type": "weekday"},
        }
        with patch("services.claim_engine.get_environment", return_value=fake_environment), patch(
            "routes.claim.log_to_blockchain",
            return_value={"transaction_id": "MOCK-TXN"},
        ):
            result = claim_routes.process_claim_endpoint(
                ClaimProcessRequest(user_id=user_id, lat=13.0827, lon=80.2707),
                db=self.db,
            )

        self.assertEqual(result["status"], "APPROVED")
        self.assertGreater(result["payout"], 0)
        self.assertGreater(result["weekly_loss"], 0)


if __name__ == "__main__":
    unittest.main()
