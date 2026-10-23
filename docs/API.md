# Train Crowd Monitoring & Prediction System - API Documentation

## Base URL
- **Localhost Development**: `http://localhost:5000/api`
- **Android Physical Device (LAN)**: `http://<YOUR_LAPTOP_IP>:5000/api`
- **Android Emulator**: `http://10.0.2.2:5000/api`

---

## 1. System & Health

### `GET /api/health`
Returns system status, PostgreSQL database connectivity, and Socket.IO status.

**Response (200 OK):**
```json
{
  "status": "ok",
  "database": "connected",
  "socketio": "enabled",
  "version": "1.0.0-mca-mvp"
}
```

---

## 2. Trains

### `GET /api/trains`
Returns a list of all monitored trains. Supports query string search.

**Query Parameters:**
- `search` *(optional)*: Filter by train number, name, or destination (e.g. `?search=chennai`)

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "number": "12602",
    "name": "Chennai Express (Demo)",
    "origin": "Chennai Central",
    "destination": "Mangaluru Central",
    "length_meters": 450.0,
    "coach_count": 9,
    "expected_crowd": "High"
  }
]
```

### `GET /api/trains/<train_id>/coaches`
Returns the coach formation of a train with real-time aggregated crowd estimations.

**Query Parameters:**
- `general_only` *(optional)*: Set to `true` to return only unreserved General coaches (`GS`).

**Response (200 OK):**
```json
[
  {
    "id": 2,
    "train_id": 1,
    "code": "GS1",
    "type": "General",
    "sequence": 1,
    "is_general": true,
    "distance_from_front": 24.0,
    "length_meters": 24.0,
    "level": "High",
    "score": 2.75,
    "reports": 8,
    "confidence": 84,
    "updated": "2 min ago",
    "breakdown": {
      "Low": 0,
      "Medium": 2,
      "High": 6
    }
  }
]
```

### `POST /api/trains`
Registers a new train record (Admin Console).

**Request Body:**
```json
{
  "number": "12626",
  "name": "Kerala Express",
  "origin": "New Delhi",
  "destination": "Thiruvananthapuram"
}
```

---

## 3. Crowd Reporting & Aggregation

### `POST /api/crowd-reports`
Submits a passenger crowd report. Automatically triggers time-weighted score re-computation and emits a `crowd_update` Socket.IO event.

**Request Body:**
```json
{
  "coach_id": 2,
  "level": "High",
  "station_name": "Katpadi Junction",
  "source": "USER"
}
```
*Allowed levels: `Low`, `Medium`, `High`*

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Thanks! Your crowd report has been recorded.",
  "data": {
    "coach_id": 2,
    "coach_code": "GS1",
    "train_id": 1,
    "level": "High",
    "score": 2.8,
    "reports": 9,
    "confidence": 86,
    "updated": "Just now"
  }
}
```

### `GET /api/crowd-reports/recent`
Returns recent reports for the live admin stream.
- Query Parameter: `limit` (default: 50)

---

## 4. Train GPS Tracking & Positioning

### `GET /api/train-positions/<train_id>`
Returns the simulated train telemetry, coordinates, and transit status.

**Response (200 OK):**
```json
{
  "success": true,
  "disclaimer": "SIMULATED TRAIN POSITION - For demonstration only. Not official railway tracking data.",
  "location": {
    "train_id": 1,
    "train_number": "12602",
    "current_station": "Katpadi Junction",
    "next_station": "Jolarpettai Junction",
    "latitude": 12.9716,
    "longitude": 79.1325,
    "speed_kmh": 72.0,
    "status": "IN_TRANSIT",
    "is_simulated": true,
    "updated_at": "2026-10-05T08:35:00Z"
  }
}
```

### `POST /api/location/estimate-coach`
Estimates the nearest coach for a passenger standing on a platform using platform geometry and Haversine distance.

**Request Body:**
```json
{
  "station_name": "Katpadi Junction",
  "platform_number": 2,
  "latitude": 12.9718,
  "longitude": 79.1328,
  "train_id": 1
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "train_id": 1,
  "station_name": "Katpadi Junction",
  "platform_number": 2,
  "estimated_coach": "GS2",
  "coach_type": "General",
  "distance_from_front_m": 52.4,
  "confidence": 74,
  "is_approximate": true,
  "note": "Approximate GPS demo estimation. Station stopping positions vary."
}
```

---

## 5. Machine Learning Prediction

### `GET /api/predictions/<train_id>`
Predicts future crowd rush using a Random Forest model trained on synthetic historical patterns.

**Query Parameters:**
- `station` *(optional)*: Station code (e.g. `KPD`, `MAS`, `CBE`)
- `coach` *(optional)*: Coach code (e.g. `GS1`, `SL1`, `3A`)
- `hour` *(optional)*: Target departure hour (0–23)

**Response (200 OK):**
```json
{
  "success": true,
  "train_id": 1,
  "train_number": "12602",
  "train_name": "Chennai Express (Demo)",
  "coach_code": "GS1",
  "station": "KPD",
  "hour": 18,
  "predicted_level": "High",
  "confidence": 92,
  "factors": [
    "Coach: GS1 (General Unreserved)",
    "Scheduled Time: 18:00 (Rush window: Yes)",
    "Boarding Station: KPD",
    "Recent User Reports: 8 recorded (Avg score: 2.75)",
    "Algorithm: Random Forest Classifier (Synthetic demo dataset)"
  ],
  "disclaimer": "PREDICTION DATA - Generated using synthetic machine learning models. Not official railway data."
}
```

---

## 6. Simulation Controls

### `POST /api/simulation/passengers`
Spawns a batch of virtual passengers and generates realistic crowd reports across coaches.
- Body: `{"train_id": 1, "count": 25, "station_name": "Katpadi Junction"}`

### `POST /api/simulation/train-move`
Advances the simulated train along route waypoints and broadcasts updated telemetry.
- Body: `{"train_id": 1, "step": 0.05, "speed": 75.0}`

### `POST /api/simulation/reset`
Clears simulated reports and resets train position to starting demo coordinates.

---

## 7. Real-Time Socket.IO Events

| Event Name | Direction | Payload | Description |
| :--- | :--- | :--- | :--- |
| `crowd_update` | Server $\to$ Client | `{coach_id, level, score, reports, confidence}` | Fired whenever a passenger or simulation reports crowd. |
| `crowd_batch_update` | Server $\to$ Client | `{train_id, summaries}` | Fired after batch passenger spawning in simulation. |
| `train_position_update` | Server $\to$ Client | `{latitude, longitude, speed_kmh, status}` | Fired as the simulated train travels between stations. |
| `simulation_update` | Server $\to$ Client | `{action: "spawned" / "reset"}` | Informs dashboards to refresh KPI counts. |
