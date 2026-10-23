from datetime import datetime, timezone
try:
    from backend.extensions import db
except ImportError:
    from extensions import db

class CrowdReport(db.Model):
    __tablename__ = "crowd_reports"
    id = db.Column(db.Integer, primary_key=True)
    coach_id = db.Column(db.Integer, db.ForeignKey("coaches.id", ondelete="CASCADE"), nullable=False)
    station_name = db.Column(db.String(100), nullable=False)
    level = db.Column(db.String(10), nullable=False)  # 'Low', 'Medium', 'High'
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    coach = db.relationship("Coach", backref=db.backref("reports", lazy="dynamic", cascade="all, delete-orphan"))

    def to_dict(self):
        return {
            "id": self.id,
            "coach_id": self.coach_id,
            "station_name": self.station_name,
            "level": self.level,
            "source": "USER",
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
