import os
import sqlite3
import math
from datetime import datetime, timezone

DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "data"))
os.makedirs(DB_DIR, exist_ok=True)
DB_PATH = os.path.join(DB_DIR, "train_extended.db")

# Standard real-world train compartment lengths in meters
REAL_WORLD_COACH_SPECS = {
    "Express": {"coach_length_meters": 25.0, "default_coaches": 20, "description": "LHB / ICF Long Distance Express"},
    "Superfast": {"coach_length_meters": 25.0, "default_coaches": 22, "description": "Superfast Express Mail"},
    "MEMU": {"coach_length_meters": 22.0, "default_coaches": 12, "description": "Mainline Electric Multiple Unit (Suburban)"},
    "Passenger": {"coach_length_meters": 24.0, "default_coaches": 16, "description": "Slow Passenger / Intercity"},
    "Vande Bharat": {"coach_length_meters": 23.5, "default_coaches": 16, "description": "Semi-High Speed Trainset"},
}

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_extended_db():
    with get_db() as conn:
        cursor = conn.cursor()
        
        # 1. Users table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone_or_email TEXT UNIQUE NOT NULL,
            created_at TEXT NOT NULL
        )
        ''')

        # 2. Station platform train stops with front and back coordinates per train model
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS station_train_stops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_name TEXT NOT NULL,
            platform_number INTEGER NOT NULL,
            train_type TEXT NOT NULL,
            front_lat REAL NOT NULL,
            front_lng REAL NOT NULL,
            back_lat REAL NOT NULL,
            back_lng REAL NOT NULL,
            avg_coach_length_meters REAL NOT NULL DEFAULT 25.0,
            UNIQUE(station_name, platform_number, train_type)
        )
        ''')

        # 3. Train profiles (stores train type and compartment count)
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS train_profiles (
            train_number TEXT PRIMARY KEY,
            train_type TEXT NOT NULL DEFAULT 'Express',
            compartment_count INTEGER NOT NULL DEFAULT 20,
            coach_length_meters REAL NOT NULL DEFAULT 25.0
        )
        ''')

        # 4. Anchor passengers for train departure & inside-train movement
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS anchor_passengers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            train_id INTEGER NOT NULL,
            coach_sequence INTEGER NOT NULL,
            anchor_role TEXT NOT NULL, -- 'FRONT', 'MID_FRONT', 'MID_REAR', 'REAR'
            passenger_name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            speed_kmh REAL DEFAULT 0.0,
            heading_deg REAL DEFAULT 90.0,
            refreshed_at TEXT NOT NULL
        )
        ''')

        # 5. Seed default train stops for Kerala stations if empty
        cursor.execute("SELECT COUNT(*) FROM station_train_stops")
        if cursor.fetchone()[0] == 0:
            default_stops = [
                # Chengannur (CNGR)
                # Platform 1
                ("Chengannur", 1, "Express", 9.3188, 76.6196, 9.3145, 76.6162, 25.0),
                ("Chengannur", 1, "MEMU", 9.3180, 76.6190, 9.3156, 76.6171, 22.0),
                ("Chengannur", 1, "Superfast", 9.3192, 76.6200, 9.3142, 76.6160, 25.0),
                # Platform 2
                ("Chengannur", 2, "Express", 9.3190, 76.6198, 9.3147, 76.6164, 25.0),
                ("Chengannur", 2, "MEMU", 9.3182, 76.6192, 9.3158, 76.6173, 22.0),
                ("Chengannur", 2, "Superfast", 9.3194, 76.6202, 9.3144, 76.6162, 25.0),
                # Platform 3
                ("Chengannur", 3, "Express", 9.3192, 76.6200, 9.3149, 76.6166, 25.0),
                ("Chengannur", 3, "MEMU", 9.3184, 76.6194, 9.3160, 76.6175, 22.0),

                # Kollam Junction (QLN)
                ("Kollam Junction", 1, "Express", 8.8878, 76.5962, 8.8835, 76.5930, 25.0),
                ("Kollam Junction", 1, "MEMU", 8.8870, 76.5956, 8.8845, 76.5938, 22.0),
                ("Kollam Junction", 2, "Express", 8.8882, 76.5966, 8.8839, 76.5934, 25.0),

                # Kottayam (KTYM)
                ("Kottayam", 1, "Express", 9.5925, 76.5230, 9.5880, 76.5195, 25.0),
                ("Kottayam", 1, "MEMU", 9.5920, 76.5225, 9.5895, 76.5205, 22.0),
                ("Kottayam", 2, "Express", 9.5930, 76.5235, 9.5885, 76.5200, 25.0),

                # Ernakulam Town (ERN)
                ("Ernakulam Town", 1, "Express", 9.9825, 76.3010, 9.9780, 76.2975, 25.0),
                ("Ernakulam Town", 1, "MEMU", 9.9820, 76.3005, 9.9795, 76.2985, 22.0),
                ("Ernakulam Town", 2, "Express", 9.9830, 76.3015, 9.9785, 76.2980, 25.0),
                ("Ernakulam Town", 2, "MEMU", 9.9825, 76.3010, 9.9800, 76.2990, 22.0),

                # Thiruvananthapuram Central (TVC)
                ("Thiruvananthapuram Central", 1, "Express", 8.4890, 76.9535, 8.4845, 76.9500, 25.0),
                ("Thiruvananthapuram Central", 2, "Express", 8.4895, 76.9540, 8.4850, 76.9505, 25.0),
            ]
            cursor.executemany('''
            INSERT INTO station_train_stops (station_name, platform_number, train_type, front_lat, front_lng, back_lat, back_lng, avg_coach_length_meters)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', default_stops)

        # 6. Seed train profiles for existing trains
        cursor.execute("SELECT COUNT(*) FROM train_profiles")
        if cursor.fetchone()[0] == 0:
            profiles = [
                ("16302", "Express", 19, 25.0),
                ("16301", "Express", 19, 25.0),
                ("16650", "Superfast", 22, 25.0),
                ("16304", "Express", 18, 25.0),
                ("12626", "Superfast", 24, 25.0),
            ]
            cursor.executemany('''
            INSERT OR REPLACE INTO train_profiles (train_number, train_type, compartment_count, coach_length_meters)
            VALUES (?, ?, ?, ?)
            ''', profiles)

        conn.commit()

# Run DB initialization at module import
init_extended_db()

# --- User Management ---
def register_or_login_user(name: str, phone_or_email: str):
    name = name.strip()
    phone_or_email = phone_or_email.strip()
    now_str = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE phone_or_email = ?", (phone_or_email,))
        user = cursor.fetchone()
        if user:
            cursor.execute("UPDATE users SET name = ? WHERE id = ?", (name, user["id"]))
            conn.commit()
            return {"id": user["id"], "name": name, "phone_or_email": user["phone_or_email"], "created_at": user["created_at"]}
        
        cursor.execute("INSERT INTO users (name, phone_or_email, created_at) VALUES (?, ?, ?)", (name, phone_or_email, now_str))
        conn.commit()
        user_id = cursor.lastrowid
        return {"id": user_id, "name": name, "phone_or_email": phone_or_email, "created_at": now_str}

def get_user_by_id(user_id: int):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        return dict(row) if row else None

# --- Station Stop Geometry ---
def get_station_train_stops(station_name: str, platform_number: int = None, train_type: str = None):
    with get_db() as conn:
        cursor = conn.cursor()
        query = "SELECT * FROM station_train_stops WHERE LOWER(station_name) LIKE LOWER(?)"
        params = [f"%{station_name}%"]
        if platform_number is not None:
            query += " AND platform_number = ?"
            params.append(platform_number)
        if train_type:
            query += " AND LOWER(train_type) = LOWER(?)"
            params.append(train_type)
        cursor.execute(query, params)
        rows = cursor.fetchall()
        return [dict(r) for r in rows]

def add_station_train_stop(station_name: str, platform_number: int, train_type: str, front_lat: float, front_lng: float, back_lat: float, back_lng: float, avg_coach_length: float = 25.0):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
        INSERT OR REPLACE INTO station_train_stops (station_name, platform_number, train_type, front_lat, front_lng, back_lat, back_lng, avg_coach_length_meters)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (station_name, platform_number, train_type, front_lat, front_lng, back_lat, back_lng, avg_coach_length))
        conn.commit()
        return cursor.lastrowid

def get_train_profile(train_number: str):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM train_profiles WHERE train_number = ?", (str(train_number),))
        row = cursor.fetchone()
        if row:
            return dict(row)
        return {"train_number": str(train_number), "train_type": "Express", "compartment_count": 20, "coach_length_meters": 25.0}

def set_train_profile(train_number: str, train_type: str, compartment_count: int, coach_length_meters: float = None):
    if not coach_length_meters:
        spec = REAL_WORLD_COACH_SPECS.get(train_type, REAL_WORLD_COACH_SPECS["Express"])
        coach_length_meters = spec["coach_length_meters"]
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
        INSERT OR REPLACE INTO train_profiles (train_number, train_type, compartment_count, coach_length_meters)
        VALUES (?, ?, ?, ?)
        ''', (str(train_number), train_type, compartment_count, coach_length_meters))
        conn.commit()
