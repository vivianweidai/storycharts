// StoryCharts API — single catch-all Worker

export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/api/, '');
  const method = request.method;

  await env.DB.exec('PRAGMA foreign_keys = ON');
  await autoMigrate(env.DB);

  const user = getUser(request);

  try {
    if (path === '/auth/login') return Response.redirect(url.origin + '/', 302);
    if (path === '/auth/me') return json(user);

    const storyMatch = path.match(/^\/stories\/(\d+)$/);
    const storySubMatch = path.match(/^\/stories\/(\d+)\/(plots|chartpoints)$/);
    const plotMatch = path.match(/^\/plots\/(\d+)$/);

    // Admin: delete all stories, plots, chart_points
    if (path === '/admin/reset' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      // Clean legacy tables if they exist
      try { await env.DB.prepare('DELETE FROM turning_points').run(); } catch {}
      try { await env.DB.prepare('DELETE FROM scenes').run(); } catch {}
      await env.DB.batch([
        env.DB.prepare('DELETE FROM chart_points'),
        env.DB.prepare('DELETE FROM plots'),
        env.DB.prepare('DELETE FROM stories')
      ]);
      return json({ ok: true, message: 'All data deleted' });
    }

    if (path === '/stories' && method === 'GET') return await listStories(env, user);
    if (path === '/stories' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await createStory(env, user, await request.json());
    }
    if (storyMatch && method === 'GET') return await getStory(env, user, storyMatch[1]);
    if (storyMatch && method === 'PUT') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await updateStory(env, user, storyMatch[1], await request.json());
    }
    if (storyMatch && method === 'DELETE') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await deleteStory(env, user, storyMatch[1]);
    }

    // --- Plot routes ---
    if (storySubMatch && storySubMatch[2] === 'plots' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await createPlot(env, user, storySubMatch[1], await request.json());
    }
    if (plotMatch && method === 'PUT') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await updatePlot(env, user, plotMatch[1], await request.json());
    }
    if (plotMatch && method === 'DELETE') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await deletePlot(env, user, plotMatch[1]);
    }

    // --- Chart points ---
    if (storySubMatch && storySubMatch[2] === 'chartpoints' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await saveChartPoints(env, user, storySubMatch[1], await request.json());
    }

    return json({ error: 'Not found' }, 404);
  } catch (e) {
    if (e && e.status) return json({ error: e.error }, e.status);
    console.error(e);
    return json({ error: 'Internal server error' }, 500);
  }
}

// --- Helpers ---

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

let migrated = false;
async function autoMigrate(db) {
  if (migrated) return;
  await db.batch([
    db.prepare("CREATE TABLE IF NOT EXISTS stories (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL DEFAULT '', private INTEGER NOT NULL DEFAULT 0, userid TEXT NOT NULL, email TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now')))"),
    db.prepare("CREATE TABLE IF NOT EXISTS plots (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, title TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 100)"),
    db.prepare("CREATE TABLE IF NOT EXISTS chart_points (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, plot_id INTEGER NOT NULL REFERENCES plots(id) ON DELETE CASCADE, x_pos INTEGER NOT NULL DEFAULT 0, y_val INTEGER NOT NULL DEFAULT 0)")
  ]);
  migrated = true;
}

function getUser(request) {
  const headerEmail = request.headers.get('Cf-Access-Authenticated-User-Email');
  if (headerEmail) return { userid: headerEmail, email: headerEmail };

  const cookie = request.headers.get('Cookie') || '';
  const match = cookie.match(/CF_Authorization=([^;]+)/);
  if (match) {
    try {
      const payload = JSON.parse(atob(match[1].split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      if (payload.email) return { userid: payload.email, email: payload.email };
    } catch {}
  }

  const devUser = request.headers.get('X-Dev-User');
  if (devUser) return { userid: devUser, email: devUser };

  return null;
}

async function requireOwner(env, user, storyId) {
  const story = await env.DB.prepare('SELECT userid FROM stories WHERE id = ?').bind(storyId).first();
  if (!story) throw { status: 404, error: 'Story not found' };
  if (story.userid !== user.userid) throw { status: 403, error: 'Forbidden' };
  return story;
}

// --- Story handlers ---

async function listStories(env, user) {
  const stories = await env.DB.prepare(
    'SELECT id, title, userid FROM stories ORDER BY id DESC'
  ).all();
  return json(stories.results);
}

async function createStory(env, user, body) {
  const result = await env.DB.prepare(
    'INSERT INTO stories (title, userid, email) VALUES (?, ?, ?)'
  ).bind(body.title || '', user.userid, user.email).run();
  const storyId = result.meta.last_row_id;

  // Random 2-4 plots
  const plotNames = ['Internal', 'Relationship', 'External', 'Mystery'];
  const plotDescs = [
    'The protagonist\'s inner journey — fears, doubts, growth, and self-discovery.',
    'How key relationships evolve — trust, conflict, bonding, and betrayal.',
    'The outer conflict — obstacles, antagonists, and the main goal.',
    'Hidden elements — secrets, twists, and revelations that reshape the story.'
  ];
  const numPlots = 2 + Math.floor(Math.random() * 3); // 2, 3, or 4

  const plotInsert = env.DB.prepare(
    'INSERT INTO plots (story_id, title, description, sort_order) VALUES (?, ?, ?, ?)'
  );
  const plotIds = [];
  for (let i = 0; i < numPlots; i++) {
    const r = await plotInsert.bind(storyId, plotNames[i], plotDescs[i], i + 1).run();
    plotIds.push(r.meta.last_row_id);
  }

  // For each plot, generate 3-8 random turning points (0-10000 coordinates)
  // x_pos: story progression (0=start, 10000=end)
  // y_val: plot intensity (5000=neutral midpoint)
  const cpInsert = env.DB.prepare(
    'INSERT INTO chart_points (story_id, plot_id, x_pos, y_val) VALUES (?, ?, ?, ?)'
  );
  const batch = [];
  for (const plotId of plotIds) {
    const numTPs = 3 + Math.floor(Math.random() * 6); // 3 to 8
    const points = [];
    for (let i = 0; i < numTPs; i++) {
      points.push({
        x: Math.floor(Math.random() * 10001), // 0-10000
        y: Math.floor(Math.random() * 10001)  // 0-10000
      });
    }
    points.sort((a, b) => a.x - b.x);
    for (const p of points) {
      batch.push(cpInsert.bind(storyId, plotId, p.x, p.y));
    }
  }
  if (batch.length) await env.DB.batch(batch);

  return json({ id: storyId }, 201);
}

async function getStory(env, user, id) {
  const story = await env.DB.prepare('SELECT * FROM stories WHERE id = ?').bind(id).first();
  if (!story) return json({ error: 'Not found' }, 404);

  const [plots, cps] = await Promise.all([
    env.DB.prepare('SELECT * FROM plots WHERE story_id = ? ORDER BY sort_order').bind(id).all(),
    env.DB.prepare('SELECT * FROM chart_points WHERE story_id = ? ORDER BY plot_id, x_pos').bind(id).all()
  ]);

  return json({
    story,
    plots: plots.results,
    chartPoints: cps.results,
    isOwner: user && user.userid === story.userid
  });
}

async function updateStory(env, user, id, body) {
  await requireOwner(env, user, id);
  await env.DB.prepare(
    'UPDATE stories SET title = ?, updated_at = datetime(\'now\') WHERE id = ?'
  ).bind(body.title || '', id).run();
  return json({ ok: true });
}

async function deleteStory(env, user, id) {
  await requireOwner(env, user, id);
  await env.DB.prepare('DELETE FROM stories WHERE id = ?').bind(id).run();
  return json({ ok: true });
}

// --- Plot handlers ---

async function createPlot(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const result = await env.DB.prepare(
    'INSERT INTO plots (story_id, title, description, sort_order) VALUES (?, ?, ?, 100)'
  ).bind(storyId, body.title || '', body.description || '').run();
  return json({ id: result.meta.last_row_id }, 201);
}

async function updatePlot(env, user, id, body) {
  const plot = await env.DB.prepare('SELECT story_id FROM plots WHERE id = ?').bind(id).first();
  if (!plot) return json({ error: 'Not found' }, 404);
  await requireOwner(env, user, plot.story_id);
  await env.DB.prepare('UPDATE plots SET title = ?, description = ? WHERE id = ?')
    .bind(body.title || '', body.description || '', id).run();
  return json({ ok: true });
}

async function deletePlot(env, user, id) {
  const plot = await env.DB.prepare('SELECT story_id FROM plots WHERE id = ?').bind(id).first();
  if (!plot) return json({ error: 'Not found' }, 404);
  await requireOwner(env, user, plot.story_id);
  // Delete associated chart points too
  await env.DB.batch([
    env.DB.prepare('DELETE FROM chart_points WHERE plot_id = ?').bind(id),
    env.DB.prepare('DELETE FROM plots WHERE id = ?').bind(id)
  ]);
  return json({ ok: true });
}

// --- Chart points handler ---

async function saveChartPoints(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const delStmt = env.DB.prepare('DELETE FROM chart_points WHERE story_id = ?').bind(storyId);
  const insStmt = env.DB.prepare(
    'INSERT INTO chart_points (story_id, plot_id, x_pos, y_val) VALUES (?, ?, ?, ?)'
  );
  const batch = [delStmt];
  for (const cp of (body.points || [])) {
    const x = Math.max(0, Math.min(10000, Math.round(cp.x_pos)));
    const y = Math.max(0, Math.min(10000, Math.round(cp.y_val)));
    batch.push(insStmt.bind(storyId, cp.plot_id, x, y));
  }
  await env.DB.batch(batch);
  return json({ ok: true });
}
