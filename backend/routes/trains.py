from flask import Blueprint, jsonify, request
from backend.extensions import db
from backend.models.train import Train
from backend.models.coach import Coach
from backend.models.crowd_report import CrowdReport
from backend.services.crowd_service import calculate_coach_crowd
from backend.services.storage import (
    REAL_WORLD_COACH_SPECS,
    get_train_profile,
    set_train_profile,
)

trains_bp = Blueprint("trains", __name__, url_prefix="/api")

@trains_bp.get("/trains")
def get_trains():
    search = request.args.get("search", "").strip().lower()
    from_stn = request.args.get("from", "").strip().lower()
    to_stn = request.args.get("to", "").strip().lower()

    query = Train.query.order_by(Train.number)
    trains = query.all()
    results = []

    for t in trains:
        t_dict = t.to_dict()
        profile = get_train_profile(t.number)
        t_dict["train_type"] = profile.get("train_type", "Express")
        t_dict["compartment_count"] = len(t.coaches) if t.coaches else profile.get("compartment_count", 20)
        t_dict["coach_length_meters"] = profile.get("coach_length_meters", 25.0)

        # Search matching
        if search:
            if not (search in t.number.lower() or search in t.name.lower() or search in t.origin.lower() or search in t.destination.lower()):
                continue

        # Destination filter
        if to_stn:
            if not (to_stn in t.destination.lower() or to_stn in t.name.lower()):
                if to_stn in "kollam" and not ("kollam" in t.destination.lower() or "thiruvananthapuram" in t.destination.lower() or "tvc" in t.destination.lower()):
                    continue
                elif to_stn in "ernakulam" and not ("ernakulam" in t.destination.lower() or "shoranur" in t.destination.lower() or "mangaluru" in t.destination.lower() or "new delhi" in t.destination.lower()):
                    continue

        # Compute expected crowd summary from general coaches
        gen_coaches = [c for c in t.coaches if c.is_general]
        if gen_coaches:
            summaries = [calculate_coach_crowd(c.id) for c in gen_coaches]
            valid_scores = [s["score"] for s in summaries if s["score"] > 0]
            if valid_scores:
                avg = sum(valid_scores) / len(valid_scores)
                if avg < 1.5:
                    summary_level = "Low"
                elif avg < 2.3:
                    summary_level = "Medium"
                else:
                    summary_level = "High"
            else:
                summary_level = "Medium"
        else:
            summary_level = "Medium"

        t_dict["expected_crowd"] = summary_level
        results.append(t_dict)

    return jsonify(results)

@trains_bp.get("/trains/<int:train_id>")
def get_train_detail(train_id):
    train = db.session.get(Train, train_id)
    if not train:
        return jsonify({"success": False, "message": "Train not found"}), 404
    t_dict = train.to_dict()
    profile = get_train_profile(train.number)
    t_dict["train_type"] = profile.get("train_type", "Express")
    t_dict["compartment_count"] = len(train.coaches) if train.coaches else profile.get("compartment_count", 20)
    t_dict["coach_length_meters"] = profile.get("coach_length_meters", 25.0)
    return jsonify({"success": True, "train": t_dict})

@trains_bp.get("/trains/<int:train_id>/coaches")
def get_train_coaches(train_id):
    train = db.session.get(Train, train_id)
    profile = get_train_profile(train.number) if train else {"coach_length_meters": 25.0}
    coach_len = profile.get("coach_length_meters", 25.0)

    only_general = request.args.get("general_only", "false").lower() == "true"
    query = Coach.query.filter_by(train_id=train_id)
    if only_general:
        query = query.filter_by(is_general=True)
    coaches = query.order_by(Coach.sequence_no).all()

    results = []
    for c in coaches:
        crowd_info = calculate_coach_crowd(c.id)
        start_dist = max(0.0, (c.sequence_no - 1) * coach_len) if c.sequence_no > 0 else 0.0
        end_dist = c.sequence_no * coach_len if c.sequence_no > 0 else coach_len

        results.append({
            "id": c.id,
            "train_id": c.train_id,
            "code": c.coach_code,
            "type": c.coach_type,
            "sequence": c.sequence_no,
            "is_general": c.is_general,
            "distance_from_front": round(c.sequence_no * coach_len, 1),
            "compartment_range": {
                "start_m": round(start_dist, 1),
                "end_m": round(end_dist, 1)
            },
            "length_meters": coach_len,
            **crowd_info
        })
    return jsonify(results)

@trains_bp.post("/trains")
def create_train():
    data = request.get_json(silent=True) or {}
    number = data.get("number", "").strip()
    name = data.get("name", "").strip()
    origin = data.get("origin", "").strip()
    destination = data.get("destination", "").strip()
    train_type = (data.get("train_type") or "Express").strip()

    if not number or not name or not origin or not destination:
        return jsonify({"success": False, "message": "number, name, origin, and destination are required"}), 400

    existing = Train.query.filter_by(number=number).first()
    if existing:
        return jsonify({"success": False, "message": f"Train with number {number} already exists"}), 409

    spec = REAL_WORLD_COACH_SPECS.get(train_type, REAL_WORLD_COACH_SPECS["Express"])
    coach_len = spec["coach_length_meters"]
    comp_count = int(data.get("compartment_count") or spec["default_coaches"])

    train = Train(number=number, name=name, origin=origin, destination=destination)
    db.session.add(train)
    db.session.commit()

    # Save extended train profile
    set_train_profile(number, train_type, comp_count, coach_len)

    # Generate realistic coach formation based on train model and compartment count
    db.session.add(Coach(train_id=train.id, coach_code="ENGINE", coach_type="Locomotive WAP-7", sequence_no=0, is_general=False))
    
    if train_type == "MEMU":
        # DMC, TC1, TC2...
        for seq in range(1, comp_count):
            if seq == comp_count - 1:
                db.session.add(Coach(train_id=train.id, coach_code="DMC2", coach_type="Driving Motor Coach (General)", sequence_no=seq, is_general=True))
            else:
                db.session.add(Coach(train_id=train.id, coach_code=f"TC{seq}", coach_type="Trailer Coach (General)", sequence_no=seq, is_general=True))
    elif train_type in ("Express", "Superfast"):
        # Engine, SLR, GS1, GS2, S1..Sn, B1, A1, GS3, SLR2
        db.session.add(Coach(train_id=train.id, coach_code="SLR1", coach_type="Guard & Luggage Van", sequence_no=1, is_general=False))
        db.session.add(Coach(train_id=train.id, coach_code="GS1", coach_type="General Second (Unreserved)", sequence_no=2, is_general=True))
        db.session.add(Coach(train_id=train.id, coach_code="GS2", coach_type="General Second (Unreserved)", sequence_no=3, is_general=True))
        
        sleeper_count = max(2, comp_count - 8)
        curr_seq = 4
        for s in range(1, sleeper_count + 1):
            db.session.add(Coach(train_id=train.id, coach_code=f"S{s}", coach_type="Sleeper Class (SL)", sequence_no=curr_seq, is_general=False))
            curr_seq += 1

        db.session.add(Coach(train_id=train.id, coach_code="B1", coach_type="AC 3 Tier (3A)", sequence_no=curr_seq, is_general=False))
        curr_seq += 1
        db.session.add(Coach(train_id=train.id, coach_code="A1", coach_type="AC 2 Tier (2A)", sequence_no=curr_seq, is_general=False))
        curr_seq += 1
        db.session.add(Coach(train_id=train.id, coach_code="GS3", coach_type="General Second (Unreserved)", sequence_no=curr_seq, is_general=True))
        curr_seq += 1
        db.session.add(Coach(train_id=train.id, coach_code="SLR2", coach_type="Guard & Power Car", sequence_no=curr_seq, is_general=False))
    else:
        for seq in range(1, comp_count):
            is_gen = seq <= 4 or seq >= comp_count - 2
            code = f"GS{seq}" if is_gen else f"D{seq}"
            ctype = "General Second (Unreserved)" if is_gen else "Second Sitting (2S Reserved)"
            db.session.add(Coach(train_id=train.id, coach_code=code, coach_type=ctype, sequence_no=seq, is_general=is_gen))

    db.session.commit()

    t_dict = train.to_dict()
    t_dict["train_type"] = train_type
    t_dict["compartment_count"] = comp_count
    t_dict["coach_length_meters"] = coach_len

    return jsonify({
        "success": True,
        "message": f"Created train {number} ({name}) with {comp_count} compartments ({coach_len}m each)",
        "train": t_dict
    }), 201

@trains_bp.delete("/trains/<int:train_id>")
def delete_train(train_id):
    train = db.session.get(Train, train_id)
    if not train:
        return jsonify({"success": False, "message": "Train not found"}), 404
    db.session.delete(train)
    db.session.commit()
    return jsonify({"success": True, "message": f"Train {train.number} deleted successfully"})

@trains_bp.post("/trains/<int:train_id>/coaches")
def add_coach(train_id):
    train = db.session.get(Train, train_id)
    if not train:
        return jsonify({"success": False, "message": "Train not found"}), 404

    data = request.get_json(silent=True) or {}
    coach_code = (data.get("coach_code") or "").strip().upper()
    coach_type = (data.get("coach_type") or "General").strip()
    is_general = data.get("is_general", coach_code.startswith("GS") or "General" in coach_type)

    if not coach_code:
        return jsonify({"success": False, "message": "coach_code is required (e.g. GS3, D4, CC2)"}), 400

    existing = Coach.query.filter_by(train_id=train_id, coach_code=coach_code).first()
    if existing:
        return jsonify({"success": False, "message": f"Coach {coach_code} already exists on this train"}), 409

    last_coach = Coach.query.filter_by(train_id=train_id).order_by(Coach.sequence_no.desc()).first()
    next_seq = (last_coach.sequence_no + 1) if last_coach else 1

    new_coach = Coach(
        train_id=train_id,
        coach_code=coach_code,
        coach_type=coach_type,
        sequence_no=next_seq,
        is_general=is_general
    )
    db.session.add(new_coach)
    db.session.commit()

    return jsonify({"success": True, "coach": new_coach.to_dict()}), 201

@trains_bp.post("/trains/<int:train_id>/coaches/template")
def apply_rake_template(train_id):
    train = db.session.get(Train, train_id)
    if not train:
        return jsonify({"success": False, "message": "Train not found"}), 404

    data = request.get_json(silent=True) or {}
    template = data.get("template", "day_intercity").lower()

    if template in ("day_intercity", "venad", "parasuram"):
        coach_codes = ["ENGINE", "SLR1", "GS1", "GS2", "GS3", "D1", "D2", "D3", "D4", "D5", "CC1", "CC2", "D6", "D7", "D8", "GS4", "GS5", "GS6", "SLR2"]
    elif template in ("superfast", "kerala_exp", "long_distance"):
        coach_codes = ["ENGINE", "EOG1", "GS1", "GS2", "S1", "S2", "S3", "S4", "S5", "S6", "PC", "B1", "B2", "B3", "B4", "A1", "A2", "GS3", "GS4", "EOG2"]
    elif template in ("memu", "local", "passenger"):
        coach_codes = ["ENGINE", "GS1", "GS2", "GS3", "GS4", "GS5", "GS6", "GS7", "GS8", "TAIL"]
    else:
        coach_codes = ["ENGINE", "GS1", "GS2", "D1", "D2", "CC1", "GS3", "GS4", "SLR"]

    old_coaches = Coach.query.filter_by(train_id=train_id).all()
    for oc in old_coaches:
        CrowdReport.query.filter_by(coach_id=oc.id).delete()
        db.session.delete(oc)
    db.session.commit()

    seq = 0
    for code in coach_codes:
        is_gen = code.startswith("GS")
        if code == "ENGINE":
            ctype = "Locomotive WAP-7"
        elif is_gen:
            ctype = "General Second (Unreserved)"
        elif code.startswith("D"):
            ctype = "Second Sitting (2S Reserved)"
        elif code.startswith("CC"):
            ctype = "AC Chair Car"
        elif code.startswith("S") and not code.startswith("SLR"):
            ctype = "Sleeper Class (SL)"
        elif code.startswith("B"):
            ctype = "AC 3 Tier (3A)"
        elif code.startswith("A"):
            ctype = "AC 2 Tier (2A)"
        elif code.startswith("PC"):
            ctype = "Pantry Car"
        elif code in ("SLR1", "SLR2", "EOG1", "EOG2", "TAIL"):
            ctype = "Guard & Power Van"
        else:
            ctype = "Second Sitting"

        c = Coach(train_id=train_id, coach_code=code, coach_type=ctype, sequence_no=seq, is_general=is_gen)
        db.session.add(c)
        seq += 1

    db.session.commit()
    return jsonify({"success": True, "template": template, "coach_count": seq, "message": f"Applied {template} rake template successfully"})

@trains_bp.delete("/coaches/<int:coach_id>")
def delete_coach(coach_id):
    coach = db.session.get(Coach, coach_id)
    if not coach:
        return jsonify({"success": False, "message": "Coach not found"}), 404

    if coach.coach_code == "ENGINE":
        return jsonify({"success": False, "message": "Cannot delete locomotive engine"}), 400

    CrowdReport.query.filter_by(coach_id=coach.id).delete()
    db.session.delete(coach)
    db.session.commit()
    return jsonify({"success": True, "message": f"Coach {coach.coach_code} deleted successfully"})
