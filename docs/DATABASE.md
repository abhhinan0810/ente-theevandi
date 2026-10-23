# Train Crowd Monitoring System - Database Documentation

## Database Engine
- **RDBMS**: PostgreSQL 14+
- **Database Name**: `train_crowd`
- **Driver**: `psycopg` (v3 binary) + `SQLAlchemy` ORM

---

## 1. Quick Setup (Windows)

Run the following commands in PowerShell or Command Prompt:

```powershell
# 1. Create database
psql -U postgres -c "CREATE DATABASE train_crowd;"

# 2. Run schema and seed
psql -U postgres -d train_crowd -f backend/schema.sql
psql -U postgres -d train_crowd -f backend/seed.sql
```
*(If using pgAdmin: open Query Tool on `train_crowd`, paste `backend/schema.sql` and run, then paste `backend/seed.sql` and run).*

---

## 2. Entity-Relationship Design

```
+------------------+         +--------------------+         +--------------------+
|     stations     |         |       trains       | 1     * |      coaches       |
+------------------+         +--------------------+<--------+--------------------+
| id (PK)          |         | id (PK)            |         | id (PK)            |
| code (UNIQUE)    |         | number (UNIQUE)    |         | train_id (FK)      |
| name             |         | name               |         | coach_code         |
+------------------+         | origin             |         | coach_type         |
                             | destination        |         | sequence_no        |
                             | length_meters      |         | is_general         |
                             +--------------------+         +--------------------+
                                       |                              | 1
                                       |                              |
                                       |                              | *
+-------------------------+            | 1                  +--------------------+
|    station_platforms    |            |                    |   crowd_reports    |
+-------------------------+            |                    +--------------------+
| id (PK)                 |            |                    | id (PK)            |
| station_name            |            |                    | coach_id (FK)      |
| platform_number         |            |                    | station_name       |
| start_lat / start_lng   |            |                    | level (Low/Med/Hi) |
| end_lat / end_lng       |            |                    | source (USER/SIM)  |
+-------------------------+            |                    | created_at         |
                                       |                    +--------------------+
                                       | 1
                             +--------------------+
                             |  train_locations   |
                             +--------------------+
                             | id (PK)            |
                             | train_id (FK, UQ)  |
                             | current_station    |
                             | next_station       |
                             | latitude/longitude |
                             | speed_kmh / status |
                             | is_simulated       |
                             +--------------------+
```

---

## 3. Table Definitions

### `stations`
Stores railway demo stations along the monitored corridor.
- `id`: `SERIAL PRIMARY KEY`
- `code`: `VARCHAR(10) UNIQUE NOT NULL` (e.g. `KPD`, `MAS`)
- `name`: `VARCHAR(100) NOT NULL` (e.g. `Katpadi Junction`)

### `trains`
Stores trains monitored by the application.
- `id`: `SERIAL PRIMARY KEY`
- `number`: `VARCHAR(10) UNIQUE NOT NULL` (e.g. `12602`)
- `name`: `VARCHAR(100) NOT NULL` (e.g. `Chennai Express (Demo)`)
- `origin`: `VARCHAR(100) NOT NULL`
- `destination`: `VARCHAR(100) NOT NULL`
- `length_meters`: `DOUBLE PRECISION DEFAULT 450.0`

### `coaches`
Stores the coach formation for each train in sequence order.
- `id`: `SERIAL PRIMARY KEY`
- `train_id`: `INTEGER REFERENCES trains(id) ON DELETE CASCADE`
- `coach_code`: `VARCHAR(12) NOT NULL` (`GS1`, `SL1`, `3A`, etc.)
- `coach_type`: `VARCHAR(30) NOT NULL` (`General`, `Sleeper`, `AC 3 Tier`)
- `sequence_no`: `INTEGER NOT NULL`
- `is_general`: `BOOLEAN NOT NULL DEFAULT FALSE`
- `distance_from_front`: `DOUBLE PRECISION DEFAULT 0.0`
- `length_meters`: `DOUBLE PRECISION DEFAULT 24.0`
- *Constraints*: `UNIQUE(train_id, coach_code)`, `UNIQUE(train_id, sequence_no)`

### `crowd_reports`
Stores crowdsourced reports submitted by passengers and simulated users.
- `id`: `SERIAL PRIMARY KEY`
- `coach_id`: `INTEGER REFERENCES coaches(id) ON DELETE CASCADE`
- `station_name`: `VARCHAR(100) NOT NULL`
- `level`: `VARCHAR(10) NOT NULL CHECK (level IN ('Low','Medium','High'))`
- `source`: `VARCHAR(20) NOT NULL DEFAULT 'USER'` (`USER` or `SIMULATION`)
- `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- *Index*: `idx_reports_coach_time ON crowd_reports(coach_id, created_at DESC)` for high-speed time-decayed aggregation queries.

### `station_platforms`
Calibrated bounding geometry for demo station platforms.
- `id`: `SERIAL PRIMARY KEY`
- `station_name`: `VARCHAR(100) NOT NULL`
- `platform_number`: `INTEGER NOT NULL`
- `start_lat`, `start_lng`: `DOUBLE PRECISION NOT NULL`
- `end_lat`, `end_lng`: `DOUBLE PRECISION NOT NULL`
- *Constraints*: `UNIQUE(station_name, platform_number)`

### `stopping_profiles`
Calibration profile mapping train stopping positions at specific platforms.
- `id`: `SERIAL PRIMARY KEY`
- `train_id`: `INTEGER REFERENCES trains(id) ON DELETE CASCADE`
- `station_name`: `VARCHAR(100) NOT NULL`
- `platform_number`: `INTEGER NOT NULL`
- `front_lat`, `front_lng`: `DOUBLE PRECISION NOT NULL`
- `avg_coach_length_meters`: `DOUBLE PRECISION DEFAULT 24.0`

### `train_locations`
Real-time tracking coordinates for simulated train movements.
- `id`: `SERIAL PRIMARY KEY`
- `train_id`: `INTEGER REFERENCES trains(id) ON DELETE CASCADE UNIQUE`
- `current_station`: `VARCHAR(100) NOT NULL`
- `next_station`: `VARCHAR(100) NOT NULL`
- `latitude`, `longitude`: `DOUBLE PRECISION NOT NULL`
- `speed_kmh`: `DOUBLE PRECISION DEFAULT 60.0`
- `status`: `VARCHAR(50) DEFAULT 'IN_TRANSIT'`
- `is_simulated`: `BOOLEAN DEFAULT TRUE`
- `updated_at`: `TIMESTAMPTZ DEFAULT NOW()`

---

## 4. Privacy & Data Handling
- **No PII Collected**: The system stores zero names, mobile numbers, or emails.
- **Anonymous Reporting**: Passenger reports only record the target coach and time.
- **Ephemeral Location**: Real-time passenger GPS is only used in-memory for the platform-distance calculation and is never stored permanently.
