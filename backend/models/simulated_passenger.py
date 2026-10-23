from datetime import datetime, timezone
from backend.extensions import db

class SimulatedPassenger:
    def __init__(self, id, passenger_name, latitude, longitude, assigned_coach_id=None, coach_code=None, last_report_level=None):
        self.id = id
        self.passenger_name = passenger_name
        self.latitude = latitude
        self.longitude = longitude
        self.assigned_coach_id = assigned_coach_id
        self.coach_code = coach_code
        self.last_report_level = last_report_level
        self.updated_at = datetime.now(timezone.utc)

    def to_dict(self):
        return {
            "id": self.id,
            "passenger_name": self.passenger_name,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "assigned_coach_id": self.assigned_coach_id,
            "coach_code": self.coach_code,
            "last_report_level": self.last_report_level,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

