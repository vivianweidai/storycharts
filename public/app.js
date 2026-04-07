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

// Absolute integer values: -10 to +10
const TP_MIN = -10;
const TP_MAX = 10;
const TP_DEFAULT = 0;

// Light pastel colors — science repo preferred palette
const PLOT_COLORS = [
  '#f4a6a0', '#a1c9f4', '#b0d9a0', '#f9c784', '#d4a8e8',
  '#f7e59a', '#c4c4c4', '#f4a6a0', '#a1c9f4', '#b0d9a0'
];

function computeChartData(plots, scenes, turningPoints) {
  const tpMap = {};
  for (const tp of turningPoints) {
    tpMap[tp.plot_id + '-' + tp.scene_id] = parseInt(tp.tp_type) || TP_DEFAULT;
  }

  const datasets = plots.map((plot, pi) => {
    const data = scenes.map(scene => {
      const key = plot.id + '-' + scene.id;
      return tpMap[key] !== undefined ? tpMap[key] : TP_DEFAULT;
    });

    return {
      label: plot.title || 'Plot ' + (pi + 1),
      data,
      borderColor: PLOT_COLORS[pi % PLOT_COLORS.length],
      backgroundColor: PLOT_COLORS[pi % PLOT_COLORS.length],
      tension: 0,
      pointRadius: 5,
      pointHoverRadius: 7,
      fill: false
    };
  });

  return {
    labels: scenes.map(s => s.title || 'Scene'),
    datasets
  };
}

// Snap a dragged Y value to the nearest discrete step (1-20)
function snapValue(y) {
  return Math.max(TP_MIN, Math.min(TP_MAX, Math.round(y)));
}

// Build a draggable chart for the editor
function renderDraggableChart(container, plots, scenes, turningPoints, onChange) {
  if (!plots.length || !scenes.length) {
    container.innerHTML = '<p class="empty">Add plots and scenes to see the chart.</p>';
    return null;
  }

  // Build mutable TP map: "plotId-sceneId" → integer value
  const tpMap = {};
  for (const tp of turningPoints) {
    tpMap[tp.plot_id + '-' + tp.scene_id] = parseInt(tp.tp_type) || TP_DEFAULT;
  }
  // Fill defaults for any missing combinations
  for (const plot of plots) {
    for (const scene of scenes) {
      const key = plot.id + '-' + scene.id;
      if (tpMap[key] === undefined) tpMap[key] = TP_DEFAULT;
    }
  }

  container.innerHTML = '';
  const canvas = document.createElement('canvas');
  canvas.height = 400;
  container.appendChild(canvas);

  const chartData = computeChartData(plots, scenes, turningPoints);

  // Make points larger and more grab-friendly
  for (const ds of chartData.datasets) {
    ds.pointRadius = 8;
    ds.pointHoverRadius = 11;
    ds.pointHitRadius = 20;
    ds.pointStyle = 'circle';
  }

  const chart = new Chart(canvas, {
    type: 'line',
    data: chartData,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 150 },
      interaction: { mode: 'nearest', intersect: true },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => (plots[item.datasetIndex].title || 'Plot') + ': ' + item.formattedValue
          }
        },
        dragData: {
          dragX: false,
          dragY: true,
          round: 0,
          onDrag: function(e, datasetIndex, index, value) {
            const snapped = snapValue(value);
            const key = plots[datasetIndex].id + '-' + scenes[index].id;
            tpMap[key] = snapped;
            chart.data.datasets[datasetIndex].data[index] = snapped;
            chart.update('none');
            return snapped;
          },
          onDragEnd: function(e, datasetIndex, index, value) {
            const snapped = snapValue(value);
            const key = plots[datasetIndex].id + '-' + scenes[index].id;
            tpMap[key] = snapped;
            chart.data.datasets[datasetIndex].data[index] = snapped;
            chart.update('none');
            if (onChange) onChange(tpMap);
          }
        }
      },
      scales: {
        x: { ticks: { display: false }, title: { display: false }, grid: { display: false }, border: { display: false } },
        y: {
          type: 'linear',
          min: -10,
          max: 10,
          beginAtZero: false,
          grace: 0,
          ticks: { display: false, stepSize: 2 },
          title: { display: false },
          grid: { color: '#e8e8e8' },
          border: { display: false }
        }
      }
    }
  });

  chart._tpMap = tpMap;
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

  // Focus first input
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
