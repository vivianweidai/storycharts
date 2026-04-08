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
  try {
    const user = await api('GET', 'auth/me');
    return user;
  } catch { return null; }
}

// --- Chart rendering ---

// Disable chart legend globally
if (typeof Chart !== 'undefined') {
  Chart.defaults.plugins.legend.display = false;
}

// Grid bounds
const X_MIN = 0;
const X_MAX = 20;
const Y_MIN = -10;
const Y_MAX = 10;

// Light pastel colors — science repo preferred palette
const PLOT_COLORS = [
  '#f4a6a0', '#a1c9f4', '#b0d9a0', '#f9c784', '#d4a8e8',
  '#f7e59a', '#c4c4c4', '#f4a6a0', '#a1c9f4', '#b0d9a0'
];

function snapY(y) {
  return Math.max(Y_MIN, Math.min(Y_MAX, Math.round(y)));
}

// Build a draggable chart on a 21x21 grid
function renderDraggableChart(container, plots, chartPoints, onChange) {
  if (!plots.length) {
    container.innerHTML = '<p class="empty">Add plots to build your chart.</p>';
    return null;
  }

  // Group points by plot
  const pointsByPlot = {};
  for (const cp of chartPoints) {
    if (!pointsByPlot[cp.plot_id]) pointsByPlot[cp.plot_id] = [];
    pointsByPlot[cp.plot_id].push({ x: cp.x_pos, y: cp.y_val });
  }
  // Sort each plot's points by x
  for (const pid in pointsByPlot) {
    pointsByPlot[pid].sort((a, b) => a.x - b.x);
  }

  const datasets = plots.map((plot, pi) => ({
    label: plot.title || 'Plot ' + (pi + 1),
    data: (pointsByPlot[plot.id] || []).map(p => ({ x: p.x, y: p.y })),
    borderColor: PLOT_COLORS[pi % PLOT_COLORS.length],
    backgroundColor: PLOT_COLORS[pi % PLOT_COLORS.length],
    tension: 0,
    pointRadius: 8,
    pointHoverRadius: 11,
    pointHitRadius: 20,
    pointStyle: 'circle',
    fill: false,
    showLine: true
  }));

  container.innerHTML = '';
  const canvas = document.createElement('canvas');
  canvas.height = 400;
  container.appendChild(canvas);

  const chart = new Chart(canvas, {
    type: 'scatter',
    data: { datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 150 },
      interaction: { mode: 'nearest', intersect: true },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (item) => {
              const pt = item.raw;
              return (plots[item.datasetIndex].title || 'Plot') + ': (' + pt.x + ', ' + pt.y + ')';
            }
          }
        },
        dragData: {
          dragX: false,
          dragY: true,
          round: 0,
          onDrag: function(e, datasetIndex, index, value) {
            const snapped = snapY(value);
            chart.data.datasets[datasetIndex].data[index].y = snapped;
            chart.update('none');
            return snapped;
          },
          onDragEnd: function(e, datasetIndex, index, value) {
            const snapped = snapY(value);
            chart.data.datasets[datasetIndex].data[index].y = snapped;
            chart.update('none');
            if (onChange) onChange();
          }
        }
      },
      scales: {
        x: {
          type: 'linear',
          min: X_MIN - 1,
          max: X_MAX + 1,
          ticks: { display: false, stepSize: 1 },
          grid: { color: '#e8e8e8', lineWidth: 0.5 },
          border: { display: true, color: '#e8e8e8', width: 1 }
        },
        y: {
          type: 'linear',
          min: Y_MIN - 1,
          max: Y_MAX + 1,
          beginAtZero: false,
          grace: 0,
          ticks: { display: false, stepSize: 1 },
          grid: { color: '#e8e8e8', lineWidth: 0.5 },
          border: { display: true, color: '#e8e8e8', width: 1 }
        }
      }
    }
  });

  return chart;
}

// --- Modal helpers ---

function showModal(title, fields, onSave, onDelete) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';

  let html = '<div class="modal"><h2>' + title + '</h2>';
  for (const f of fields) {
    html += '<div class="form-group"><label>' + f.label + '</label>';
    if (f.type === 'textarea') {
      html += '<textarea name="' + f.name + '">' + (f.value || '') + '</textarea>';
    } else if (f.type === 'checkbox') {
      html += '<div class="form-check"><input type="checkbox" name="' + f.name + '"' + (f.value ? ' checked' : '') + '> ' + (f.checkLabel || '') + '</div>';
    } else {
      html += '<input type="text" name="' + f.name + '" value="' + (f.value || '') + '">';
    }
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
    for (const f of fields) {
      const el = overlay.querySelector('[name="' + f.name + '"]');
      data[f.name] = f.type === 'checkbox' ? el.checked : el.value;
    }
    document.body.removeChild(overlay);
    onSave(data);
  };

  overlay.querySelector('#modal-cancel').onclick = () => document.body.removeChild(overlay);

  if (onDelete) {
    overlay.querySelector('#modal-delete').onclick = () => {
      if (confirm('Are you sure?')) {
        document.body.removeChild(overlay);
        onDelete();
      }
    };
  }

  const first = overlay.querySelector('input, textarea');
  if (first) first.focus();
}

// --- Render auth header ---

function renderHeader(user) {
  const header = document.getElementById('header');
  if (!header) return;

  let html = '<a href="/">Story Charts</a>';
  if (user) {
    html += '<span style="font-size:0.8em;color:#656d76">' + user.email + '</span>';
  } else {
    html += '<a href="/api/auth/login" class="auth-btn">Login</a>';
  }
  header.innerHTML = html;
}
