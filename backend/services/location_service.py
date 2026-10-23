import math
import time
import random
from datetime import datetime, timezone
from backend.extensions import db
from backend.models.coach import Coach
from backend.models.train import Train
from backend.services.storage import (
    REAL_WORLD_COACH_SPECS,
    get_station_train_stops,
    get_train_profile,
)

def haversine_distance_meters(lat1, lon1, lat2, lon2):
    """Calculate distance in meters between two lat/lng coordinates using Haversine formula."""
    R = 6371000.0  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * \
        math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def calculate_bearing(lat1, lon1, lat2, lon2):
    """Calculate bearing in degrees from point 1 to point 2."""
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_lambda = math.radians(lon2 - lon1)
    y = math.sin(delta_lambda) * math.cos(phi2)
    x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(delta_lambda)
    bearing = math.degrees(math.atan2(y, x))
    return (bearing + 360) % 360

def estimate_coach_position(station_name, platform_number, passenger_lat, passenger_lng, train_id=None, train_type="Express"):
    """
    Estimates the user's compartment based on station platform front and back coordinates:
    1. Checks if user is between front and back stopping coordinates for the train model.
    2. Divides the total train length (front to back) into equal parts = number of compartments.
    3. Uses real-world compartment lengths (e.g. 25m for Express, 22m for MEMU).
    4. Compares distance from front coordinate to find the exact compartment and probability.
    """
    train = None
    if train_id:
        train = db.session.get(Train, train_id)

    # Determine train type and compartment length
    train_number = train.number if train else "16302"
    profile = get_train_profile(train_number)
    effective_train_type = profile.get("train_type", train_type or "Express")
    spec = REAL_WORLD_COACH_SPECS.get(effective_train_type, REAL_WORLD_COACH_SPECS["Express"])
    coach_len = spec["coach_length_meters"]

    # Retrieve platform front & back stop coordinates
    stops = get_station_train_stops(station_name, platform_number, effective_train_type)
    if not stops:
        # Fallback to any stop for this station & platform
        stops = get_station_train_stops(station_name, platform_number)
    if not stops:
        # Fallback to generic Chengannur Platform 2 coordinates
        stop_geom = {
            "front_lat": 9.3190, "front_lng": 76.6198,
            "back_lat": 9.3147, "back_lng": 76.6164,
            "avg_coach_length_meters": coach_len
        }
    else:
        stop_geom = stops[0]

    front_lat = stop_geom["front_lat"]
    front_lng = stop_geom["front_lng"]
    back_lat = stop_geom["back_lat"]
    back_lng = stop_geom["back_lng"]

    # Total train length along platform between front and back coordinates
    total_platform_length = haversine_distance_meters(front_lat, front_lng, back_lat, back_lng)
    if total_platform_length < 50:
        total_platform_length = 500.0  # Safe default ~20 coaches

    # Distance of user from train front coordinate
    dist_from_front = haversine_distance_meters(passenger_lat, passenger_lng, front_lat, front_lng)
    dist_from_back = haversine_distance_meters(passenger_lat, passenger_lng, back_lat, back_lng)

    # Vector projection along train axis to verify if user is between front and back
    # Convert lat/lng to meter displacements
    lat_mid = (front_lat + back_lat) / 2.0
    meters_per_lat = 110540.0
    meters_per_lng = 111320.0 * math.cos(math.radians(lat_mid))

    vx = (back_lng - front_lng) * meters_per_lng
    vy = (back_lat - front_lat) * meters_per_lat
    v_mag_sq = vx * vx + vy * vy

    ux = (passenger_lng - front_lng) * meters_per_lng
    uy = (passenger_lat - front_lat) * meters_per_lat

    t_proj = (ux * vx + uy * vy) / v_mag_sq if v_mag_sq > 0 else 0.0
    dist_along = t_proj * math.sqrt(v_mag_sq)

    # Perpendicular distance from track centerline
    perp_dist = math.sqrt(max(0.0, (ux * ux + uy * uy) - (dist_along * dist_along)))

    # User is on platform if projected distance is within range [-20m, total_length + 20m]
    # and perpendicular distance to platform is within 40m
    is_on_platform = (-25.0 <= dist_along <= total_platform_length + 25.0) and (perp_dist <= 50.0)

    # Fetch coaches for this train from database
    coaches = []
    if train_id:
        try:
            coaches = Coach.query.filter_by(train_id=train_id).order_by(Coach.sequence_no).all()
        except Exception:
            pass

    num_coaches = len(coaches) if coaches else profile.get("compartment_count", 20)
    # Derive compartment length: total distance divided by number of compartments
    derived_compartment_length = total_platform_length / max(1, num_coaches)
    if abs(derived_compartment_length - coach_len) > 8.0:
        # Use real-world catalog standard length if GPS platform coords have slight survey deviation
        effective_coach_length = coach_len
    else:
        effective_coach_length = derived_compartment_length

    # Clamp distance along train
    effective_dist = max(0.0, min(total_platform_length, dist_along if dist_along > 0 else dist_from_front))

    # Compartment index (1-indexed)
    comp_index = int(effective_dist // effective_coach_length) + 1
    comp_index = max(1, min(num_coaches, comp_index))

    comp_start_m = (comp_index - 1) * effective_coach_length
    comp_end_m = comp_index * effective_coach_length
    comp_center_m = (comp_start_m + comp_end_m) / 2.0

    # Probability & confidence calculation based on proximity to center of compartment
    dist_from_comp_center = abs(effective_dist - comp_center_m)
    half_len = effective_coach_length / 2.0
    confidence = max(60, min(98, int(98 - (dist_from_comp_center / half_len) * 35)))

    # Map to Coach object
    matched_coach = None
    if coaches and (comp_index - 1) < len(coaches):
        matched_coach = coaches[comp_index - 1]
    elif coaches:
        matched_coach = coaches[-1]

    coach_code = matched_coach.coach_code if matched_coach else f"C{comp_index}"
    coach_type_name = matched_coach.coach_type if matched_coach else "General / Coach"
    is_general = matched_coach.is_general if matched_coach else (comp_index <= 3)

    return {
        "success": True,
        "is_on_platform": is_on_platform,
        "station_name": station_name,
        "platform_number": platform_number,
        "train_type": effective_train_type,
        "train_id": train_id,
        "train_number": train_number,
        "train_name": train.name if train else "Venad Express",
        "total_train_length_meters": round(total_platform_length, 1),
        "total_compartments": num_coaches,
        "compartment_length_meters": round(effective_coach_length, 1),
        "distance_from_front_m": round(dist_from_front, 1),
        "distance_along_train_m": round(effective_dist, 1),
        "estimated_compartment_number": comp_index,
        "compartment_range": {
            "start_m": round(comp_start_m, 1),
            "end_m": round(comp_end_m, 1)
        },
        "estimated_coach": coach_code,
        "estimated_coach_id": matched_coach.id if matched_coach else None,
        "coach_type": coach_type_name,
        "is_general": is_general,
        "confidence": confidence,
        "probability_percent": confidence,
        "platform_geometry": {
            "front_lat": front_lat,
            "front_lng": front_lng,
            "back_lat": back_lat,
            "back_lng": back_lng
        }
    }


# ============================================================================
# ANCHOR PASSENGER & TRAIN DEPARTURE DETECTION SERVICE
# ============================================================================
class AnchorPassengerManager:
    """
    Manages anchor passengers across the train:
    - Randomly picks anchor passengers from front to back of the train.
    - Refreshes anchor passenger list every 30 seconds.
    - Detects departure when all anchor passengers move simultaneously in route direction.
    - Tracks passenger movement between compartments inside the running train.
    """
    def __init__(self):
        # Key: train_id -> state dict
        self._train_anchors = {}
        self._departure_events = {}

    def get_or_create_anchors(self, train_id, train_lat=9.3178, train_lng=76.6186, heading_deg=90.0, force_refresh=False):
        now = time.time()
        state = self._train_anchors.get(train_id)

        # Re-sample anchor passengers every 30 seconds as specified in prompt
        if not state or force_refresh or (now - state.get("last_refreshed", 0)) > 30.0:
            coaches = Coach.query.filter_by(train_id=train_id).order_by(Coach.sequence_no).all()
            total_coaches = len(coaches) if coaches else 20

            # Distribute anchor roles from front to rear
            sample_seqs = [
                (1, "FRONT", "Passenger A (Front Coach)"),
                (max(2, total_coaches // 3), "MID_FRONT", "Passenger B (Mid-Front)"),
                (max(3, (2 * total_coaches) // 3), "MID_REAR", "Passenger C (Mid-Rear)"),
                (max(4, total_coaches - 2), "REAR", "Passenger D (Rear Coach)"),
            ]

            anchors = []
            for seq, role, name in sample_seqs:
                coach_obj = coaches[seq - 1] if coaches and (seq - 1) < len(coaches) else None
                # Small offset along train line
                offset_meters = seq * 25.0
                offset_lat = train_lat - (offset_meters / 111000.0) * math.cos(math.radians(heading_deg))
                offset_lng = train_lng - (offset_meters / 111000.0) * math.sin(math.radians(heading_deg))

                anchors.append({
                    "role": role,
                    "coach_sequence": seq,
                    "coach_code": coach_obj.coach_code if coach_obj else f"C{seq}",
                    "coach_id": coach_obj.id if coach_obj else None,
                    "passenger_name": name,
                    "latitude": round(offset_lat, 6),
                    "longitude": round(offset_lng, 6),
                    "speed_kmh": 0.0,
                    "heading_deg": heading_deg,
                    "last_distance_moved_m": 0.0
                })

            self._train_anchors[train_id] = {
                "train_id": train_id,
                "anchors": anchors,
                "last_refreshed": now,
                "refreshed_at_iso": datetime.now(timezone.utc).isoformat(),
                "next_refresh_in_sec": 30
            }

        state = self._train_anchors[train_id]
        state["next_refresh_in_sec"] = max(0, int(30 - (now - state["last_refreshed"])))
        return state

    def simulate_train_departure(self, train_id, station_name="Chengannur", speed_kmh=45.0, distance_moved_m=120.0):
        """
        Simulates anchor passengers moving simultaneously in the route direction,
        which triggers the instantaneous departure detection and starts the 1-minute voting timer.
        """
        state = self.get_or_create_anchors(train_id)
        now_dt = datetime.now(timezone.utc)
        
        # All anchor passengers move simultaneously to the same distance and speed
        for a in state["anchors"]:
            a["speed_kmh"] = speed_kmh
            a["last_distance_moved_m"] = distance_moved_m
            # Move slightly north-west along Kerala railway corridor
            a["latitude"] += (distance_moved_m / 111000.0) * 0.8
            a["longitude"] += (distance_moved_m / 111000.0) * 0.6

        departure_record = {
            "train_id": train_id,
            "station_name": station_name,
            "departed_at": now_dt.isoformat(),
            "departed_timestamp": time.time(),
            "status": "DEPARTED",
            "speed_kmh": speed_kmh,
            "detection_method": "SIMULTANEOUS_ANCHOR_MOVEMENT",
            "anchor_count": len(state["anchors"]),
            "vote_notification_due_in_seconds": 60  # 1 minute as specified
        }
        self._departure_events[train_id] = departure_record
        return departure_record

    def get_departure_status(self, train_id):
        return self._departure_events.get(train_id, {
            "train_id": train_id,
            "status": "AT_STATION",
            "departed_at": None,
            "vote_notification_due_in_seconds": None
        })

    def detect_in_train_movement(self, train_id, current_coach_sequence, delta_to_front_anchor, delta_to_rear_anchor):
        """
        Checks if passenger moved between compartments while the train is running:
        If distance to front anchor decreases and to rear anchor increases -> passenger moved forward!
        If distance to rear anchor decreases and to front anchor increases -> passenger moved backward!
        """
        new_sequence = current_coach_sequence
        movement_direction = "STATIONARY"

        # Threshold of ~15-25 meters represents moving through 1 vestibule into next coach
        if delta_to_front_anchor <= -15.0 and delta_to_rear_anchor >= 15.0:
            # Moved towards front
            new_sequence = max(1, current_coach_sequence - 1)
            movement_direction = "FORWARD"
        elif delta_to_rear_anchor <= -15.0 and delta_to_front_anchor >= 15.0:
            # Moved towards rear
            new_sequence = current_coach_sequence + 1
            movement_direction = "REARWARD"

        return {
            "previous_sequence": current_coach_sequence,
            "new_sequence": new_sequence,
            "movement_direction": movement_direction,
            "delta_front_m": delta_to_front_anchor,
            "delta_rear_m": delta_to_rear_anchor
        }

# Global singleton anchor manager
anchor_manager = AnchorPassengerManager()
