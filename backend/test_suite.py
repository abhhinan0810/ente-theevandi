import sys
import os
import unittest
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from datetime import datetime, timedelta, timezone
from backend.services.crowd_service import get_time_weight, format_relative_time
from backend.services.location_service import haversine_distance_meters, estimate_coach_position
from backend.app import create_app

class TestCrowdSystem(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.client = self.app.test_client()

    def test_time_weights(self):
        now = datetime.now(timezone.utc)
        # 5 mins ago -> weight 1.0
        w_recent = get_time_weight(now - timedelta(minutes=5), now)
        self.assertEqual(w_recent, 1.0)

        # 20 mins ago -> weight 0.6
        w_med = get_time_weight(now - timedelta(minutes=20), now)
        self.assertEqual(w_med, 0.6)

        # 45 mins ago -> weight 0.3
        w_low = get_time_weight(now - timedelta(minutes=45), now)
        self.assertEqual(w_low, 0.3)

        # 90 mins ago -> expired 0.0
        w_old = get_time_weight(now - timedelta(minutes=90), now)
        self.assertEqual(w_old, 0.0)

    def test_relative_time_formatter(self):
        now = datetime.now(timezone.utc)
        self.assertEqual(format_relative_time(now - timedelta(seconds=20), now), "Just now")
        self.assertEqual(format_relative_time(now - timedelta(minutes=5), now), "5 min ago")
        self.assertEqual(format_relative_time(now - timedelta(hours=2), now), "2 hr ago")

    def test_haversine_distance(self):
        # Known points: Chennai Central (13.0827, 80.2750) and nearby point (~100m)
        d = haversine_distance_meters(13.0827, 80.2750, 13.0836, 80.2750)
        self.assertTrue(90 <= d <= 110, f"Distance {d} was unexpected")

    def test_blueprints_registered(self):
        rules = [rule.rule for rule in self.app.url_map.iter_rules()]
        self.assertIn("/api/health", rules)
        self.assertIn("/api/trains", rules)
        self.assertIn("/api/trains/<int:train_id>/coaches", rules)
        self.assertIn("/api/crowd/<int:coach_id>", rules)
        self.assertIn("/api/crowd-reports", rules)
        self.assertIn("/api/train-positions/<int:train_id>", rules)
        self.assertIn("/api/location/estimate-coach", rules)
        self.assertIn("/api/simulation/passengers", rules)
        self.assertIn("/api/simulation/train-move", rules)
        self.assertIn("/api/auth/login", rules)

    def test_coach_position_estimation(self):
        with self.app.app_context():
            res = estimate_coach_position("Chengannur", 2, 9.3182, 76.6190, train_id=2)
            self.assertTrue(res["success"])
            self.assertIn("estimated_compartment_number", res)
            self.assertIn("compartment_range", res)

if __name__ == "__main__":
    unittest.main()
