from backend.extensions import db

class StationPlatform:
    def __init__(self, id, station_name, platform_number, start_lat, start_lng, end_lat, end_lng):
        self.id = id
        self.station_name = station_name
        self.platform_number = platform_number
        self.start_lat = start_lat
        self.start_lng = start_lng
        self.end_lat = end_lat
        self.end_lng = end_lng

    def to_dict(self):
        return {
            "id": self.id,
            "station_name": self.station_name,
            "platform_number": self.platform_number,
            "start_lat": self.start_lat,
            "start_lng": self.start_lng,
            "end_lat": self.end_lat,
            "end_lng": self.end_lng,
        }

class StoppingProfile:
    def __init__(self, id, train_id, station_name, platform_number, front_lat, front_lng, heading_deg=90.0, avg_coach_length_meters=24.0):
        self.id = id
        self.train_id = train_id
        self.station_name = station_name
        self.platform_number = platform_number
        self.front_lat = front_lat
        self.front_lng = front_lng
        self.heading_deg = heading_deg
        self.avg_coach_length_meters = avg_coach_length_meters

    def to_dict(self):
        return {
            "id": self.id,
            "train_id": self.train_id,
            "station_name": self.station_name,
            "platform_number": self.platform_number,
            "front_lat": self.front_lat,
            "front_lng": self.front_lng,
            "heading_deg": self.heading_deg,
            "avg_coach_length_meters": self.avg_coach_length_meters,
        }

