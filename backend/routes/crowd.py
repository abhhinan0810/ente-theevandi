from flask import Blueprint, jsonify, request
try:
    from backend.extensions import db, socketio
    from backend.models.coach import Coach
    from backend.models.crowd_report import CrowdReport
    from backend.services.crowd_service import (
        calculate_coach_crowd,
        record_crowd_report,
    )
except ImportError:
    from extensions import db, socketio
    from models.coach import Coach
    from models.crowd_report import CrowdReport
    from services.crowd_service import (
        calculate_coach_crowd,
        record_crowd_report,
    )

crowd_bp = Blueprint("crowd", __name__, url_prefix="/api")

@crowd_bp.get("/crowd/<int:coach_id>")
def get_coach_crowd_summary(coach_id):
    coach = db.session.get(Coach, coach_id)
    if not coach:
        return jsonify({"success": False, "message": "Coach not found"}), 404
    summary = calculate_coach_crowd(coach_id)
    return jsonify({
        "success": True,
        "coach": coach.to_dict(),
        **summary
    })

@crowd_bp.get("/crowd-reports/recent")
def get_recent_reports():
    limit = min(request.args.get("limit", 50, type=int), 200)
    reports = CrowdReport.query.order_by(CrowdReport.created_at.desc()).limit(limit).all()
    results = []
    for r in reports:
        coach = db.session.get(Coach, r.coach_id)
        train = coach.train if coach else None
        results.append({
            "id": r.id,
            "coach_id": r.coach_id,
            "coach_code": coach.coach_code if coach else "N/A",
            "coach_type": coach.coach_type if coach else "N/A",
            "train_number": train.number if train else "N/A",
            "train_name": train.name if train else "N/A",
            "station_name": r.station_name,
            "level": r.level,
            "source": getattr(r, 'source', 'USER'),
            "created_at": r.created_at.isoformat() if r.created_at else None,
        })
    return jsonify(results)

@crowd_bp.post("/crowd-reports")
def submit_crowd_report():
    data = request.get_json(silent=True) or {}
    coach_id = data.get("coach_id")
    level = data.get("level")
    station_name = (data.get("station_name") or "Chengannur").strip()
    source = data.get("source", "USER").upper()

    if not isinstance(coach_id, int):
        return jsonify({"success": False, "message": "coach_id must be an integer"}), 400

    if level not in {"Low", "Medium", "High"}:
        return jsonify({"success": False, "message": "level must be Low, Medium, or High"}), 400

    coach = db.session.get(Coach, coach_id)
    if not coach:
        return jsonify({"success": False, "message": f"Coach with ID {coach_id} not found"}), 404

    try:
        updated_summary = record_crowd_report(
            coach_id=coach_id,
            level=level,
            station_name=station_name,
            source=source
        )
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

    # Emit real-time Socket.IO event to all listening clients (Flutter, Admin, Simulation)
    event_payload = {
        "coach_id": coach_id,
        "coach_code": coach.coach_code,
        "coach_type": coach.coach_type,
        "train_id": coach.train_id,
        "station_name": station_name,
        "source": source,
        "new_report": level,
        **updated_summary
    }
    socketio.emit("crowd_update", event_payload)

    return jsonify({
        "success": True,
        "message": "Thanks! Your crowd report has been recorded.",
        "data": event_payload
    }), 201
