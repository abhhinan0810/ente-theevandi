import os
import sys
from datetime import datetime, timedelta, timezone

# Ensure project root in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app import create_app
from backend.extensions import db
from backend.models import Train, Coach, CrowdReport

app = create_app()

with app.app_context():
    def set_coaches_for_train(train_num, coach_specs):
        t = Train.query.filter_by(number=train_num).first()
        if not t:
            print(f"Train {train_num} not found")
            return
        
        # Clear existing crowd reports and coaches
        existing_coaches = Coach.query.filter_by(train_id=t.id).all()
        for c in existing_coaches:
            CrowdReport.query.filter_by(coach_id=c.id).delete()
            db.session.delete(c)
        db.session.commit()
        
        seq = 0
        coaches_added = []
        for code, ctype, is_gen in coach_specs:
            c = Coach(
                train_id=t.id,
                coach_code=code,
                coach_type=ctype,
                sequence_no=seq,
                is_general=is_gen
            )
            db.session.add(c)
            coaches_added.append(c)
            seq += 1
        db.session.commit()
        print(f"Set {len(coaches_added)} coaches for {train_num} ({t.name})")
        return coaches_added

    # 1. 16302 Venad Express (TVC -> SRR) - Realistic 19 coaches Day Intercity
    venad_coaches = [
        ('ENGINE', 'Locomotive WAP-7', False),
        ('SLR1', 'Guard & Luggage Van', False),
        ('GS1', 'General Second (Unreserved)', True),
        ('GS2', 'General Second (Unreserved)', True),
        ('GS3', 'General Second (Unreserved)', True),
        ('D1', 'Second Sitting (2S Reserved)', False),
        ('D2', 'Second Sitting (2S Reserved)', False),
        ('D3', 'Second Sitting (2S Reserved)', False),
        ('D4', 'Second Sitting (2S Reserved)', False),
        ('D5', 'Second Sitting (2S Reserved)', False),
        ('D6', 'Second Sitting (2S Reserved)', False),
        ('CC1', 'AC Chair Car', False),
        ('CC2', 'AC Chair Car', False),
        ('D7', 'Second Sitting (2S Reserved)', False),
        ('D8', 'Second Sitting (2S Reserved)', False),
        ('D9', 'Second Sitting (2S Reserved)', False),
        ('GS4', 'General Second (Unreserved)', True),
        ('GS5', 'General Second (Unreserved)', True),
        ('GS6', 'General Second (Unreserved)', True),
        ('SLR2', 'Guard & Luggage Van', False),
    ]
    set_coaches_for_train('16302', venad_coaches)

    # 2. 16301 Venad Express (Down) (SRR -> TVC)
    set_coaches_for_train('16301', venad_coaches)

    # 3. 16650 Parasuram Express (NCJ -> MAQ) - Highly popular Day Express
    parasuram_coaches = [
        ('ENGINE', 'Locomotive WAP-7', False),
        ('SLR1', 'Guard Van', False),
        ('GS1', 'General Second (Unreserved)', True),
        ('GS2', 'General Second (Unreserved)', True),
        ('GS3', 'General Second (Unreserved)', True),
        ('D1', 'Second Sitting (2S Reserved)', False),
        ('D2', 'Second Sitting (2S Reserved)', False),
        ('D3', 'Second Sitting (2S Reserved)', False),
        ('D4', 'Second Sitting (2S Reserved)', False),
        ('D5', 'Second Sitting (2S Reserved)', False),
        ('CC1', 'AC Chair Car', False),
        ('CC2', 'AC Chair Car', False),
        ('D6', 'Second Sitting (2S Reserved)', False),
        ('D7', 'Second Sitting (2S Reserved)', False),
        ('D8', 'Second Sitting (2S Reserved)', False),
        ('GS4', 'General Second (Unreserved)', True),
        ('GS5', 'General Second (Unreserved)', True),
        ('GS6', 'General Second (Unreserved)', True),
        ('SLR2', 'Guard Van', False),
    ]
    set_coaches_for_train('16650', parasuram_coaches)

    # 4. 16304 Vanchinad Express (TVC -> ERS) - Kottayam Line Express
    vanchinad_coaches = [
        ('ENGINE', 'Locomotive WAP-7', False),
        ('SLR1', 'Guard Van', False),
        ('GS1', 'General Second (Unreserved)', True),
        ('GS2', 'General Second (Unreserved)', True),
        ('GS3', 'General Second (Unreserved)', True),
        ('D1', 'Second Sitting (2S Reserved)', False),
        ('D2', 'Second Sitting (2S Reserved)', False),
        ('D3', 'Second Sitting (2S Reserved)', False),
        ('D4', 'Second Sitting (2S Reserved)', False),
        ('CC1', 'AC Chair Car', False),
        ('D5', 'Second Sitting (2S Reserved)', False),
        ('D6', 'Second Sitting (2S Reserved)', False),
        ('D7', 'Second Sitting (2S Reserved)', False),
        ('GS4', 'General Second (Unreserved)', True),
        ('GS5', 'General Second (Unreserved)', True),
        ('GS6', 'General Second (Unreserved)', True),
        ('SLR2', 'Guard Van', False),
    ]
    set_coaches_for_train('16304', vanchinad_coaches)

    # 5. 12626 Kerala Express (NDLS -> TVC) - 23-Coach Premier Superfast LHB
    kerala_exp_coaches = [
        ('ENGINE', 'Locomotive WAP-7', False),
        ('EOG1', 'End On Generator Van', False),
        ('GS1', 'General Second (Unreserved)', True),
        ('GS2', 'General Second (Unreserved)', True),
        ('S1', 'Sleeper Class (SL)', False),
        ('S2', 'Sleeper Class (SL)', False),
        ('S3', 'Sleeper Class (SL)', False),
        ('S4', 'Sleeper Class (SL)', False),
        ('S5', 'Sleeper Class (SL)', False),
        ('S6', 'Sleeper Class (SL)', False),
        ('PC', 'Pantry Car', False),
        ('B1', 'AC 3 Tier (3A)', False),
        ('B2', 'AC 3 Tier (3A)', False),
        ('B3', 'AC 3 Tier (3A)', False),
        ('B4', 'AC 3 Tier (3A)', False),
        ('B5', 'AC 3 Tier (3A)', False),
        ('B6', 'AC 3 Tier (3A)', False),
        ('A1', 'AC 2 Tier (2A)', False),
        ('A2', 'AC 2 Tier (2A)', False),
        ('H1', 'AC First Class (1A)', False),
        ('GS3', 'General Second (Unreserved)', True),
        ('GS4', 'General Second (Unreserved)', True),
        ('EOG2', 'End On Generator Van', False),
    ]
    set_coaches_for_train('12626', kerala_exp_coaches)

    # 6. 12602 Chennai Express (Demo)
    chennai_coaches = [
        ('ENGINE', 'Locomotive WAP-7', False),
        ('SLR1', 'Guard Van', False),
        ('GS1', 'General Second (Unreserved)', True),
        ('GS2', 'General Second (Unreserved)', True),
        ('S1', 'Sleeper Class (SL)', False),
        ('S2', 'Sleeper Class (SL)', False),
        ('S3', 'Sleeper Class (SL)', False),
        ('B1', 'AC 3 Tier (3A)', False),
        ('B2', 'AC 3 Tier (3A)', False),
        ('A1', 'AC 2 Tier (2A)', False),
        ('GS3', 'General Second (Unreserved)', True),
        ('GS4', 'General Second (Unreserved)', True),
        ('SLR2', 'Guard Van', False),
    ]
    set_coaches_for_train('12602', chennai_coaches)

    # Seed live crowd reports for general coaches at Kerala stations
    now = datetime.now(timezone.utc)
    all_gen_coaches = Coach.query.filter_by(is_general=True).all()
    crowd_pattern = ['High', 'High', 'Medium', 'Medium', 'Low', 'Medium', 'High', 'Low']
    stations = ['Chengannur', 'Kollam', 'Kottayam', 'Ernakulam Town']
    for idx, c in enumerate(all_gen_coaches):
        for rep_i in range(3):
            lvl = crowd_pattern[(idx + rep_i) % len(crowd_pattern)]
            stn = stations[(idx + rep_i) % len(stations)]
            report = CrowdReport(
                coach_id=c.id,
                station_name=stn,
                level=lvl,
                created_at=now - timedelta(minutes=(idx * 4 + rep_i * 9) % 50)
            )
            db.session.add(report)
    db.session.commit()
    print("ALL REAL-LIFE TRAIN COMPARTMENT ARRANGEMENTS & CROWD STATUS SEEDED!")
