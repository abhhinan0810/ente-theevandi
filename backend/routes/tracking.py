from flask import Blueprint, jsonify, request
from backend.extensions import db, socketio
from backend.models.train import Train
from backend.services.location_service import (
    estimate_coach_position,
    anchor_manager,
)
from backend.services.simulation_service import get_train_sim_position

tracking_bp = Blueprint("tracking", __name__, url_prefix="/api")

@tracking_bp.get("/train-positions/<int:train_id>")
def get_train_position(train_id):
    train = db.session.get(Train, train_id)
    if not train:
        return jsonify({"success": False, "message": "Train not found"}), 404

    loc = get_train_sim_position(train_id)
    dep_status = anchor_manager.get_departure_status(train_id)
    loc["departure_status"] = dep_status

    return jsonify({
        "success": True,
        "disclaimer": "SIMULATED TRAIN POSITION - For demonstration only. Not official railway tracking data.",
        "location": loc
    })

@tracking_bp.post("/location/estimate-coach")
def estimate_coach():
    data = request.get_json(silent=True) or {}
    station_name = data.get("station_name", "Chengannur").strip()
    platform_number = data.get("platform_number", 2)
    lat = data.get("latitude")
    lng = data.get("longitude")
    train_id = data.get("train_id")
    train_type = data.get("train_type")

    if lat is None or lng is None:
        return jsonify({
            "success": False,
            "message": "latitude and longitude are required",
            "manual_fallback": True
        }), 400

    try:
        lat = float(lat)
        lng = float(lng)
        platform_number = int(platform_number)
    except (ValueError, TypeError):
        return jsonify({"success": False, "message": "Invalid coordinates or platform format"}), 400

    result = estimate_coach_position(
        station_name=station_name,
        platform_number=platform_number,
        passenger_lat=lat,
        passenger_lng=lng,
        train_id=train_id,
        train_type=train_type
    )
    return jsonify(result)

@tracking_bp.get("/tracking/anchors/<int:train_id>")
def get_train_anchors(train_id):
    """Returns the anchor passengers for this train (refreshed every 30 seconds)."""
    force = request.args.get("force", "false").lower() == "true"
    loc = get_train_sim_position(train_id)
    anchors_data = anchor_manager.get_or_create_anchors(
        train_id=train_id,
        train_lat=loc.get("latitude", 9.3178),
        train_lng=loc.get("longitude", 76.6186),
        force_refresh=force
    )
    return jsonify({
        "success": True,
        "data": anchors_data
    })

@tracking_bp.post("/tracking/simulate-departure")
def trigger_train_departure():
    """
    Simulates departure of anchor passengers in train's heading direction.
    Triggers instant departure detection and starts the 1-minute voting timer.
    """
    data = request.get_json(silent=True) or {}
    train_id = int(data.get("train_id", 2))
    station_name = data.get("station_name", "Chengannur")
    speed_kmh = float(data.get("speed_kmh", 45.0))

    departure_event = anchor_manager.simulate_train_departure(
        train_id=train_id,
        station_name=station_name,
        speed_kmh=speed_kmh
    )

    # Broadcast real-time departure event via Socket.IO
    socketio.emit("train_departed", departure_event)

    return jsonify({
        "success": True,
        "message": f"Train {train_id} departure detected via simultaneous anchor passenger movement!",
        "departure_event": departure_event
    })

@tracking_bp.get("/tracking/departure-status/<int:train_id>")
def get_departure_status(train_id):
    status = anchor_manager.get_departure_status(train_id)
    return jsonify({
        "success": True,
        "status": status
    })

@tracking_bp.post("/tracking/in-train-movement")
def test_in_train_movement():
    """
    Evaluates passenger movement inside the running train relative to anchor passengers.
    """
    data = request.get_json(silent=True) or {}
    train_id = int(data.get("train_id", 2))
    current_seq = int(data.get("current_sequence", 4))
    delta_front = float(data.get("delta_front_m", 0.0))
    delta_rear = float(data.get("delta_rear_m", 0.0))

    result = anchor_manager.detect_in_train_movement(
        train_id=train_id,
        current_coach_sequence=current_seq,
        delta_to_front_anchor=delta_front,
        delta_to_rear_anchor=delta_rear
    )
    return jsonify({
        "success": True,
        "movement": result
    })
