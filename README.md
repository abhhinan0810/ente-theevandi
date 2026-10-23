# Train Crowd Monitoring & GPS Coach Positioning System

> **Railway Mini-Project**: A full-stack, real-time railway passenger crowd estimation, platform GPS coach-position approximation, anchor passenger kinematics, and crowdsourced voting system.

---

## 🚆 System Overview

The **Train Crowd Monitoring & GPS Coach Positioning System** assists railway passengers in determining the expected crowding level of train coaches before boarding, with primary emphasis on **General / Unreserved (GS) coaches**.

### Key System Highlights
* **Coordinate-Based Compartment Division**:
  * Stations feature defined platform front (engine) and back (tail) stopping coordinates for each train model (`Express`, `MEMU`, `Superfast`).
  * Total platform stop length is divided into equal coach segments according to standard coach lengths (e.g. 25m for Express, 22m for MEMU).
  * Measures distance between passenger and train front stop coordinate to determine boarding compartment probability (e.g., 85m $\to$ Compartment 3 / GS2).
* **Anchor Passenger Kinematics & Departure Detection**:
  * Samples random anchor passengers from front to back of the train (auto-refreshed every 30 seconds).
  * Detects train departure instantaneously when anchor passengers move simultaneously in the train's route direction.
  * Tracks in-train passenger movement between compartments by checking relative distance changes between front and rear anchor passengers.
* **1-Minute Post-Departure Crowdsourced Voting**:
  * Exactly 1 minute after train departure, prompts the passenger for live crowd feedback for their compartment.
  * Instant voting (`Low 🟢`, `Medium 🟡`, `High 🔴`) stored in the database with coach ID and station context.
* **"Where Is My Train" Dashboard**:
  * Displays *"You're at: [Station]"*, Platform No, and estimated Coach position.
  * Hidden presentation selector to simulate station, platform, and coach for college viva presentations without physical station presence.
  * From & To route search filter.
  * Upcoming trains list with **two primary action buttons**:
    1. **View Crowd**: Coach-by-coach visual heatmaps and crowd levels.
    2. **Track Train**: Real-time simulated GPS tracking and station path.
* **Interactive Admin Console & Simulation Cockpit**:
  * Web-based **Admin Console** to register new stations, define platform front & back stop coordinates per train model, and add trains deriving coach lengths.
  * Web-based **Simulation Cockpit** to direct trains to stations, adjust speed, and simulate passenger boarding & crowd voting.

---

## 🏗️ Technology Stack

| Layer | Technologies Used |
| :--- | :--- |
| **Mobile Passenger App** | Flutter 3.x, Dart 3.x, Material 3, HTTP |
| **Backend Web Server** | Python 3.13, Flask 3.x, Flask-CORS, Flask-SocketIO |
| **Database** | SQLite / PostgreSQL, SQLAlchemy ORM |
| **Web Dashboards** | Vanilla HTML5, CSS3 (Railway Transit Dark Theme), JavaScript ES6, Socket.IO Client |

---

## 📁 Project Architecture & Directory Structure

```
train_crowd_mvp/
├── backend/
│   ├── app.py                      # Application factory, blueprints & static hosting
│   ├── config.py                   # Environment configuration (.env loader)
│   ├── extensions.py               # Shared SQLAlchemy & SocketIO instances
│   ├── requirements.txt            # Python dependencies
│   ├── test_suite.py               # Automated unit tests for backend algorithms
│   ├── test_socket.py              # WebSocket connectivity test script
│   ├── models/                     # SQLAlchemy ORM models
│   │   ├── station.py
│   │   ├── train.py
│   │   ├── coach.py
│   │   ├── crowd_report.py
│   │   └── train_location.py
│   ├── routes/                     # Blueprint controllers
│   │   ├── auth.py                 # Passenger login & registration
│   │   ├── trains.py               # Train schedules, rake profiles & coach layouts
│   │   ├── stations.py             # Stations & platform stopping geometry
│   │   ├── crowd.py                # Crowd reports & time-decay scoring
│   │   ├── tracking.py             # Coach GPS estimation & anchor departure detection
│   │   └── simulation.py           # Virtual passenger spawn & train movement
│   └── services/                   # Business logic engines
│       ├── crowd_service.py        # Time-decay score calculation
│       ├── location_service.py     # Platform coordinate coach division & anchor kinematics
│       ├── simulation_service.py   # Multi-passenger generator & train path
│       └── storage.py              # SQLite storage for stops, profiles & users
├── passenger_app/                  # Flutter Mobile Passenger Application
│   ├── lib/
│   │   ├── main.dart               # App entrypoint & navigation
│   │   ├── theme/app_theme.dart    # Theme tokens & styling
│   │   ├── services/
│   │   │   ├── api_service.dart    # REST API client
│   │   │   └── user_session.dart   # Passenger session, location override & voting state
│   │   ├── screens/
│   │   │   ├── login_screen.dart             # Passenger sign in
│   │   │   ├── home_screen.dart              # Where Is My Train dashboard & route picker
│   │   │   ├── crowd_screen.dart             # Visual coach-by-coach crowd heatmaps
│   │   │   ├── track_train_screen.dart       # Live simulated GPS train tracking
│   │   │   ├── coach_estimation_screen.dart  # Platform coordinate compartment division
│   │   │   ├── student_simulation_screen.dart# College viva demo console (anchors & 1-min vote)
│   │   │   └── settings_screen.dart          # Server URL & user profile
│   │   └── widgets/                          # Reusable components
├── admin_dashboard/                # Web Admin Portal (Stations, Platforms, Rakes)
│   ├── index.html
│   ├── script.js
│   └── style.css
└── simulation/                     # Web Simulator Cockpit
    ├── index.html
    ├── script.js
    └── style.css
```

---

## 🚀 Running the System

### 1. Start the Flask Backend Server
```powershell
cd d:\FlutterProjects\train_crowd_mvp\backend
.\.venv\Scripts\python.exe app.py
```
* **Admin Console**: `http://localhost:5000/admin/`
* **Simulation Cockpit**: `http://localhost:5000/simulation/`
* **API Health Check**: `http://localhost:5000/api/health`

### 2. Run the Flutter Mobile App
```powershell
cd d:\FlutterProjects\train_crowd_mvp\passenger_app
flutter run
```
"# train_crowd_mvp" 
