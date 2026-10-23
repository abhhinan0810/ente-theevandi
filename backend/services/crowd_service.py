from datetime import datetime, timedelta, timezone
try:
    from backend.extensions import db
    from backend.models.crowd_report import CrowdReport
    from backend.models.coach import Coach
except ImportError:
    from extensions import db
    from models.crowd_report import CrowdReport
    from models.coach import Coach

LEVEL_WEIGHTS = {
    "Low": 1.0,
    "Medium": 2.0,
    "High": 3.0,
}

def get_time_weight(report_time, now):
    if not report_time:
        return 0.0
    # Ensure both are tz-aware or tz-naive
    if report_time.tzinfo is None and now.tzinfo is not None:
        report_time = report_time.replace(tzinfo=timezone.utc)
    elif report_time.tzinfo is not None and now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)

    age_seconds = (now - report_time).total_seconds()
    if age_seconds < 0:
        age_seconds = 0
    age_minutes = age_seconds / 60.0

    if age_minutes <= 10:
        return 1.0  # High freshness
    elif age_minutes <= 30:
        return 0.6  # Medium freshness
    elif age_minutes <= 60:
        return 0.3  # Low freshness
    else:
        return 0.0  # Expired / negligible

def format_relative_time(report_time, now):
    if not report_time:
        return "No reports yet"
    if report_time.tzinfo is None and now.tzinfo is not None:
        report_time = report_time.replace(tzinfo=timezone.utc)
    elif report_time.tzinfo is not None and now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)

    diff_sec = max(0, int((now - report_time).total_seconds()))
    if diff_sec < 60:
        return "Just now"
    diff_min = diff_sec // 60
    if diff_min < 60:
        return f"{diff_min} min ago"
    diff_hours = diff_min // 60
    return f"{diff_hours} hr ago"

def calculate_coach_crowd(coach_id):
    """
    Calculates weighted crowd score, confidence, and freshness for a specific coach.
    - Low = 1.0, Medium = 2.0, High = 3.0
    - Score ranges:
        1.0 - 1.49 -> Low
        1.5 - 2.29 -> Medium
        2.3 - 3.0  -> High
    """
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=2)

    try:
        reports = CrowdReport.query.filter(
            CrowdReport.coach_id == coach_id,
            CrowdReport.created_at >= cutoff
        ).order_by(CrowdReport.created_at.desc()).all()
    except Exception as e:
        print(f"Error querying crowd reports for coach {coach_id}: {e}")
        reports = []

    if not reports:
        return {
            "level": "Unknown",
            "score": 0.0,
            "reports": 0,
            "updated": "No recent reports",
            "confidence": 0,
            "breakdown": {"Low": 0, "Medium": 0, "High": 0}
        }

    total_weighted_score = 0.0
    total_weights = 0.0
    breakdown = {"Low": 0, "Medium": 0, "High": 0}
    latest_report_time = reports[0].created_at if reports else None

    for r in reports:
        w = get_time_weight(r.created_at, now)
        if w > 0:
            score_val = LEVEL_WEIGHTS.get(r.level, 2.0)
            total_weighted_score += score_val * w
            total_weights += w
            if r.level in breakdown:
                breakdown[r.level] += 1

    if total_weights <= 0:
        return {
            "level": "Unknown",
            "score": 0.0,
            "reports": len(reports),
            "updated": format_relative_time(latest_report_time, now),
            "confidence": 15,
            "breakdown": breakdown
        }

    avg_score = round(total_weighted_score / total_weights, 2)

    if avg_score < 1.50:
        level = "Low"
    elif avg_score < 2.30:
        level = "Medium"
    else:
        level = "High"

    base_confidence = min(85.0, 40.0 + (min(len(reports), 6) * 7.5))
    freshness_factor = min(1.0, total_weights / max(1, len(reports)))
    confidence = int(round(base_confidence * (0.6 + 0.4 * freshness_factor)))

    return {
        "level": level,
        "score": avg_score,
        "reports": len(reports),
        "updated": format_relative_time(latest_report_time, now),
        "confidence": confidence,
        "breakdown": breakdown
    }

def record_crowd_report(coach_id, level, station_name="Chengannur", source="USER"):
    if level not in LEVEL_WEIGHTS:
        raise ValueError(f"Invalid crowd level: {level}. Must be Low, Medium, or High.")

    coach = db.session.get(Coach, coach_id)
    if not coach:
        raise ValueError(f"Coach {coach_id} not found.")

    report = CrowdReport(
        coach_id=coach_id,
        station_name=station_name,
        level=level,
        created_at=datetime.now(timezone.utc)
    )
    db.session.add(report)
    db.session.commit()

    return calculate_coach_crowd(coach_id)
