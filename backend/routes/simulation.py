from flask import Blueprint, jsonify, request
from backend.extensions import db, socketio
from backend.models.crowd_report import CrowdReport
from backend.models.train import Train
from backend.services.simulation_service import (
    generate_simulated_passengers,
    advance_simulated_train_position,
    direct_train_to_station,
    reset_simulation,
    get_train_sim_position,
)
from backend.services.location_service import anchor_manager

simulation_bp = Blueprint("simulation", __name__, url_prefix="/api/simulation")

@simulation_bp.get("/stats")
def get_simulation_stats():
    try:
        total_reports = CrowdReport.query.count()
    except Exception:
        total_reports = 0

    return jsonify({
        "success": True,
        "is_simulation_mode": True,
        "simulated_passengers": total_reports * 2,
        "simulated_reports": total_reports,
        "user_reports": total_reports,
    })

@simulation_bp.post("/passengers")
def spawn_simulated_passengers():
    data = request.get_json(silent=True) or {}
    train_id = data.get("train_id")
    count = min(max(data.get("count", 25), 1), 200)
    station_name = data.get("station_name", "Chengannur")

    if not train_id:
        train = Train.query.first()
        if not train:
            return jsonify({"success": False, "message": "No trains found in database"}), 404
        train_id = train.id

    try:
        result = generate_simulated_passengers(
            train_id=train_id,
            count=count,
            target_station=station_name
        )
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 400

    socketio.emit("simulation_update", {
        "action": "spawned_passengers",
        "count": count,
        "train_id": train_id,
        "station_name": station_name
    })
    socketio.emit("crowd_batch_update", {
        "train_id": train_id,
        "summaries": result["coach_summaries"]
    })

    return jsonify(result), 201

@simulation_bp.post("/train-move")
def advance_train():
    data = request.get_json(silent=True) or {}
    train_id = data.get("train_id")
    step = float(data.get("step", 0.08))
    speed = float(data.get("speed", 75.0))

    if not train_id:
        train = Train.query.first()
        if not train:
            return jsonify({"success": False, "message": "No trains found"}), 404
        train_id = train.id

    loc_dict = advance_simulated_train_position(train_id=train_id, progress_step=step, custom_speed=speed)
    socketio.emit("train_position_update", loc_dict)

    return jsonify({
        "success": True,
        "location": loc_dict
    })

@simulation_bp.post("/direct-train")
def direct_train():
    """Directs train to station where presentation user is standing."""
    data = request.get_json(silent=True) or {}
    train_id = int(data.get("train_id", 2))
    station_name = data.get("station_name", "Chengannur")
    at_platform = bool(data.get("at_platform", True))

    loc_dict = direct_train_to_station(train_id=train_id, target_station=station_name, place_at_platform=at_platform)
    socketio.emit("train_position_update", loc_dict)

    return jsonify({
        "success": True,
        "message": f"Directed train to {station_name}",
        "location": loc_dict
    })

@simulation_bp.post("/depart-train")
def depart_train():
    """Simulates departure from station and triggers 1-minute vote notification."""
    data = request.get_json(silent=True) or {}
    train_id = int(data.get("train_id", 2))
    station_name = data.get("station_name", "Chengannur")
    speed = float(data.get("speed", 50.0))

    dep_event = anchor_manager.simulate_train_departure(
        train_id=train_id,
        station_name=station_name,
        speed_kmh=speed
    )

    loc = get_train_sim_position(train_id)
    loc["status"] = "IN_TRANSIT"
    loc["speed_kmh"] = speed

    socketio.emit("train_departed", dep_event)
    socketio.emit("train_position_update", loc)

    return jsonify({
        "success": True,
        "message": f"Train {train_id} departed from {station_name}! Anchor passenger movement detected.",
        "departure_event": dep_event
    })

@simulation_bp.post("/reset")
def do_reset_simulation():
    data = request.get_json(silent=True) or {}
    train_id = data.get("train_id")
    result = reset_simulation(train_id=train_id)
    return jsonify(result)
