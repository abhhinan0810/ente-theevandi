// Admin Console Logic - Train Crowd MVP
function getBackendUrl() {
  const saved = localStorage.getItem("train_crowd_backend_url");
  if (saved) return saved.replace(/\/+$/, "");
  if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
    return window.location.port === "5000" ? window.location.origin : "http://127.0.0.1:5000";
  }
  return window.location.origin;
}

let SERVER_URL = getBackendUrl();
let API_BASE = `${SERVER_URL}/api`;

let socket = null;
let allTrains = [];
let allStations = [];
let currentTrainCoaches = [];
let selectedFormationTrainId = null;

// Initialize on DOM Ready
document.addEventListener("DOMContentLoaded", () => {
  setupNavigation();
  initSocket();
  loadOverview();
  loadTrains();
  loadStationsTab();
  setupForms();

  const btnServer = document.getElementById("btnServerUrl");
  if (btnServer) {
    btnServer.addEventListener("click", () => {
      const cur = localStorage.getItem("train_crowd_backend_url") || SERVER_URL;
      const input = prompt("Enter Backend Server API URL (e.g. https://your-backend.onrender.com or http://localhost:5000):", cur);
      if (input !== null) {
        const trimmed = input.trim().replace(/\/+$/, "");
        if (trimmed) {
          localStorage.setItem("train_crowd_backend_url", trimmed);
        } else {
          localStorage.removeItem("train_crowd_backend_url");
        }
        window.location.reload();
      }
    });
  }

  document.getElementById("btnRefresh").addEventListener("click", () => {
    loadOverview();
    loadTrains();
    loadStationsTab();
  });
});

// Setup Tab Navigation
function setupNavigation() {
  const navBtns = document.querySelectorAll(".nav-item");
  const panes = document.querySelectorAll(".tab-pane");

  navBtns.forEach(btn => {
    btn.addEventListener("click", () => {
      navBtns.forEach(b => b.classList.remove("active"));
      panes.forEach(p => p.classList.remove("active"));

      btn.classList.add("active");
      const tabId = btn.getAttribute("data-tab");
      const targetPane = document.getElementById(`pane-${tabId}`);
      if (targetPane) targetPane.classList.add("active");

      if (tabId === "crowd") loadCrowdView();
      if (tabId === "trains") loadFormationTab();
      if (tabId === "stations") loadStationsTab();
      if (tabId === "system") checkSystemHealth();
    });
  });
}

// Socket.IO Real-Time Connection
function initSocket() {
  const statusEl = document.getElementById("socketStatus");
  const labelEl = statusEl.querySelector(".status-label");

  try {
    socket = io(SERVER_URL, { reconnectionDelay: 2000, timeout: 5000 });

    socket.on("connect", () => {
      statusEl.className = "socket-status connected";
      labelEl.textContent = "Live Socket Online";
    });

    socket.on("disconnect", () => {
      statusEl.className = "socket-status disconnected";
      labelEl.textContent = "Socket Disconnected";
    });

    socket.on("crowd_update", (data) => {
      prependRecentReport({
        coach_code: data.coach_code,
        coach_type: data.coach_type,
        station_name: data.station_name,
        level: data.new_report,
        source: data.source || "USER",
        created_at: new Date().toISOString(),
        train_number: data.train_number || "LIVE"
      });
      loadOverview();
      const currentTrain = document.getElementById("crowdTrainSelect").value;
      if (currentTrain == data.train_id) {
        fetchCoachesForTrain(data.train_id);
      }
    });

    socket.on("train_departed", (data) => {
      console.log("[Socket.IO] Train departed event:", data);
    });

  } catch (err) {
    statusEl.className = "socket-status disconnected";
    labelEl.textContent = "Socket Offline";
  }
}

// Load Overview KPIs & Recent Reports
async function loadOverview() {
  try {
    const [trainsRes, reportsRes] = await Promise.all([
      fetch(`${API_BASE}/trains`),
      fetch(`${API_BASE}/crowd-reports/recent?limit=15`)
    ]);

    allTrains = await trainsRes.json();
    const reports = await reportsRes.json();

    document.getElementById("kpiTrains").textContent = allTrains.length;
    document.getElementById("kpiReports").textContent = reports.length;

    let highCrowdCount = 0;
    reports.forEach(r => { if (r.level === "High") highCrowdCount++; });
    document.getElementById("kpiHighCrowd").textContent = highCrowdCount;

    renderRecentReports(reports);
  } catch (err) {
    console.error("Failed to load overview data:", err);
  }
}

function renderRecentReports(reports) {
  const tbody = document.getElementById("recentReportsBody");
  if (!reports || reports.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="empty">No crowd reports recorded yet.</td></tr>`;
    return;
  }

  tbody.innerHTML = reports.map(r => `
    <tr>
      <td>${formatTime(r.created_at)}</td>
      <td><strong>${r.train_number}</strong> <span style="font-size: 11px; color: var(--text-muted);">${r.train_name || ''}</span></td>
      <td><strong>${r.coach_code}</strong></td>
      <td><span class="${r.coach_code.startsWith('GS') ? 'tag-general' : ''}">${r.coach_type || 'General'}</span></td>
      <td>${r.station_name}</td>
      <td><span class="badge-crowd ${r.level}">${r.level}</span></td>
      <td><span class="tag-source ${r.source}">${r.source}</span></td>
    </tr>
  `).join("");
}

function prependRecentReport(r) {
  const tbody = document.getElementById("recentReportsBody");
  const emptyRow = tbody.querySelector(".empty");
  if (emptyRow) emptyRow.remove();

  const tr = document.createElement("tr");
  tr.className = "row-highlight";
  tr.innerHTML = `
    <td>Just now</td>
    <td><strong>${r.train_number}</strong></td>
    <td><strong>${r.coach_code}</strong></td>
    <td><span class="${r.coach_code.startsWith('GS') ? 'tag-general' : ''}">${r.coach_type}</span></td>
    <td>${r.station_name}</td>
    <td><span class="badge-crowd ${r.level}">${r.level}</span></td>
    <td><span class="tag-source ${r.source}">${r.source}</span></td>
  `;
  tbody.insertBefore(tr, tbody.firstChild);
}

// Load Trains Registry & Dropdowns
async function loadTrains() {
  try {
    const res = await fetch(`${API_BASE}/trains`);
    allTrains = await res.json();
    populateTrainDropdowns();
    renderTrainsManagementTable(allTrains);
  } catch (err) {
    console.error("Failed to fetch trains:", err);
  }
}

function populateTrainDropdowns() {
  const dropdowns = [
    document.getElementById("crowdTrainSelect"),
    document.getElementById("formationTrainSelect")
  ];

  dropdowns.forEach(select => {
    if (!select) return;
    const prevVal = select.value;
    select.innerHTML = allTrains.map(t => `
      <option value="${t.id}">${t.number} - ${t.name} (${t.train_type || 'Express'})</option>
    `).join("");
    if (prevVal && allTrains.some(t => t.id == prevVal)) {
      select.value = prevVal;
    }
  });

  if (allTrains.length > 0 && !selectedFormationTrainId) {
    selectedFormationTrainId = allTrains[0].id;
    loadFormationBlocks(selectedFormationTrainId);
  }
}

function renderTrainsManagementTable(trains) {
  const tbody = document.getElementById("trainsManagementBody");
  if (!trains || trains.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="empty">No trains registered.</td></tr>`;
    return;
  }

  tbody.innerHTML = trains.map(t => `
    <tr>
      <td><strong>${t.number}</strong></td>
      <td>${t.name}</td>
      <td><span class="badge-pill" style="font-size: 11px;">${t.train_type || 'Express'}</span></td>
      <td>${t.origin} → ${t.destination}</td>
      <td><strong>${t.compartment_count || t.coach_count || 20}</strong> coaches</td>
      <td>${t.coach_length_meters || 25.0} m</td>
      <td>
        <button class="btn btn-secondary btn-sm" onclick="selectAndEditTrainFormation(${t.id})">🛠️ Rake</button>
        <button class="btn btn-danger btn-sm" onclick="deleteTrain(${t.id}, '${t.number}')">🗑️</button>
      </td>
    </tr>
  `).join("");
}

function selectAndEditTrainFormation(trainId) {
  selectedFormationTrainId = trainId;
  const select = document.getElementById("formationTrainSelect");
  if (select) select.value = trainId;
  loadFormationBlocks(trainId);
  document.querySelector('.nav-item[data-tab="trains"]').click();
}

// Compartment Formation Tab
function loadFormationTab() {
  const trainId = document.getElementById("formationTrainSelect").value || selectedFormationTrainId;
  if (trainId) loadFormationBlocks(trainId);
}

document.getElementById("formationTrainSelect").addEventListener("change", (e) => {
  selectedFormationTrainId = e.target.value;
  loadFormationBlocks(selectedFormationTrainId);
});

async function loadFormationBlocks(trainId) {
  const track = document.getElementById("formationBlocksTrack");
  const title = document.getElementById("formationTrainTitle");
  const meta = document.getElementById("formationTrainMeta");
  track.innerHTML = `<span class="loading">Loading compartments...</span>`;

  try {
    const [trainRes, coachesRes] = await Promise.all([
      fetch(`${API_BASE}/trains/${trainId}`),
      fetch(`${API_BASE}/trains/${trainId}/coaches`)
    ]);

    const trainData = await trainRes.json();
    const coaches = await coachesRes.json();

    const t = trainData.train || allTrains.find(x => x.id == trainId);
    if (t) {
      title.textContent = `${t.number} ${t.name} (${t.train_type || 'Express'})`;
      meta.textContent = `${t.origin} → ${t.destination} | Total Length: ${coaches.length * (t.coach_length_meters || 25)}m | ${coaches.length} Compartments`;
    }

    if (coaches.length === 0) {
      track.innerHTML = `<div class="empty">No coaches found. Apply a preset below.</div>`;
      return;
    }

    track.innerHTML = coaches.map((c, i) => `
      <div class="formation-coach-card" style="border-color: ${c.is_general ? '#6366f1' : '#334155'};">
        <span class="coach-tag">${c.type.slice(0, 12)}</span>
        <strong class="coach-name">${c.code}</strong>
        <span class="coach-seq">#${c.sequence} • ${c.distance_from_front || (c.sequence * 25)}m</span>
        <button class="btn-delete-coach" onclick="deleteCoachFromRake(${c.id}, '${c.code}')">✕</button>
      </div>
    `).join("");

  } catch (err) {
    track.innerHTML = `<span class="error">Failed to load coach layout.</span>`;
  }
}

async function deleteCoachFromRake(coachId, coachCode) {
  if (coachCode === "ENGINE") {
    alert("Cannot delete the locomotive engine.");
    return;
  }
  if (!confirm(`Remove coach ${coachCode} from formation?`)) return;

  try {
    const res = await fetch(`${API_BASE}/coaches/${coachId}`, { method: "DELETE" });
    if (res.ok) {
      loadFormationBlocks(selectedFormationTrainId);
      loadTrains();
    } else {
      const data = await res.json();
      alert(data.message || "Failed to remove coach");
    }
  } catch (err) {
    alert("Error removing coach: " + err.message);
  }
}

async function applyPresetTemplate(templateName) {
  if (!selectedFormationTrainId) {
    alert("Please select a train first");
    return;
  }
  const track = document.getElementById("formationBlocksTrack");
  track.innerHTML = `<span class="loading">Applying ${templateName} preset...</span>`;

  try {
    const res = await fetch(`${API_BASE}/trains/${selectedFormationTrainId}/coaches/template`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ template: templateName })
    });
    if (res.ok) {
      loadFormationBlocks(selectedFormationTrainId);
      loadTrains();
    } else {
      alert("Failed to apply rake preset");
      loadFormationBlocks(selectedFormationTrainId);
    }
  } catch (err) {
    alert("Error: " + err.message);
    loadFormationBlocks(selectedFormationTrainId);
  }
}

async function applyBulkCoaches() {
  if (!selectedFormationTrainId) {
    alert("Please select a train first");
    return;
  }
  const input = document.getElementById("bulkCoachesInput");
  const raw = input.value.trim();
  if (!raw) return;

  const track = document.getElementById("formationBlocksTrack");
  track.innerHTML = `<span class="loading">Updating coach arrangement...</span>`;

  try {
    const res = await fetch(`${API_BASE}/trains/${selectedFormationTrainId}/coaches/bulk`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ coaches: raw })
    });
    if (res.ok) {
      input.value = "";
      loadFormationBlocks(selectedFormationTrainId);
      loadTrains();
    } else {
      alert("Failed to set coach arrangement");
      loadFormationBlocks(selectedFormationTrainId);
    }
  } catch (err) {
    alert("Error saving coach arrangement: " + err.message);
    loadFormationBlocks(selectedFormationTrainId);
  }
}

// Live Crowd Tab
function loadCrowdView() {
  const trainId = document.getElementById("crowdTrainSelect").value;
  if (trainId) fetchCoachesForTrain(trainId);
}

document.getElementById("crowdTrainSelect").addEventListener("change", (e) => {
  if (e.target.value) fetchCoachesForTrain(e.target.value);
});

document.getElementById("crowdFilterLevel").addEventListener("change", () => {
  renderCoachesTable(currentTrainCoaches);
});

async function fetchCoachesForTrain(trainId) {
  const tbody = document.getElementById("coachesCrowdBody");
  const blocksContainer = document.getElementById("crowdFormationBlocks");
  tbody.innerHTML = `<tr><td colspan="8" class="loading">Loading coaches and crowd reports...</td></tr>`;

  try {
    const res = await fetch(`${API_BASE}/trains/${trainId}/coaches`);
    currentTrainCoaches = await res.json();
    renderCoachesTable(currentTrainCoaches);

    blocksContainer.innerHTML = currentTrainCoaches.map(c => `
      <div style="background: #1e293b; border: 2px solid ${c.is_general ? '#6366f1' : '#334155'}; border-radius: 8px; padding: 8px 12px; text-align: center; min-width: 85px;">
        <span style="font-size: 9px; color: #94a3b8;">${c.type.slice(0, 10)}</span>
        <strong style="display: block; font-size: 14px; margin: 2px 0;">${c.code}</strong>
        <span class="badge-crowd ${c.level}" style="font-size: 9px; padding: 1px 6px;">${c.level}</span>
      </div>
    `).join("");

  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="8" class="error">Failed to load coaches.</td></tr>`;
  }
}

function renderCoachesTable(coaches) {
  const tbody = document.getElementById("coachesCrowdBody");
  const filter = document.getElementById("crowdFilterLevel").value;

  const filtered = filter === "ALL" ? coaches : coaches.filter(c => c.level === filter);

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="empty">No coaches matching filter criteria.</td></tr>`;
    return;
  }

  tbody.innerHTML = filtered.map(c => `
    <tr>
      <td><strong>${c.code}</strong></td>
      <td><span class="${c.is_general ? 'tag-general' : ''}">${c.type}</span></td>
      <td>#${c.sequence}</td>
      <td><span class="badge-crowd ${c.level}">${c.level}</span></td>
      <td><strong>${c.score ? c.score.toFixed(2) : '--'}</strong> / 3.0</td>
      <td>${c.reports || 0} reports</td>
      <td><strong>${c.confidence || 0}%</strong></td>
      <td style="color: var(--text-muted);">${c.updated || 'No reports'}</td>
    </tr>
  `).join("");
}

// TAB 4: STATIONS & PLATFORM STOP GEOMETRY
async function loadStationsTab() {
  const stationSelect = document.getElementById("stopStationSelect");
  const tableBody = document.getElementById("stopsTableBody");
  tableBody.innerHTML = `<tr><td colspan="7" class="loading">Loading stopping profiles...</td></tr>`;

  try {
    const [stnRes, stopsRes] = await Promise.all([
      fetch(`${API_BASE}/stations`),
      fetch(`${API_BASE}/stations/Chengannur/stops`)
    ]);

    allStations = await stnRes.json();
    document.getElementById("kpiStations").textContent = allStations.length;

    // Populate Station Select dropdown
    if (stationSelect) {
      const prevVal = stationSelect.value;
      stationSelect.innerHTML = allStations.map(s => `
        <option value="${s.name}">${s.name} (${s.code})</option>
      `).join("");
      if (prevVal) stationSelect.value = prevVal;
    }

    // Fetch all stops across key stations
    const keyStations = ["Chengannur", "Kollam Junction", "Kottayam", "Ernakulam Town"];
    const allStopsPromises = keyStations.map(s => fetch(`${API_BASE}/stations/${s}/stops`).then(r => r.json()));
    const stopsArrays = await Promise.all(allStopsPromises);
    const flattenedStops = stopsArrays.flat();

    document.getElementById("kpiStopProfiles").textContent = flattenedStops.length;
    renderStopsTable(flattenedStops);

  } catch (err) {
    console.error("Error loading stations tab:", err);
    tableBody.innerHTML = `<tr><td colspan="7" class="error">Failed to load stopping profiles.</td></tr>`;
  }
}

function renderStopsTable(stops) {
  const tbody = document.getElementById("stopsTableBody");
  if (!stops || stops.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="empty">No platform stop profiles defined.</td></tr>`;
    return;
  }

  tbody.innerHTML = stops.map(s => {
    // Approximate distance between front and back in meters
    const latDiff = (s.front_lat - s.back_lat) * 110540;
    const lngDiff = (s.front_lng - s.back_lng) * 109000;
    const approxDist = Math.round(Math.sqrt(latDiff * latDiff + lngDiff * lngDiff));

    return `
      <tr>
        <td><strong>${s.station_name}</strong></td>
        <td><span class="badge-pill">Platform ${s.platform_number}</span></td>
        <td><span class="tag-general" style="font-weight: 700;">${s.train_type}</span></td>
        <td>${s.front_lat.toFixed(6)}, ${s.front_lng.toFixed(6)}</td>
        <td>${s.back_lat.toFixed(6)}, ${s.back_lng.toFixed(6)}</td>
        <td><strong>${s.avg_coach_length_meters || 25} m</strong></td>
        <td><strong>~${approxDist} m</strong></td>
      </tr>
    `;
  }).join("");
}

// Forms Setup
function setupForms() {
  // 1. Add Train Form
  const addTrainForm = document.getElementById("addTrainForm");
  const addTrainMsg = document.getElementById("addTrainMsg");

  addTrainForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    addTrainMsg.textContent = "Registering train...";
    addTrainMsg.style.color = "var(--accent-cyan)";

    const payload = {
      number: document.getElementById("trainNumber").value.trim(),
      name: document.getElementById("trainName").value.trim(),
      train_type: document.getElementById("trainModelType").value,
      compartment_count: parseInt(document.getElementById("trainCompartmentsCount").value) || 20,
      origin: document.getElementById("trainOrigin").value.trim(),
      destination: document.getElementById("trainDestination").value.trim()
    };

    try {
      const res = await fetch(`${API_BASE}/trains`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (res.ok) {
        addTrainMsg.textContent = `Train ${payload.number} (${payload.name}) registered with ${payload.compartment_count} coaches!`;
        addTrainMsg.style.color = "var(--green)";
        addTrainForm.reset();
        loadTrains();
      } else {
        addTrainMsg.textContent = data.message || "Failed to register train";
        addTrainMsg.style.color = "var(--red)";
      }
    } catch (err) {
      addTrainMsg.textContent = "Server communication error";
      addTrainMsg.style.color = "var(--red)";
    }
  });

  // 2. Add Coach Form
  const coachForm = document.getElementById("addCoachForm");
  const coachMsg = document.getElementById("addCoachMsg");

  coachForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!selectedFormationTrainId) {
      alert("Please select a train first");
      return;
    }

    coachMsg.textContent = "Adding coach...";
    coachMsg.style.color = "var(--accent-cyan)";

    const payload = {
      coach_code: document.getElementById("newCoachCode").value.trim().toUpperCase(),
      coach_type: document.getElementById("newCoachType").value
    };

    try {
      const res = await fetch(`${API_BASE}/trains/${selectedFormationTrainId}/coaches`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (res.ok) {
        coachMsg.textContent = `Coach ${payload.coach_code} added to formation!`;
        coachMsg.style.color = "var(--green)";
        document.getElementById("newCoachCode").value = "";
        loadFormationBlocks(selectedFormationTrainId);
        loadTrains();
      } else {
        coachMsg.textContent = data.message || "Failed to add coach";
        coachMsg.style.color = "var(--red)";
      }
    } catch (err) {
      coachMsg.textContent = "Error communicating with server";
      coachMsg.style.color = "var(--red)";
    }
  });

  // 3. Add Platform Stop Coordinates Form
  const stopForm = document.getElementById("addStopCoordsForm");
  const stopMsg = document.getElementById("addStopMsg");

  stopForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    stopMsg.textContent = "Saving platform stopping coordinates...";
    stopMsg.style.color = "var(--accent-cyan)";

    const stationName = document.getElementById("stopStationSelect").value;
    const payload = {
      platform_number: parseInt(document.getElementById("stopPlatformNumber").value),
      train_type: document.getElementById("stopTrainType").value,
      front_lat: parseFloat(document.getElementById("stopFrontLat").value),
      front_lng: parseFloat(document.getElementById("stopFrontLng").value),
      back_lat: parseFloat(document.getElementById("stopBackLat").value),
      back_lng: parseFloat(document.getElementById("stopBackLng").value),
      avg_coach_length: parseFloat(document.getElementById("stopCoachLength").value)
    };

    try {
      const res = await fetch(`${API_BASE}/stations/${encodeURIComponent(stationName)}/stops`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (res.ok) {
        stopMsg.textContent = `Saved stop coordinates for ${stationName} (Platform ${payload.platform_number})!`;
        stopMsg.style.color = "var(--green)";
        loadStationsTab();
      } else {
        stopMsg.textContent = data.message || "Failed to save stop coordinates";
        stopMsg.style.color = "var(--red)";
      }
    } catch (err) {
      stopMsg.textContent = "Server communication error";
      stopMsg.style.color = "var(--red)";
    }
  });

  // 4. Add Station Form
  const stationForm = document.getElementById("addStationForm");
  const stationMsg = document.getElementById("addStationMsg");

  stationForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    stationMsg.textContent = "Registering station...";
    stationMsg.style.color = "var(--accent-cyan)";

    const payload = {
      code: document.getElementById("newStationCode").value.trim().toUpperCase(),
      name: document.getElementById("newStationName").value.trim(),
      latitude: parseFloat(document.getElementById("newStationLat").value),
      longitude: parseFloat(document.getElementById("newStationLng").value)
    };

    try {
      const res = await fetch(`${API_BASE}/stations`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (res.ok) {
        stationMsg.textContent = `Station ${payload.name} (${payload.code}) registered!`;
        stationMsg.style.color = "var(--green)";
        stationForm.reset();
        loadStationsTab();
      } else {
        stationMsg.textContent = data.message || "Failed to register station";
        stationMsg.style.color = "var(--red)";
      }
    } catch (err) {
      stationMsg.textContent = "Server communication error";
      stationMsg.style.color = "var(--red)";
    }
  });
}

// Delete Train Handler
async function deleteTrain(id, number) {
  if (!confirm(`Are you sure you want to delete train ${number}?`)) return;
  try {
    const res = await fetch(`${API_BASE}/trains/${id}`, { method: "DELETE" });
    if (res.ok) {
      loadTrains();
    } else {
      alert("Failed to delete train");
    }
  } catch (err) {
    alert("Error deleting train: " + err.message);
  }
}

// System Health
async function checkSystemHealth() {
  const dbStatusEl = document.getElementById("sysDbStatus");
  const socketStatusEl = document.getElementById("sysSocketStatus");
  const hostEl = document.getElementById("sysApiHost");

  hostEl.textContent = API_BASE;

  try {
    const res = await fetch(`${API_BASE}/health`);
    const data = await res.json();
    if (data.status === "ok") {
      dbStatusEl.textContent = `PostgreSQL + SQLite Extended Storage (Online)`;
      dbStatusEl.className = "status-val text-green";
    } else {
      dbStatusEl.textContent = "Database Error: " + data.message;
      dbStatusEl.className = "status-val text-red";
    }
  } catch (err) {
    dbStatusEl.textContent = "Backend Unreachable";
    dbStatusEl.className = "status-val text-red";
  }

  if (socket && socket.connected) {
    socketStatusEl.textContent = "Flask-SocketIO (Online - Real-time)";
    socketStatusEl.className = "status-val text-green";
  } else {
    socketStatusEl.textContent = "Socket Disconnected";
    socketStatusEl.className = "status-val text-amber";
  }
}

function formatTime(isoStr) {
  if (!isoStr) return "--";
  const d = new Date(isoStr);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}
