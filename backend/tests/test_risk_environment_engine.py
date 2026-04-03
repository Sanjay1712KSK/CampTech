import os
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from database.db import Base  # noqa: E402
from core.environment_engine import build_environment  # noqa: E402
from routes import risk as risk_routes  # noqa: E402
from schemas.environment_schema import CoordinatesQuery  # noqa: E402
from services.risk_engine import calculate_risk  # noqa: E402
from models import adaptive_risk_weight as adaptive_weight_model  # noqa: F401,E402
from models import environment_snapshot as environment_snapshot_model  # noqa: F401,E402
from models import gig_income as gig_income_model  # noqa: F401,E402
from models import insurance as insurance_model  # noqa: F401,E402
from models import user_model as user_model  # noqa: E402


class RiskEnvironmentEngineTests(unittest.TestCase):
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

        self.user = user_model.User(
            email='risk@example.com',
            phone='+919876543210',
            username='risk.user',
            name='Risk User',
            password_hash='hashed-password',
            is_email_verified=True,
            is_phone_verified=True,
            is_account_confirmed=True,
            is_digilocker_verified=True,
            has_completed_first_login_2fa=True,
        )
        self.db.add(self.user)
        self.db.commit()
        self.db.refresh(self.user)

    def tearDown(self):
        self.db.close()
        self.engine.dispose()
        if os.path.exists(self.temp_db.name):
            os.unlink(self.temp_db.name)

    def _seed_gig_history(self):
        records = []
        for offset in range(10):
            records.append(
                gig_income_model.GigIncome(
                    user_id=self.user.id,
                    date=date.today() - timedelta(days=offset),
                    orders_completed=12,
                    hours_worked=7.5,
                    earnings=600.0 - (offset * 8),
                    earnings_per_order=50.0,
                    platform='swiggy',
                    disruption_type='rain' if offset % 2 == 0 else 'traffic',
                    rainfall=6.0 + offset,
                    traffic_score=1.25 + (offset * 0.03),
                    aqi_level=3,
                    wind_speed=11.0 + offset,
                    temperature=34.0 + (offset * 0.2),
                    humidity=68.0,
                    city='Chennai',
                    loss_amount=120.0,
                )
            )
        self.db.add_all(records)
        self.db.commit()

    def test_environment_engine_builds_snapshot_and_persists_history(self):
        fake_weather = {
            'temperature': 36.5,
            'humidity': 78.0,
            'wind_speed': 14.0,
            'rainfall': 5.5,
            'rain_estimate': 5.5,
            'hourly': [
                {'time': '2026-04-03T06:00', 'hour': 6, 'temperature': 31.0, 'humidity': 72.0, 'wind_speed': 8.0, 'rain_estimate': 0.0},
                {'time': '2026-04-03T12:00', 'hour': 12, 'temperature': 37.0, 'humidity': 60.0, 'wind_speed': 12.0, 'rain_estimate': 1.0},
                {'time': '2026-04-03T18:00', 'hour': 18, 'temperature': 33.0, 'humidity': 80.0, 'wind_speed': 14.0, 'rain_estimate': 6.0},
                {'time': '2026-04-03T22:00', 'hour': 22, 'temperature': 29.0, 'humidity': 84.0, 'wind_speed': 11.0, 'rain_estimate': 4.0},
            ],
        }
        fake_aqi = {'aqi': 4, 'aqi_index': 250.0, 'pm2_5': 72.0, 'pm10': 108.0}
        fake_traffic = {
            'traffic_score': 1.55,
            'traffic_index': 1.55,
            'traffic_level': 'HIGH',
            'route_duration_seconds': 1400.0,
            'free_flow_duration_seconds': 900.0,
        }

        with (
            patch('core.environment_engine.get_weather', return_value=fake_weather),
            patch('core.environment_engine.get_aqi', return_value=fake_aqi),
            patch('core.environment_engine.get_traffic', return_value=fake_traffic),
        ):
            payload = build_environment(13.0827, 80.2707, db=self.db, user_id=self.user.id)

        self.assertIn('snapshot', payload)
        self.assertEqual(payload['snapshot']['traffic_index'], 1.55)
        self.assertIn('time_slot_risk', payload)
        self.assertIn('predictive_risk', payload)
        self.assertIn('hyper_local_analysis', payload)
        snapshot_count = self.db.query(environment_snapshot_model.EnvironmentSnapshot).count()
        self.assertEqual(snapshot_count, 1)

    def test_risk_engine_returns_full_payload_and_updates_weights(self):
        self._seed_gig_history()
        environment_payload = {
            'snapshot': {
                'temperature': 38.0,
                'wind_speed': 18.0,
                'humidity': 80.0,
                'rain_estimate': 7.0,
                'aqi': 220.0,
                'traffic_index': 1.65,
            },
            'hyper_local_analysis': {
                'hyper_local_risk': 1.4,
                'insight': '40% higher disruption than recent average',
                'baseline_snapshot': {
                    'temperature': 32.0,
                    'wind_speed': 9.0,
                    'humidity': 60.0,
                    'rain_estimate': 1.0,
                    'aqi': 90.0,
                    'traffic_index': 1.1,
                },
                'source': 'gig_history',
            },
            'predictive_risk': {'next_6hr_risk': 0.78, 'trend': 'increasing'},
            'time_slot_risk': {
                'morning': 'LOW',
                'afternoon': 'MEDIUM',
                'evening': 'HIGH',
                'night': 'MEDIUM',
            },
            'city': 'Chennai',
            'resolved_city': 'Chennai',
        }

        result = calculate_risk(
            environment_payload,
            user_id=self.user.id,
            db=self.db,
            today_income={'disruption_type': 'rain', 'earnings': 420.0, 'orders_completed': 8},
        )

        self.assertGreater(result['risk_score'], 0.0)
        self.assertEqual(result['risk_level'], 'HIGH')
        self.assertIn('expected_income_loss', result)
        self.assertIn('expected_income_loss_pct', result)
        self.assertIn('delivery_efficiency', result)
        self.assertIn('RAIN_TRIGGER', result['active_triggers'])
        self.assertIn('TRAFFIC_TRIGGER', result['active_triggers'])
        self.assertIn('fraud_signals', result)
        self.assertIn('pattern_flag', result['fraud_signals'])
        self.assertIn('next_6hr', result['predictive_risk'])
        self.assertIn('adaptive_weights', result)

        weights = result['adaptive_weights']
        self.assertAlmostEqual(sum(weights.values()), 1.0, places=2)

    def test_risk_route_returns_top_level_payload_and_gig_context(self):
        self._seed_gig_history()
        fake_environment = {
            'weather': {
                'temperature': 37.0,
                'humidity': 75.0,
                'wind_speed': 15.0,
                'rainfall': 6.0,
                'rain_estimate': 6.0,
                'hourly': [],
            },
            'aqi': {'aqi': 4, 'aqi_index': 250.0, 'pm2_5': 70.0, 'pm10': 100.0},
            'traffic': {
                'traffic_score': 1.6,
                'traffic_index': 1.6,
                'traffic_level': 'HIGH',
                'route_duration_seconds': 1300.0,
                'free_flow_duration_seconds': 850.0,
            },
            'context': {'hour': 18, 'day_type': 'weekday'},
            'snapshot': {
                'temperature': 37.0,
                'wind_speed': 15.0,
                'humidity': 75.0,
                'rain_estimate': 6.0,
                'aqi': 250.0,
                'traffic_index': 1.6,
            },
            'hyper_local_analysis': {
                'hyper_local_risk': 1.3,
                'insight': '30% higher disruption than recent average',
                'baseline_snapshot': {
                    'temperature': 31.0,
                    'wind_speed': 8.0,
                    'humidity': 60.0,
                    'rain_estimate': 1.0,
                    'aqi': 90.0,
                    'traffic_index': 1.1,
                },
                'source': 'gig_history',
            },
            'time_slot_risk': {
                'morning': 'LOW',
                'afternoon': 'MEDIUM',
                'evening': 'HIGH',
                'night': 'MEDIUM',
            },
            'predictive_risk': {'next_6hr_risk': 0.76, 'trend': 'increasing'},
            'hourly_forecast': [],
        }

        with (
            patch.object(risk_routes, 'get_environment', return_value=fake_environment),
            patch.object(risk_routes, 'today_income', return_value={'earnings': 410.0, 'orders_completed': 7, 'disruption_type': 'rain'}),
        ):
            response = risk_routes.risk(
                CoordinatesQuery(lat=13.0827, lon=80.2707),
                user_id=self.user.id,
                db=self.db,
            )

        self.assertIn('risk_score', response)
        self.assertIn('delivery_efficiency', response)
        self.assertIn('expected_income_loss_pct', response)
        self.assertEqual(response['gig_context']['orders_completed'], 7)
        self.assertIn('environment', response)


if __name__ == '__main__':
    unittest.main()
