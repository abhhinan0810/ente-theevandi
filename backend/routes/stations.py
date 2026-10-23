from flask import Blueprint, jsonify, request
from backend.extensions import db
from backend.models.station import Station
from backend.services.storage import (
    REAL_WORLD_COACH_SPECS,
    get_station_train_stops,
    add_station_train_stop,
)

stations_bp = Blueprint("stations", __name__, url_prefix="/api/stations")

@stations_bp.get("")
def get_stations():
    stations = Station.query.order_by(Station.name).all()
    return jsonify([s.to_dict() for s in stations])

@stations_bp.get("/train-models")
def get_train_models():
    """Returns list of real-world train models with coach lengths."""
    return jsonify({
        "success": True,
        "models": REAL_WORLD_COACH_SPECS
    })

@stations_bp.get("/<string:station_identifier>/platforms")
def get_station_platforms(station_identifier):
    # Lookup platforms configured in station_train_stops
    stops = get_station_train_stops(station_identifier)
    platform_numbers = sorted(list(set(s["platform_number"] for s in stops))) if stops else [1, 2, 3]
    
    results = []
    for p in platform_numbers:
        p_stops = [s for s in stops if s["platform_number"] == p]
        first = p_stops[0] if p_stops else None
        results.append({
            "platform_number": p,
            "station_name": station_identifier,
            "train_types_configured": [s["train_type"] for s in p_stops],
            "front_lat": first["front_lat"] if first else 9.3190,
            "front_lng": first["front_lng"] if first else 76.6198,
            "back_lat": first["back_lat"] if first else 9.3147,
            "back_lng": first["back_lng"] if first else 76.6164,
        })
    return jsonify(results)

@stations_bp.get("/<string:station_identifier>/stops")
def get_station_stops(station_identifier):
    train_type = request.args.get("train_type")
    platform = request.args.get("platform", type=int)
    stops = get_station_train_stops(station_identifier, platform_number=platform, train_type=train_type)
    return jsonify(stops)

@stations_bp.post("/<string:station_identifier>/stops")
def create_or_update_station_stop(station_identifier):
    data = request.get_json(silent=True) or {}
    platform_number = int(data.get("platform_number", 1))
    train_type = (data.get("train_type") or "Express").strip()
    front_lat = float(data.get("front_lat", 9.3190))
    front_lng = float(data.get("front_lng", 76.6198))
    back_lat = float(data.get("back_lat", 9.3147))
    back_lng = float(data.get("back_lng", 76.6164))

    # Derive coach length based on train model
    spec = REAL_WORLD_COACH_SPECS.get(train_type, REAL_WORLD_COACH_SPECS["Express"])
    avg_coach_len = float(data.get("avg_coach_length", spec["coach_length_meters"]))

    stop_id = add_station_train_stop(
        station_name=station_identifier,
        platform_number=platform_number,
        train_type=train_type,
        front_lat=front_lat,
        front_lng=front_lng,
        back_lat=back_lat,
        back_lng=back_lng,
        avg_coach_length=avg_coach_len
    )

    return jsonify({
        "success": True,
        "message": f"Saved stopping coordinates for {station_identifier} (Platform {platform_number}, {train_type})",
        "stop_id": stop_id,
        "train_type": train_type,
        "coach_length_meters": avg_coach_len
    }), 201

@stations_bp.post("")
def add_station():
    data = request.get_json(silent=True) or {}
    code = data.get("code", "").strip().upper()
    name = data.get("name", "").strip()
    lat = data.get("latitude")
    lng = data.get("longitude")

    if not code or not name:
        return jsonify({"success": False, "message": "code and name are required"}), 400

    existing = Station.query.filter_by(code=code).first()
    if existing:
        return jsonify({"success": False, "message": f"Station with code {code} already exists"}), 409

    stn = Station(code=code, name=name, latitude=lat, longitude=lng)
    db.session.add(stn)
    db.session.commit()

    # Pre-configure default Platform 1 & 2 stops for this new station
    center_lat = float(lat) if lat else 9.3178
    center_lng = float(lng) if lng else 76.6186
    for p in [1, 2]:
        for t_type, t_spec in REAL_WORLD_COACH_SPECS.items():
            add_station_train_stop(
                station_name=name,
                platform_number=p,
                train_type=t_type,
                front_lat=round(center_lat + 0.0012, 6),
                front_lng=round(center_lng + 0.0012, 6),
                back_lat=round(center_lat - 0.0030, 6),
                back_lng=round(center_lng - 0.0022, 6),
                avg_coach_length=t_spec["coach_length_meters"]
            )

    return jsonify({"success": True, "station": stn.to_dict()}), 201
