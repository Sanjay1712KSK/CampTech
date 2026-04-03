import os
import sys
import tempfile
import unittest
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from database.db import Base  # noqa: E402
from models import gig_account as gig_account_model  # noqa: F401,E402
from models import gig_income as gig_income_model  # noqa: F401,E402
from models import profile as profile_model  # noqa: F401,E402
from models import user_model as user_model  # noqa: E402
from routes import gig as gig_routes  # noqa: E402
from schemas.gig_schema import GigConnectRequest  # noqa: E402


class GigModuleTests(unittest.TestCase):
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
            email='gigworker@example.com',
            phone='+919999999999',
            username='gig.worker',
            name='Gig Worker',
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

    def test_connect_generates_income_and_updates_profile(self):
        result = gig_routes.connect_gig_account_endpoint(
            GigConnectRequest(user_id=self.user.id, platform='Swiggy', worker_id='SWG123'),
            db=self.db,
        )

        self.assertEqual(result['message'], 'Swiggy account connected successfully')
        self.assertTrue(result['income_generated'])
        self.assertEqual(result['generated'], 30)

        account = self.db.query(gig_account_model.GigAccount).filter_by(user_id=self.user.id).one()
        self.assertEqual(account.worker_id, 'SWG123')
        self.assertEqual(account.platform, 'swiggy')

        history = gig_routes.income_history_endpoint(user_id=self.user.id, db=self.db)
        self.assertEqual(len(history), 30)
        self.assertTrue(all(6.0 <= item['hours'] <= 10.0 for item in history))
        self.assertTrue(all(item['income'] >= 150.0 for item in history))

        today = gig_routes.today_income_endpoint(user_id=self.user.id, db=self.db)
        self.assertIn('income', today)
        self.assertIn('hours', today)

        baseline = gig_routes.baseline_income_endpoint(user_id=self.user.id, db=self.db)
        self.assertGreater(baseline['baseline_income'], 0)
        self.assertEqual(baseline['baseline_income'], baseline['baseline_daily_income'])

        weekly = gig_routes.weekly_summary_endpoint(user_id=self.user.id, db=self.db)
        self.assertGreaterEqual(weekly['total_income'], 0)
        self.assertGreaterEqual(weekly['average_daily'], 0)

        profile = self.db.query(profile_model.Profile).filter_by(user_id=self.user.id).first()
        self.assertIsNotNone(profile)
        self.assertEqual(profile.platform, 'swiggy')
        self.assertGreater(profile.avg_income, 0)

    def test_duplicate_connection_is_blocked(self):
        gig_routes.connect_gig_account_endpoint(
            GigConnectRequest(user_id=self.user.id, platform='Zomato', worker_id='ZMT123'),
            db=self.db,
        )

        with self.assertRaises(Exception) as context:
            gig_routes.connect_gig_account_endpoint(
                GigConnectRequest(user_id=self.user.id, platform='zomato', worker_id='ZMT999'),
                db=self.db,
            )

        self.assertIn('already connected', str(context.exception))


if __name__ == '__main__':
    unittest.main()
