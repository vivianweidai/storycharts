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

const TP_TYPES = ['None', 'Increase', 'Accelerate', 'Success', 'Decrease', 'Decelerate', 'Failure'];

const PLOT_COLORS = [
  '#1f77b4', '#d62728', '#2ca02c', '#ff7f0e', '#9467bd',
  '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
];

// Replicate the legacy TP accumulation logic from Story.html
function computeChartData(plots, scenes, turningPoints) {
  const tpMap = {};
  for (const tp of turningPoints) {
    tpMap[tp.plot_id + '-' + tp.scene_id] = tp.tp_type;
  }

  const datasets = plots.map((plot, pi) => {
    let value = 0;
    const data = scenes.map(scene => {
      const tpType = tpMap[plot.id + '-' + scene.id] || 'None';
      if (tpType === 'None') return value;

      switch (tpType) {
        case 'Increase': value += 1; break;
        case 'Decrease': value -= 1; break;
        case 'Accelerate':
          if (value < 0) value = -value;
          value += 2;
          break;
        case 'Decelerate':
          if (value > 0) value = -value;
          value -= 2;
          break;
        case 'Success':
          if (value < 0) value = -value;
          value += 3;
          break;
        case 'Failure':
          if (value > 0) value = -value;
          value -= 3;
          break;
      }
      return value;
    });

    return {
      label: plot.title || 'Plot ' + (pi + 1),
      data,
      borderColor: PLOT_COLORS[pi % PLOT_COLORS.length],
      backgroundColor: PLOT_COLORS[pi % PLOT_COLORS.length],
      tension: 0.3,
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

function renderChart(container, plots, scenes, turningPoints) {
  if (!plots.length || !scenes.length) {
    container.innerHTML = '<p class="empty">Add plots and scenes to see the chart.</p>';
    return null;
  }

  // Clear container and create canvas
  container.innerHTML = '';
  const canvas = document.createElement('canvas');
  canvas.height = 300;
  container.appendChild(canvas);

  const chartData = computeChartData(plots, scenes, turningPoints);

  return new Chart(canvas, {
    type: 'line',
    data: chartData,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { position: 'top', labels: { font: { size: 12 } } },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => {
              const plot = plots[item.datasetIndex];
              const scene = scenes[item.dataIndex];
              const tpType = getTpType(plot.id, scene.id, turningPoints);
              return (plot.title || 'Plot') + ': ' + tpType + ' (' + item.formattedValue + ')';
            }
          }
        }
      },
      scales: {
        x: { title: { display: true, text: 'Scenes' } },
        y: { title: { display: true, text: 'Value' }, grid: { color: '#f0f0f0' } }
      }
    }
  });
}

function getTpType(plotId, sceneId, turningPoints) {
  const tp = turningPoints.find(t => t.plot_id == plotId && t.scene_id == sceneId);
  return tp ? tp.tp_type : 'None';
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
