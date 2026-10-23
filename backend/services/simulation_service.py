import random
import math
from datetime import datetime, timezone
from backend.extensions import db
from backend.models.train import Train
from backend.models.coach import Coach
from backend.models.crowd_report import CrowdReport
from backend.services.crowd_service import calculate_coach_crowd
from backend.services.location_service import anchor_manager
from backend.services.storage import get_station_train_stops

# Kerala Railway Corridor Waypoints (South to North)
KERALA_WAYPOINTS = [
    {"name": "Thiruvananthapuram Central", "code": "TVC", "lat": 8.4875, "lng": 76.9525},
    {"name": "Kollam Junction", "code": "QLN", "lat": 8.8870, "lng": 76.5956},
    {"name": "Kayamkulam Junction", "code": "KYJ", "lat": 9.1724, "lng": 76.5008},
    {"name": "Mavelikara", "code": "MVLK", "lat": 9.2483, "lng": 76.5471},
    {"name": "Chengannur", "code": "CNGR", "lat": 9.3178, "lng": 76.6186},
    {"name": "Tiruvalla", "code": "TRVL", "lat": 9.3835, "lng": 76.5746},
    {"name": "Changanassery", "code": "CGY", "lat": 9.4443, "lng": 76.5415},
    {"name": "Kottayam", "code": "KTYM", "lat": 9.5916, "lng": 76.5222},
    {"name": "Ernakulam Town", "code": "ERN", "lat": 9.9816, "lng": 76.2999},
    {"name": "Aluva", "code": "AWY", "lat": 10.1080, "lng": 76.3530},
    {"name": "Thrissur", "code": "TCR", "lat": 10.5180, "lng": 76.2140},
    {"name": "Shoranur Junction", "code": "SRR", "lat": 10.7602, "lng": 76.2783},
]

# Live in-memory telemetry simulation cache
_train_sim_state = {}

def get_train_sim_position(train_id):
    if train_id not in _train_sim_state:
        train = db.session.get(Train, train_id) if db.session else None
        _train_sim_state[train_id] = {
            "train_id": train_id,
            "train_number": train.number if train else "16302",
            "train_name": train.name if train else "Venad Express",
            "current_station": "Mavelikara",
            "next_station": "Chengannur",
            "latitude": 9.2780,
            "longitude": 76.5820,
            "speed_kmh": 68.0,
            "heading_deg": 45.0,
            "status": "APPROACHING_STATION",
            "is_simulated": True,
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    return _train_sim_state[train_id]

def direct_train_to_station(train_id, target_station="Chengannur", place_at_platform=True):
    """
    Directs the train to the specific station so the user standing at that station
    can board and test live crowd reporting during the presentation.
    """
    loc = get_train_sim_position(train_id)
    
    target_wp = None
    target_idx = 4  # Default Chengannur
    for idx, wp in enumerate(KERALA_WAYPOINTS):
        if target_station.lower() in wp["name"].lower():
            target_wp = wp
            target_idx = idx
            break

    if not target_wp:
        target_wp = KERALA_WAYPOINTS[4]  # Chengannur

    next_idx = min(target_idx + 1, len(KERALA_WAYPOINTS) - 1)
    prev_idx = max(0, target_idx - 1)

    if place_at_platform:
        loc["current_station"] = target_wp["name"]
        loc["next_station"] = KERALA_WAYPOINTS[next_idx]["name"]
        loc["latitude"] = target_wp["lat"]
        loc["longitude"] = target_wp["lng"]
        loc["status"] = "AT_STATION"
        loc["speed_kmh"] = 0.0
    else:
        # Approaching station ~2 km away
        prev_wp = KERALA_WAYPOINTS[prev_idx]
        loc["current_station"] = prev_wp["name"]
        loc["next_station"] = target_wp["name"]
        loc["latitude"] = round((prev_wp["lat"] + target_wp["lat"]) / 2.0, 6)
        loc["longitude"] = round((prev_wp["lng"] + target_wp["lng"]) / 2.0, 6)
        loc["status"] = "APPROACHING_STATION"
        loc["speed_kmh"] = 55.0

    loc["updated_at"] = datetime.now(timezone.utc).isoformat()
    return loc

def advance_simulated_train_position(train_id, progress_step=0.08, custom_speed=75.0):
    loc = get_train_sim_position(train_id)

    curr_idx = 0
    for idx, wp in enumerate(KERALA_WAYPOINTS):
        if wp["name"] == loc["current_station"]:
            curr_idx = idx
            break

    next_idx = min(curr_idx + 1, len(KERALA_WAYPOINTS) - 1)
    if curr_idx >= len(KERALA_WAYPOINTS) - 1:
        curr_idx = 0
        next_idx = 1

    start_wp = KERALA_WAYPOINTS[curr_idx]
    dest_wp = KERALA_WAYPOINTS[next_idx]

    new_lat = round(loc["latitude"] + (dest_wp["lat"] - start_wp["lat"]) * progress_step, 6)
    new_lng = round(loc["longitude"] + (dest_wp["lng"] - start_wp["lng"]) * progress_step, 6)

    lat_diff = abs(new_lat - dest_wp["lat"])
    lng_diff = abs(new_lng - dest_wp["lng"])

    if lat_diff < 0.015 and lng_diff < 0.015:
        loc["current_station"] = dest_wp["name"]
        loc["latitude"] = dest_wp["lat"]
        loc["longitude"] = dest_wp["lng"]
        new_next = (next_idx + 1) % len(KERALA_WAYPOINTS)
        loc["next_station"] = KERALA_WAYPOINTS[new_next]["name"]
        loc["status"] = "AT_STATION"
        loc["speed_kmh"] = 0.0
    else:
        loc["latitude"] = new_lat
        loc["longitude"] = new_lng
        loc["status"] = "IN_TRANSIT"
        loc["speed_kmh"] = custom_speed

    loc["updated_at"] = datetime.now(timezone.utc).isoformat()
    return loc

def generate_simulated_passengers(train_id, count=25, target_station="Chengannur"):
    """
    Generates random coordinates and crowdsourced votes for simulated passengers.
    As requested in prompt:
    - Generates random passenger coordinates along platform & compartments.
    - Votes are generated randomly, mostly weighted on GENERAL compartments.
    """
    coaches = Coach.query.filter_by(train_id=train_id).all()
    if not coaches:
        raise ValueError(f"No coaches found for train {train_id}")

    general_coaches = [c for c in coaches if c.is_general]
    other_coaches = [c for c in coaches if not c.is_general]

    # Get platform stop geometry for realistic passenger coordinates
    stops = get_station_train_stops(target_station, 2)
    front_lat = stops[0]["front_lat"] if stops else 9.3190
    front_lng = stops[0]["front_lng"] if stops else 76.6198
    back_lat = stops[0]["back_lat"] if stops else 9.3147
    back_lng = stops[0]["back_lng"] if stops else 76.6164

    simulated_passengers_data = []

    for i in range(count):
        # 75% probability of boarding General compartment as requested
        if general_coaches and (random.random() < 0.75 or not other_coaches):
            coach = random.choice(general_coaches)
            # General compartments have higher crowd density (mostly Medium or High)
            level = random.choices(["Low", "Medium", "High"], weights=[0.10, 0.45, 0.45])[0]
        else:
            coach = random.choice(other_coaches)
            # Reserved coaches have lower crowd
            level = random.choices(["Low", "Medium", "High"], weights=[0.65, 0.25, 0.10])[0]

        # Calculate random simulated coordinates near this coach
        t_frac = min(1.0, max(0.0, (coach.sequence_no + random.uniform(-0.4, 0.4)) / max(1, len(coaches))))
        p_lat = round(front_lat + (back_lat - front_lat) * t_frac + random.uniform(-0.00005, 0.00005), 6)
        p_lng = round(front_lng + (back_lng - front_lng) * t_frac + random.uniform(-0.00005, 0.00005), 6)

        report = CrowdReport(
            coach_id=coach.id,
            station_name=target_station,
            level=level,
            created_at=datetime.now(timezone.utc)
        )
        db.session.add(report)

        simulated_passengers_data.append({
            "passenger_id": f"SIM-{i+1}",
            "assigned_coach": coach.coach_code,
            "coach_sequence": coach.sequence_no,
            "is_general": coach.is_general,
            "vote_level": level,
            "latitude": p_lat,
            "longitude": p_lng
        })

    db.session.commit()

    updated_summaries = {}
    for c in coaches:
        updated_summaries[c.coach_code] = calculate_coach_crowd(c.id)

    return {
        "success": True,
        "train_id": train_id,
        "passengers_generated": count,
        "station_name": target_station,
        "simulated_passengers_sample": simulated_passengers_data[:10],
        "coach_summaries": updated_summaries
    }

def reset_simulation(train_id=None):
    if train_id and train_id in _train_sim_state:
        train = Train.query.get(train_id)
        _train_sim_state[train_id] = {
            "train_id": train_id,
            "train_number": train.number if train else "16302",
            "train_name": train.name if train else "Venad Express",
            "current_station": "Mavelikara",
            "next_station": "Chengannur",
            "latitude": 9.2780,
            "longitude": 76.5820,
            "speed_kmh": 68.0,
            "status": "APPROACHING_STATION",
            "is_simulated": True,
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    return {"success": True, "message": "Simulation data reset successfully."}
