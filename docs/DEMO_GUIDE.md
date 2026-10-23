# Project Demonstration & Viva Presentation Guide

This guide provides the exact step-by-step walkthrough to demonstrate your **Train Crowd Monitoring & Prediction System** during project evaluations and viva examinations.

---

## 1. Pre-Demo Setup (2 Minutes)

### Step A: Verify PostgreSQL is Running
Make sure your PostgreSQL service is running and the database is initialized:
```powershell
psql -U postgres -c "SELECT COUNT(*) FROM trains;" train_crowd
```

### Step B: Start the Flask Backend Server
Open a terminal in the project directory:
```powershell
cd d:\FlutterProjects\train_crowd_mvp\backend
.\.venv\Scripts\Activate.ps1
python app.py
```
> Server runs on `http://0.0.0.0:5000`. You will see:
> `Starting Train Crowd Server on 0.0.0.0:5000...`

### Step C: Open Web Dashboards in Browser
Open Chrome/Edge to:
* **Admin Dashboard**: `http://localhost:5000/admin`
* **Simulation Dashboard**: `http://localhost:5000/simulation`

### Step D: Run the Flutter Mobile Application
Open a second terminal:
```powershell
cd d:\FlutterProjects\train_crowd_mvp\passenger_app
flutter run
```
*(Runs on your connected Android physical phone or Android Emulator).*

---

## 2. Live Demo Script (Step-by-Step Flow)

### 🎯 Scene 1: Passenger App Home & Upcoming Trains
1. Show the **Home Screen** on the mobile phone.
2. Point out:
   * **Current Station Card**: Katpadi Junction (KPD) — Platform 2 (Demo Calibrated).
   * **Search Filter**: Type `12602` or `Chennai` to demonstrate instant backend filtering.
   * **Train Card**: Highlights Train `12602 — Chennai Express` with an aggregated crowd status badge (**HIGH** or **MEDIUM**).
3. **Talking Point for Viva**:
   > *"The application presents passengers with expected crowd levels before boarding, specifically focusing on general unreserved coaches which suffer the highest congestion."*

---

### 🎯 Scene 2: Horizontal Coach Formation & Crowd Reporting
1. Tap **"View Crowd"** on Train 12602.
2. Show the **Horizontal Train Formation**:
   `[ENGINE] → [GS1] → [GS2] → [SL1] → [SL2] → [3A] → [2A] → [GS3] → [GS4] → [TAIL]`
3. Point out that **General Coaches (GS)** are visually emphasized with purple badges and distinctive borders.
4. Tap **GS1** coach card $\to$ opens the coach details bottom sheet.
5. Tap **"Report Crowd for this Coach"**:
   * Select **"HIGH CROWD"**.
   * Tap **"Submit Crowd Report"**.
   * Success snackbar appears: *"Thanks! Your report for GS1 was recorded."*
6. **The "Wow" Real-Time Moment**:
   * Switch gaze immediately to the **Admin Dashboard** in your browser:
   * The new report appeared at the top of the **Recent Reports Stream** instantly via **Socket.IO** without any page refresh!
7. **Talking Point for Viva**:
   > *"We do not use simple majority voting. We implemented a time-weighted decay algorithm where reports under 10 minutes have 100% weight, older reports decay gradually, and confidence scales with report freshness."*

---

### 🎯 Scene 3: Stress-Testing with the Simulation Dashboard
1. Switch to the **Simulation Dashboard** tab in your browser (`http://localhost:5000/simulation`).
2. Point out the academic disclaimer banner: `⚠ ACADEMIC SIMULATION MODE ACTIVE`.
3. Click the button: **`+25 Passengers`**.
4. The system injects 25 realistic synthetic passenger reports, heavily weighting general coaches.
5. Watch the **Coach Formation Visualizer** recalculate crowd loads across GS1, GS2, GS3, and GS4 in real time!
6. Open the mobile app again $\to$ coach crowd scores and confidence levels have updated automatically!

---

### 🎯 Scene 4: Real-Time Train GPS Tracking
1. On the **Simulation Dashboard**, click **"Start Transit"**.
2. Notice the train starts moving along the corridor (Chennai $\to$ Katpadi $\to$ Jolarpettai $\to$ Salem).
3. Increase speed to **95 km/h** using the slider.
4. On the mobile phone, switch to the **"Tracker"** tab.
5. Point out:
   * Telemetry card displays: Speed `95 km/h`, Status `IN_TRANSIT`, GPS coordinates.
   * Visual waypoint tracker marks the current station and next stop live.
   * Clear academic disclaimer: *"SIMULATED TRAIN POSITION - For demonstration only."*

---

### 🎯 Scene 5: Platform GPS Coach-Position Estimator
1. On the mobile phone, tap the **"Coach GPS"** tab.
2. Explain the algorithm:
   > *"Using calibrated front and back coordinates for Platform 2 at Katpadi Junction, the system calculates the passenger's distance from the engine and estimates which coach will stop right in front of them."*
3. Tap **"Walk Back →"** by 25 meters $\to$ estimated coach updates dynamically from `GS1` to `GS2` with a `74% Confidence` indicator!
4. Point out the **"Choose Manually"** fallback chips for situations when GPS accuracy is low or underground.

---

### 🎯 Scene 6: Machine Learning Crowd Forecast
1. On the mobile phone, tap the **"Forecast"** tab.
2. Select Coach: `GS1`, Station: `KPD`, Departure Hour: `18:00 hrs` (Peak evening rush).
3. Tap **"Calculate ML Prediction"**.
4. Show the result:
   * Predicted Crowd: **HIGH**
   * Model Confidence: **92%**
   * **Inference Factors (Model Explainability)**:
     * Coach: GS1 (General Unreserved)
     * Scheduled Time: 18:00 (Rush window: Yes)
     * Boarding Station: KPD
     * Algorithm: Random Forest Classifier (Synthetic demo dataset)

---

### 🎯 Scene 7: In-App Settings & Network Configuration
1. Tap the **"Settings"** tab.
2. Show the configurable **API Base URL** and tap **"Save & Test Connection"** $\to$ green checkmark: *"Connected successfully to backend!"*.
3. Explain that this allows testing on physical Android devices across any Wi-Fi network without recompiling Dart code.

---

## 3. Frequently Asked Viva Questions & Strong Answers

| Examiner Question | Your Winning Answer |
| :--- | :--- |
| **Q: Why focus primarily on General (GS) coaches?** | *"Reserved AC and Sleeper coaches have strictly allocated berths with chart occupancy. In contrast, General unreserved coaches have no assigned seating, leading to severe unpredictable overcrowding. That is where passenger crowdsourcing provides the greatest real-world utility."* |
| **Q: How does your aggregation prevent old reports from skewing the data?** | *"We implemented a time-weighted decay function. Reports $<10$ minutes old receive weight 1.0; reports $10–30$ minutes old receive weight 0.6; reports $30–60$ minutes old receive weight 0.3; and reports older than 1 hour expire to Unknown."* |
| **Q: Can GPS identify the exact coach with 100% precision?** | *"No, consumer smartphone GPS typically has an error margin of 5 to 10 meters. Therefore, we explicitly label the coach position as an approximate estimate with a confidence percentage, and provide a manual coach selection fallback."* |
| **Q: What machine learning algorithm was used?** | *"We used a Scikit-Learn Random Forest Classifier. It evaluates categorical factors (station, coach type) and continuous features (hour of day, day of week, recent report volume) to classify crowd rush into Low, Medium, or High with explainable factors."* |
| **Q: Is this real railway data?** | *"No. In accordance with ethical software practices, all data is explicitly badged as DEMO, ESTIMATED, or SIMULATED. We never fabricate connections to official railway APIs."* |
