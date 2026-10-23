// Simulation Dashboard Script
const SERVER_URL = (!window.location.hostname || window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1")
  ? "http://localhost:5000" 
  : `${window.location.protocol}//${window.location.hostname}:5000`;
const API_BASE = `${SERVER_URL}/api`;

let socket = null;
let allTrains = [];
let movementInterval = null;
let currentTrainId = null;

const DEMO_WAYPOINTS = [
  "Thiruvananthapuram Central", "Kollam Junction", "Kayamkulam Junction", 
  "Mavelikara", "Chengannur", "Tiruvalla", "Changanassery", 
  "Kottayam", "Ernakulam Town", "Shoranur Junction"
];

document.addEventListener("DOMContentLoaded", () => {
  initSocket();
  loadTrains();
  renderTimeline("Chengannur");
  setupEventListeners();
});

// Socket.IO Setup
function initSocket() {
  const statusEl = document.getElementById("socketStatusText");
  try {
    socket = io(SERVER_URL);
    socket.on("connect", () => {
      statusEl.textContent = "Live Socket Online";
      statusEl.style.color = "var(--accent-cyan)";
    });
    socket.on("disconnect", () => {
      statusEl.textContent = "Socket Disconnected";
      statusEl.style.color = "var(--red)";
    });
    socket.on("train_position_update", (loc) => {
      updateTelemetryUI(loc);
    });
    socket.on("crowd_batch_update", (data) => {
      if (currentTrainId === data.train_id) {
        fetchCoachesVisualizer(currentTrainId);
      }
    });
    socket.on("crowd_update", (data) => {
      if (currentTrainId === data.train_id) {
        fetchCoachesVisualizer(currentTrainId);
      }
    });
  } catch (err) {
    statusEl.textContent = "Socket Offline";
  }
}

// Load Trains
async function loadTrains() {
  try {
    const res = await fetch(`${API_BASE}/trains`);
    allTrains = await res.json();
    const select = document.getElementById("simTrainSelect");
    select.innerHTML = allTrains.map(t => `<option value="${t.id}">${t.number} - ${t.name}</option>`).join("");

    if (allTrains.length > 0) {
      currentTrainId = allTrains[0].id;
      fetchCoachesVisualizer(currentTrainId);
      fetchInitialTelemetry(currentTrainId);
    }
  } catch (err) {
    console.error("Failed to load trains:", err);
  }
}

// Fetch Coaches Visualizer
async function fetchCoachesVisualizer(trainId) {
  const container = document.getElementById("coachesFlowContainer");
  try {
    const res = await fetch(`${API_BASE}/trains/${trainId}/coaches`);
    const coaches = await res.json();

    container.innerHTML = coaches.map(c => `
      <div class="coach-chip ${c.is_general ? 'general' : ''}">
        <div class="code">${c.code}</div>
        <div class="type">${c.type}</div>
        <div class="crowd-tag ${c.level}">${c.level}</div>
        <div class="reports-count">${c.reports || 0} reports (${c.confidence || 0}%)</div>
      </div>
    `).join("");
  } catch (err) {
    container.innerHTML = `<p class="error">Failed to load coach formation</p>`;
  }
}

// Fetch Initial Train Telemetry
async function fetchInitialTelemetry(trainId) {
  try {
    const res = await fetch(`${API_BASE}/train-positions/${trainId}`);
    const data = await res.json();
    if (data.success && data.location) {
      updateTelemetryUI(data.location);
    }
  } catch (err) {
    console.warn("Could not fetch initial train position:", err);
  }
}

function updateTelemetryUI(loc) {
  document.getElementById("telemetryStatus").textContent = loc.status;
  document.getElementById("telemetryCurrentStation").textContent = loc.current_station;
  document.getElementById("telemetryNextStation").textContent = loc.next_station;
  document.getElementById("telemetrySpeed").textContent = `${Math.round(loc.speed_kmh)} km/h`;
  document.getElementById("telemetryCoords").textContent = `${loc.latitude.toFixed(4)}, ${loc.longitude.toFixed(4)}`;

  renderTimeline(loc.current_station);
}

// Render Railway Waypoints Timeline
function renderTimeline(currentStationName) {
  const timeline = document.getElementById("waypointsTimeline");
  const currIdx = DEMO_WAYPOINTS.indexOf(currentStationName);

  timeline.innerHTML = DEMO_WAYPOINTS.map((wp, idx) => {
    let stateClass = "";
    if (idx < currIdx) stateClass = "passed";
    else if (idx === currIdx) stateClass = "current";

    return `
      <div class="waypoint-node ${stateClass}">
        <div class="dot"></div>
        <span class="name">${wp}</span>
      </div>
    `;
  }).join("");
}

// Event Listeners
function setupEventListeners() {
  // Train Selector Change
  document.getElementById("simTrainSelect").addEventListener("change", (e) => {
    currentTrainId = parseInt(e.target.value);
    fetchCoachesVisualizer(currentTrainId);
    fetchInitialTelemetry(currentTrainId);
  });

  // Spawn Buttons
  document.querySelectorAll(".btn-spawn").forEach(btn => {
    btn.addEventListener("click", () => {
      const count = parseInt(btn.getAttribute("data-count"));
      spawnSimulatedPassengers(count);
    });
  });

  // Reset Simulation
  document.getElementById("btnResetSimulation").addEventListener("click", resetSimulationData);

  // Speed Slider
  const slider = document.getElementById("speedSlider");
  const speedDisplay = document.getElementById("speedValDisplay");
  slider.addEventListener("input", (e) => {
    speedDisplay.textContent = `${e.target.value} km/h`;
  });

  // Train Movement Controls
  document.getElementById("btnStartMovement").addEventListener("click", startTrainMovement);
  document.getElementById("btnPauseMovement").addEventListener("click", pauseTrainMovement);
  document.getElementById("btnResetMovement").addEventListener("click", resetTrainMovement);
}

// Spawn Simulated Passengers
async function spawnSimulatedPassengers(count) {
  const msgEl = document.getElementById("spawnStatusMsg");
  const stn = document.getElementById("simStationSelect").value;
  msgEl.className = "status-msg info";
  msgEl.textContent = `Spawning ${count} simulated passengers with realistic crowd reports...`;

  try {
    const res = await fetch(`${API_BASE}/simulation/passengers`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        train_id: currentTrainId,
        count: count,
        station_name: stn
      })
    });
    const data = await res.json();
    if (res.ok) {
      msgEl.className = "status-msg success";
      msgEl.textContent = `✅ Successfully injected ${count} simulated passenger reports! Aggregation updated across system.`;
      fetchCoachesVisualizer(currentTrainId);
    } else {
      msgEl.className = "status-msg error";
      msgEl.textContent = `Error: ${data.message}`;
    }
  } catch (err) {
    msgEl.className = "status-msg error";
    msgEl.textContent = "Failed to communicate with simulation service.";
  }
}

// Reset Simulation Data
async function resetSimulationData() {
  if (!confirm("Are you sure you want to clear all simulated reports?")) return;
  try {
    const res = await fetch(`${API_BASE}/simulation/reset`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ train_id: currentTrainId })
    });
    if (res.ok) {
      alert("Simulation data cleared!");
      fetchCoachesVisualizer(currentTrainId);
      fetchInitialTelemetry(currentTrainId);
    }
  } catch (err) {
    alert("Reset failed: " + err.message);
  }
}

// Train Movement Simulation Engine
function startTrainMovement() {
  if (movementInterval) return;

  document.getElementById("btnStartMovement").disabled = true;
  document.getElementById("btnPauseMovement").disabled = false;

  movementInterval = setInterval(async () => {
    const speed = parseFloat(document.getElementById("speedSlider").value);
    try {
      const res = await fetch(`${API_BASE}/simulation/train-move`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          train_id: currentTrainId,
          step: 0.05,
          speed: speed
        })
      });
      const data = await res.json();
      if (data.success && data.location) {
        updateTelemetryUI(data.location);
      }
    } catch (err) {
      console.error("Train movement step error:", err);
    }
  }, 1500);
}

function pauseTrainMovement() {
  if (movementInterval) {
    clearInterval(movementInterval);
    movementInterval = null;
  }
  document.getElementById("btnStartMovement").disabled = false;
  document.getElementById("btnPauseMovement").disabled = true;
  document.getElementById("telemetryStatus").textContent = "PAUSED";
}

async function resetTrainMovement() {
  pauseTrainMovement();
  try {
    await fetch(`${API_BASE}/simulation/reset`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ train_id: currentTrainId })
    });
    fetchInitialTelemetry(currentTrainId);
  } catch (err) {
    console.error("Reset error:", err);
  }
}
