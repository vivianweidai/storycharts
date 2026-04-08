// StoryCharts API — Cloudflare Pages Function (catch-all)

export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/api/, '');
  const method = request.method;

  await env.DB.exec('PRAGMA foreign_keys = ON');
  await migrate(env.DB);
  const user = getUser(request);

  try {
    if (path === '/auth/login') return Response.redirect(url.origin + '/', 302);
    if (path === '/auth/me') return json(user);

    const storyM = path.match(/^\/stories\/(\d+)$/);
    const subM = path.match(/^\/stories\/(\d+)\/(plots|chartpoints)$/);
    const plotM = path.match(/^\/plots\/(\d+)$/);

    // Stories
    if (path === '/stories' && method === 'GET') return listStories(env);
    if (path === '/stories' && method === 'POST') return requireAuth(user) || createStory(env, user, await request.json());
    if (storyM && method === 'GET') return getStory(env, user, storyM[1]);
    if (storyM && method === 'PUT') return requireAuth(user) || updateStory(env, user, storyM[1], await request.json());
    if (storyM && method === 'DELETE') return requireAuth(user) || deleteStory(env, user, storyM[1]);

    // Plots
    if (subM && subM[2] === 'plots' && method === 'POST') return requireAuth(user) || createPlot(env, user, subM[1], await request.json());
    if (plotM && method === 'PUT') return requireAuth(user) || updatePlot(env, user, plotM[1], await request.json());
    if (plotM && method === 'DELETE') return requireAuth(user) || deletePlot(env, user, plotM[1]);

    // Chart points
    if (subM && subM[2] === 'chartpoints' && method === 'POST') return requireAuth(user) || saveChartPoints(env, user, subM[1], await request.json());

    // Admin
    if (path === '/admin/reset' && method === 'POST') return requireAuth(user) || resetAll(env);

    return json({ error: 'Not found' }, 404);
  } catch (e) {
    if (e && e.status) return json({ error: e.error }, e.status);
    console.error(e);
    return json({ error: 'Internal server error' }, 500);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
}

function requireAuth(user) {
  return user ? null : json({ error: 'Unauthorized' }, 401);
}

// --- Auth ---

function getUser(request) {
  const email = request.headers.get('Cf-Access-Authenticated-User-Email');
  if (email) return { userid: email, email };

  const cookie = request.headers.get('Cookie') || '';
  const m = cookie.match(/CF_Authorization=([^;]+)/);
  if (m) {
    try {
      const p = JSON.parse(atob(m[1].split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      if (p.email) return { userid: p.email, email: p.email };
    } catch {}
  }

  const dev = request.headers.get('X-Dev-User');
  return dev ? { userid: dev, email: dev } : null;
}

// --- DB ---

let migrated = false;
async function migrate(db) {
  if (migrated) return;
  await db.batch([
    db.prepare("CREATE TABLE IF NOT EXISTS stories (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL DEFAULT '', userid TEXT NOT NULL, email TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT (datetime('now')))"),
    db.prepare("CREATE TABLE IF NOT EXISTS plots (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, title TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 100)"),
    db.prepare("CREATE TABLE IF NOT EXISTS chart_points (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, plot_id INTEGER NOT NULL REFERENCES plots(id) ON DELETE CASCADE, x_pos INTEGER NOT NULL DEFAULT 0, y_val INTEGER NOT NULL DEFAULT 0, label TEXT NOT NULL DEFAULT '')")
  ]);
  try { await db.prepare("ALTER TABLE chart_points ADD COLUMN label TEXT NOT NULL DEFAULT ''").run(); } catch {}
  migrated = true;
}

async function requireOwner(env, user, storyId) {
  const s = await env.DB.prepare('SELECT userid FROM stories WHERE id = ?').bind(storyId).first();
  if (!s) throw { status: 404, error: 'Not found' };
  if (s.userid !== user.userid) throw { status: 403, error: 'Forbidden' };
}

// --- Stories ---

async function listStories(env) {
  return json((await env.DB.prepare('SELECT id, title, userid FROM stories ORDER BY id DESC').all()).results);
}

async function createStory(env, user, body) {
  const r = await env.DB.prepare('INSERT INTO stories (title, userid, email) VALUES (?, ?, ?)').bind(body.title || '', user.userid, user.email).run();
  const sid = r.meta.last_row_id;

  const names = ['Internal', 'Relationship', 'External', 'Mystery'];
  const descs = [
    'Inner journey — fears, doubts, growth, self-discovery.',
    'Key relationships — trust, conflict, bonding, betrayal.',
    'Outer conflict — obstacles, antagonists, the main goal.',
    'Hidden elements — secrets, twists, revelations.'
  ];
  const numPlots = 2 + Math.floor(Math.random() * 3);
  const pStmt = env.DB.prepare('INSERT INTO plots (story_id, title, description, sort_order) VALUES (?, ?, ?, ?)');
  const plotIds = [];
  for (let i = 0; i < numPlots; i++) {
    const pr = await pStmt.bind(sid, names[i], descs[i], i + 1).run();
    plotIds.push(pr.meta.last_row_id);
  }

  const tpLabels = {
    Internal: ['Self-doubt', 'Realization', 'Inner peace', 'Fear strikes', 'Courage found', 'Identity crisis', 'Acceptance', 'Breakdown'],
    Relationship: ['First meeting', 'Trust broken', 'Reconciliation', 'Betrayal', 'Deep bond', 'Argument', 'Sacrifice', 'Forgiveness'],
    External: ['Obstacle appears', 'Small victory', 'Setback', 'Ally joins', 'Enemy revealed', 'Battle', 'Escape', 'Confrontation'],
    Mystery: ['Clue found', 'Red herring', 'Secret revealed', 'Twist', 'Hidden truth', 'Deception', 'Discovery', 'Unmasked']
  };

  const cpStmt = env.DB.prepare('INSERT INTO chart_points (story_id, plot_id, x_pos, y_val, label) VALUES (?, ?, ?, ?, ?)');
  const batch = [];
  for (let pi = 0; pi < plotIds.length; pi++) {
    const n = 3 + Math.floor(Math.random() * 6);
    const labels = tpLabels[names[pi]] || tpLabels.Internal;
    const shuffled = labels.slice().sort(() => Math.random() - 0.5);
    const pts = [];
    for (let i = 0; i < n; i++) pts.push({ x: Math.floor(Math.random() * 10001), y: Math.floor(Math.random() * 10001), label: shuffled[i % shuffled.length] });
    pts.sort((a, b) => a.x - b.x);
    for (const p of pts) batch.push(cpStmt.bind(sid, plotIds[pi], p.x, p.y, p.label));
  }
  if (batch.length) await env.DB.batch(batch);
  return json({ id: sid }, 201);
}

async function getStory(env, user, id) {
  const story = await env.DB.prepare('SELECT * FROM stories WHERE id = ?').bind(id).first();
  if (!story) return json({ error: 'Not found' }, 404);
  const [plots, cps] = await Promise.all([
    env.DB.prepare('SELECT * FROM plots WHERE story_id = ? ORDER BY sort_order').bind(id).all(),
    env.DB.prepare('SELECT * FROM chart_points WHERE story_id = ? ORDER BY plot_id, x_pos').bind(id).all()
  ]);
  return json({ story, plots: plots.results, chartPoints: cps.results, isOwner: user && user.userid === story.userid });
}

async function updateStory(env, user, id, body) {
  await requireOwner(env, user, id);
  await env.DB.prepare('UPDATE stories SET title = ? WHERE id = ?').bind(body.title || '', id).run();
  return json({ ok: true });
}

async function deleteStory(env, user, id) {
  await requireOwner(env, user, id);
  await env.DB.prepare('DELETE FROM stories WHERE id = ?').bind(id).run();
  return json({ ok: true });
}

// --- Plots ---

async function createPlot(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const r = await env.DB.prepare('INSERT INTO plots (story_id, title, description, sort_order) VALUES (?, ?, ?, 100)').bind(storyId, body.title || '', body.description || '').run();
  return json({ id: r.meta.last_row_id }, 201);
}

async function updatePlot(env, user, id, body) {
  const p = await env.DB.prepare('SELECT story_id FROM plots WHERE id = ?').bind(id).first();
  if (!p) return json({ error: 'Not found' }, 404);
  await requireOwner(env, user, p.story_id);
  await env.DB.prepare('UPDATE plots SET title = ?, description = ? WHERE id = ?').bind(body.title || '', body.description || '', id).run();
  return json({ ok: true });
}

async function deletePlot(env, user, id) {
  const p = await env.DB.prepare('SELECT story_id FROM plots WHERE id = ?').bind(id).first();
  if (!p) return json({ error: 'Not found' }, 404);
  await requireOwner(env, user, p.story_id);
  await env.DB.batch([
    env.DB.prepare('DELETE FROM chart_points WHERE plot_id = ?').bind(id),
    env.DB.prepare('DELETE FROM plots WHERE id = ?').bind(id)
  ]);
  return json({ ok: true });
}

// --- Chart Points ---

async function saveChartPoints(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const del = env.DB.prepare('DELETE FROM chart_points WHERE story_id = ?').bind(storyId);
  const ins = env.DB.prepare('INSERT INTO chart_points (story_id, plot_id, x_pos, y_val, label) VALUES (?, ?, ?, ?, ?)');
  const batch = [del];
  for (const cp of (body.points || [])) {
    batch.push(ins.bind(storyId, cp.plot_id, Math.max(0, Math.min(10000, Math.round(cp.x_pos))), Math.max(0, Math.min(10000, Math.round(cp.y_val))), cp.label || ''));
  }
  await env.DB.batch(batch);
  return json({ ok: true });
}

// --- Admin ---

async function resetAll(env) {
  try { await env.DB.prepare('DELETE FROM turning_points').run(); } catch {}
  try { await env.DB.prepare('DELETE FROM scenes').run(); } catch {}
  await env.DB.batch([
    env.DB.prepare('DELETE FROM chart_points'),
    env.DB.prepare('DELETE FROM plots'),
    env.DB.prepare('DELETE FROM stories')
  ]);
  return json({ ok: true });
}
