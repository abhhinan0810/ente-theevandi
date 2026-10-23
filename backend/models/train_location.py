from datetime import datetime, timezone
from backend.extensions import db

class TrainLocation:
    def __init__(self, id, train_id, current_station, next_station, latitude, longitude, speed_kmh=60.0, status="IN_TRANSIT", is_simulated=True, train_number="", train_name=""):
        self.id = id
        self.train_id = train_id
        self.current_station = current_station
        self.next_station = next_station
        self.latitude = latitude
        self.longitude = longitude
        self.speed_kmh = speed_kmh
        self.status = status
        self.is_simulated = is_simulated
        self.train_number = train_number
        self.train_name = train_name
        self.updated_at = datetime.now(timezone.utc)

    def to_dict(self):
        return {
            "id": self.id,
            "train_id": self.train_id,
            "train_number": self.train_number,
            "train_name": self.train_name,
            "current_station": self.current_station,
            "next_station": self.next_station,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "speed_kmh": self.speed_kmh,
            "status": self.status,
            "is_simulated": self.is_simulated,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

