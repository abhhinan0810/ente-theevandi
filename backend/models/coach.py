try:
    from backend.extensions import db
except ImportError:
    from extensions import db

class Coach(db.Model):
    __tablename__ = "coaches"
    id = db.Column(db.Integer, primary_key=True)
    train_id = db.Column(db.Integer, db.ForeignKey("trains.id", ondelete="CASCADE"), nullable=False)
    coach_code = db.Column(db.String(12), nullable=False)
    coach_type = db.Column(db.String(30), nullable=False)
    sequence_no = db.Column(db.Integer, nullable=False)
    is_general = db.Column(db.Boolean, default=False, nullable=False)

    __table_args__ = (
        db.UniqueConstraint("train_id", "coach_code", name="uq_train_coach_code"),
        db.UniqueConstraint("train_id", "sequence_no", name="uq_train_sequence_no"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "train_id": self.train_id,
            "code": self.coach_code,
            "type": self.coach_type,
            "sequence": self.sequence_no,
            "is_general": self.is_general,
            "distance_from_front": self.sequence_no * 24.0,
            "length_meters": 24.0,
        }
