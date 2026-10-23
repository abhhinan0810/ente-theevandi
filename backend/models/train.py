try:
    from backend.extensions import db
except ImportError:
    from extensions import db

class Train(db.Model):
    __tablename__ = "trains"
    id = db.Column(db.Integer, primary_key=True)
    number = db.Column(db.String(10), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    origin = db.Column(db.String(100), nullable=False)
    destination = db.Column(db.String(100), nullable=False)

    coaches = db.relationship("Coach", backref="train", cascade="all, delete-orphan", order_by="Coach.sequence_no")

    def to_dict(self):
        return {
            "id": self.id,
            "number": self.number,
            "name": self.name,
            "origin": self.origin,
            "destination": self.destination,
            "length_meters": (len(self.coaches) * 24.0) if self.coaches else 480.0,
            "coach_count": len(self.coaches) if self.coaches else 0,
        }
