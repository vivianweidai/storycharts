// StoryCharts — shared frontend logic

// --- API client ---

async function api(method, path, body) {
  const opts = { method, headers: {} };
  if (body) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  const res = await fetch('/api/' + path, opts);
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: 'Request failed' }));
    throw new Error(err.error || 'Request failed');
  }
  return res.json();
}

async function getUser() {
  try { return await api('GET', 'auth/me'); }
  catch { return null; }
}

// --- Chart constants ---

const X_MIN = 0, X_MAX = 20, Y_MIN = -10, Y_MAX = 10;

const PLOT_COLORS = [
  '#f4a6a0', '#a1c9f4', '#b0d9a0', '#f9c784', '#d4a8e8',
  '#f7e59a', '#c4c4c4', '#f4a6a0', '#a1c9f4', '#b0d9a0'
];

function buildDatasets(plots, chartPoints) {
  const byPlot = {};
  for (const cp of chartPoints) {
    if (!byPlot[cp.plot_id]) byPlot[cp.plot_id] = [];
    byPlot[cp.plot_id].push({ x: cp.x_pos, y: cp.y_val });
  }
  for (const pid in byPlot) byPlot[pid].sort((a, b) => a.x - b.x);

  return plots.map((plot, pi) => ({
    label: plot.title || 'Plot ' + (pi + 1),
    data: (byPlot[plot.id] || []).map(p => ({ x: p.x, y: p.y })),
    borderColor: PLOT_COLORS[pi % PLOT_COLORS.length],
    backgroundColor: PLOT_COLORS[pi % PLOT_COLORS.length],
    tension: 0, pointRadius: 6, pointHoverRadius: 8,
    pointStyle: 'circle', fill: false, showLine: true
  }));
}

function renderChart(container, plots, chartPoints, scaleOpts) {
  container.innerHTML = '';
  const canvas = document.createElement('canvas');
  container.appendChild(canvas);

  return new Chart(canvas, {
    type: 'scatter',
    data: { datasets: buildDatasets(plots, chartPoints) },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      plugins: { legend: { display: false }, tooltip: { enabled: false } },
      scales: {
        x: {
          type: 'linear', min: X_MIN - 1, max: X_MAX + 1,
          ticks: { display: false, stepSize: 1 },
          grid: scaleOpts.xGrid,
          border: scaleOpts.xBorder
        },
        y: {
          type: 'linear', min: Y_MIN - 1, max: Y_MAX + 1,
          beginAtZero: false, grace: 0,
          ticks: { display: false, stepSize: 1 },
          grid: scaleOpts.yGrid,
          border: scaleOpts.yBorder
        }
      }
    }
  });
}

// --- Modal ---

function showModal(title, fields, onSave, onDelete) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  let html = '<div class="modal"><h2>' + title + '</h2>';
  for (const f of fields) {
    html += '<div class="form-group"><label>' + f.label + '</label>';
    if (f.type === 'textarea') html += '<textarea name="' + f.name + '">' + (f.value || '') + '</textarea>';
    else html += '<input type="text" name="' + f.name + '" value="' + (f.value || '') + '">';
    html += '</div>';
  }
  html += '<div class="actions"><button class="btn btn-primary" id="modal-save">Save</button>';
  html += '<button class="btn" id="modal-cancel">Cancel</button>';
  if (onDelete) html += '<button class="btn btn-danger" id="modal-delete" style="margin-left:auto">Delete</button>';
  html += '</div></div>';
  overlay.innerHTML = html;
  document.body.appendChild(overlay);

  overlay.querySelector('#modal-save').onclick = () => {
    const data = {};
    for (const f of fields) data[f.name] = overlay.querySelector('[name="' + f.name + '"]').value;
    document.body.removeChild(overlay);
    onSave(data);
  };
  overlay.querySelector('#modal-cancel').onclick = () => document.body.removeChild(overlay);
  if (onDelete) {
    overlay.querySelector('#modal-delete').onclick = () => {
      if (confirm('Are you sure?')) { document.body.removeChild(overlay); onDelete(); }
    };
  }
  const first = overlay.querySelector('input, textarea');
  if (first) first.focus();
}

// --- Header ---

function renderHeader(user) {
  const header = document.getElementById('header');
  if (!header) return;
  let html = '<a href="/">Story Charts</a>';
  if (user) html += '<span style="font-size:0.8em;color:#656d76">' + user.email + '</span>';
  else html += '<a href="/api/auth/login" class="auth-btn">Login</a>';
  header.innerHTML = html;
}
