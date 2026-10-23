try:
    from backend.extensions import db
except ImportError:
    from extensions import db

# Calibrated Kerala & Southern Railway Station Coordinates
STATION_COORDINATES = {
    "CNGR": {"lat": 9.3178, "lng": 76.6186},
    "TRVL": {"lat": 9.3835, "lng": 76.5746},
    "CGY": {"lat": 9.4443, "lng": 76.5415},
    "KTYM": {"lat": 9.5916, "lng": 76.5222},
    "ERN": {"lat": 9.9816, "lng": 76.2999},
    "ERS": {"lat": 9.9680, "lng": 76.2890},
    "MVLK": {"lat": 9.2483, "lng": 76.5471},
    "KYJ": {"lat": 9.1724, "lng": 76.5008},
    "QLN": {"lat": 8.8870, "lng": 76.5956},
    "TVC": {"lat": 8.4875, "lng": 76.9525},
    "SRR": {"lat": 10.7602, "lng": 76.2783},
    "MAS": {"lat": 13.0827, "lng": 80.2750},
    "KPD": {"lat": 12.9716, "lng": 79.1325},
}

class Station(db.Model):
    __tablename__ = "stations"
    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(10), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)

    def to_dict(self):
        coords = STATION_COORDINATES.get(self.code, {"lat": 9.3178, "lng": 76.6186})
        return {
            "id": self.id,
            "code": self.code,
            "name": self.name,
            "latitude": coords["lat"],
            "longitude": coords["lng"],
        }
