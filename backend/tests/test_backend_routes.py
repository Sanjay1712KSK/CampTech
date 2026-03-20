import os
import tempfile
import unittest
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import main
from database.db import Base
from models import digilocker_request as digilocker_request_model  # noqa: F401
from models import gig_income as gig_income_model  # noqa: F401
from models import user_model as user_model_module  # noqa: F401
from routes import auth as auth_routes
from routes import digilocker as digilocker_routes
from routes import environment as environment_routes
from routes import gig as gig_routes
from routes import risk as risk_routes
from schemas.environment_schema import CoordinatesQuery
from schemas.digilocker_schema import DigiLockerConsentSchema, DigiLockerRequestSchema
from schemas.gig_schema import GenerateGigDataRequest
from schemas.user_schema import UserCreate, UserLogin, VerificationRequest


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

        with patch("services.gig_service.SessionLocal", self.SessionLocal):
            today_result = gig_routes.today_income_endpoint(user_id=user_id)
        self.assertIn("earnings", today_result)
        self.assertIn("orders_completed", today_result)

    def test_digilocker_request_consent_and_status(self):
        signup_result = self._signup_user(email="dl@example.com", phone="9234567890")
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
                    document_type="aadhaar",
                    document_number="123456789012",
                    name="Sanju",
                ),
                db=self.db,
            )

        self.assertEqual(consent_result["status"], "VERIFIED")

        status_result = digilocker_routes.digilocker_status(user_id=user_id, db=self.db)
        self.assertEqual(status_result["status"], "VERIFIED")


if __name__ == "__main__":
    unittest.main()
