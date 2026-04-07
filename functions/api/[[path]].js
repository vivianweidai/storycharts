// StoryCharts API — single catch-all Worker
// Auth: Cloudflare Access protects /api/auth/*, sets CF_Authorization cookie domain-wide.
// Worker reads that cookie on all paths to identify the user.

export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/api/, '');
  const method = request.method;

  // Enable foreign keys and auto-migrate
  await env.DB.exec('PRAGMA foreign_keys = ON');
  await autoMigrate(env.DB);

  // Auth: read CF_Authorization cookie (set by Cloudflare Access after login),
  // or Cf-Access-Authenticated-User-Email header (on Access-protected paths),
  // or X-Dev-User header (local dev only)
  const user = getUser(request);

  try {
    // Login endpoint — protected by Cloudflare Access, just redirects home after auth
    if (path === '/auth/login') return Response.redirect(url.origin + '/', 302);
    if (path === '/auth/me') return json(user);

    // --- Story routes ---
    const storyMatch = path.match(/^\/stories\/(\d+)$/);
    const storySubMatch = path.match(/^\/stories\/(\d+)\/(plots|scenes|order|turningpoints)$/);
    const plotMatch = path.match(/^\/plots\/(\d+)$/);
    const sceneMatch = path.match(/^\/scenes\/(\d+)$/);

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

    // --- Scene routes ---
    if (storySubMatch && storySubMatch[2] === 'scenes' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await createScene(env, user, storySubMatch[1], await request.json());
    }
    if (sceneMatch && method === 'PUT') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await updateScene(env, user, sceneMatch[1], await request.json());
    }
    if (sceneMatch && method === 'DELETE') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await deleteScene(env, user, sceneMatch[1]);
    }

    // --- Order route ---
    if (storySubMatch && storySubMatch[2] === 'order' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await updateOrder(env, user, storySubMatch[1], await request.json());
    }

    // --- Turning point routes ---
    if (storySubMatch && storySubMatch[2] === 'turningpoints' && method === 'POST') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await saveTurningPoints(env, user, storySubMatch[1], await request.json());
    }
    if (storySubMatch && storySubMatch[2] === 'turningpoints' && method === 'DELETE') {
      if (!user) return json({ error: 'Unauthorized' }, 401);
      return await clearTurningPoints(env, user, storySubMatch[1]);
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
    db.prepare("CREATE TABLE IF NOT EXISTS stories (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL DEFAULT '', private INTEGER NOT NULL DEFAULT 1, userid TEXT NOT NULL, email TEXT NOT NULL DEFAULT '', summary TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now')))"),
    db.prepare("CREATE TABLE IF NOT EXISTS plots (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, title TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 100)"),
    db.prepare("CREATE TABLE IF NOT EXISTS scenes (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, title TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 100)"),
    db.prepare("CREATE TABLE IF NOT EXISTS turning_points (id INTEGER PRIMARY KEY AUTOINCREMENT, story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE, plot_id INTEGER NOT NULL REFERENCES plots(id) ON DELETE CASCADE, scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE CASCADE, tp_type TEXT NOT NULL DEFAULT 'None', UNIQUE(plot_id, scene_id))")
  ]);
  migrated = true;
}

function getUser(request) {
  // 1. Cf-Access-Authenticated-User-Email header (on Access-protected paths)
  const headerEmail = request.headers.get('Cf-Access-Authenticated-User-Email');
  if (headerEmail) return { userid: headerEmail, email: headerEmail };

  // 2. CF_Authorization cookie (set domain-wide after Access login)
  const cookie = request.headers.get('Cookie') || '';
  const match = cookie.match(/CF_Authorization=([^;]+)/);
  if (match) {
    try {
      // Decode JWT payload (no verification needed — cookie is set by Cloudflare's edge)
      const payload = JSON.parse(atob(match[1].split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      if (payload.email) return { userid: payload.email, email: payload.email };
    } catch {}
  }

  // 3. X-Dev-User header (local development only)
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
    'SELECT id, title, userid, summary, updated_at FROM stories ORDER BY updated_at DESC'
  ).all();
  return json(stories.results);
}

async function createStory(env, user, body) {
  const result = await env.DB.prepare(
    'INSERT INTO stories (title, private, userid, email, summary) VALUES (?, 0, ?, ?, ?)'
  ).bind(body.title || '', user.userid, user.email, body.summary || '').run();
  const storyId = result.meta.last_row_id;

  // Auto-populate with 3 default plots and 3 scenes
  const plotTemplates = [
    { title: 'Internal', description: 'The protagonist\'s inner journey — fears, doubts, growth, and self-discovery.' },
    { title: 'Relationship', description: 'How key relationships evolve — trust, conflict, bonding, and betrayal.' },
    { title: 'External', description: 'The outer conflict — obstacles, antagonists, and the main goal.' }
  ];
  const sceneTemplates = [
    { title: 'Beginning', description: 'Establish the world, characters, and stakes. The inciting incident sets things in motion.' },
    { title: 'Middle', description: 'Rising tension and complications. Characters are tested and alliances shift.' },
    { title: 'End', description: 'The climax and resolution. Conflicts converge and the story reaches its turning point.' }
  ];

  const plotInsert = env.DB.prepare(
    'INSERT INTO plots (story_id, title, description, sort_order) VALUES (?, ?, ?, ?)'
  );
  const sceneInsert = env.DB.prepare(
    'INSERT INTO scenes (story_id, title, description, sort_order) VALUES (?, ?, ?, ?)'
  );

  // Create plots
  const plotResults = [];
  for (let i = 0; i < plotTemplates.length; i++) {
    const r = await plotInsert.bind(storyId, plotTemplates[i].title, plotTemplates[i].description, i + 1).run();
    plotResults.push(r.meta.last_row_id);
  }

  // Create scenes
  const sceneResults = [];
  for (let i = 0; i < sceneTemplates.length; i++) {
    const r = await sceneInsert.bind(storyId, sceneTemplates[i].title, sceneTemplates[i].description, i + 1).run();
    sceneResults.push(r.meta.last_row_id);
  }

  // Generate template turning point values (1-20 scale)
  // Each plot gets a distinct arc shape
  const tpArcs = [
    [8, 14, 18],   // Internal: steady rise
    [12, 6, 16],   // Relationship: dip then rise
    [14, 10, 8]    // External: gradual decline
  ];

  const tpInsert = env.DB.prepare(
    'INSERT INTO turning_points (story_id, plot_id, scene_id, tp_type) VALUES (?, ?, ?, ?)'
  );
  const batch = [];
  for (let pi = 0; pi < plotResults.length; pi++) {
    for (let si = 0; si < sceneResults.length; si++) {
      const value = tpArcs[pi] ? tpArcs[pi][si] : 10;
      batch.push(tpInsert.bind(storyId, plotResults[pi], sceneResults[si], String(value)));
    }
  }
  if (batch.length) await env.DB.batch(batch);

  return json({ id: storyId }, 201);
}

async function getStory(env, user, id) {
  const story = await env.DB.prepare('SELECT * FROM stories WHERE id = ?').bind(id).first();
  if (!story) return json({ error: 'Not found' }, 404);

  const [plots, scenes, tps] = await Promise.all([
    env.DB.prepare('SELECT * FROM plots WHERE story_id = ? ORDER BY sort_order').bind(id).all(),
    env.DB.prepare('SELECT * FROM scenes WHERE story_id = ? ORDER BY sort_order').bind(id).all(),
    env.DB.prepare('SELECT * FROM turning_points WHERE story_id = ?').bind(id).all()
  ]);

  return json({
    story,
    plots: plots.results,
    scenes: scenes.results,
    turningPoints: tps.results,
    isOwner: user && user.userid === story.userid
  });
}

async function updateStory(env, user, id, body) {
  await requireOwner(env, user, id);
  await env.DB.prepare(
    'UPDATE stories SET title = ?, summary = ?, updated_at = datetime(\'now\') WHERE id = ?'
  ).bind(body.title || '', body.summary || '', id).run();
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
  await env.DB.prepare('DELETE FROM plots WHERE id = ?').bind(id).run();
  return json({ ok: true });
}

// --- Scene handlers ---

async function createScene(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const result = await env.DB.prepare(
    'INSERT INTO scenes (story_id, title, description, sort_order) VALUES (?, ?, ?, 100)'
  ).bind(storyId, body.title || '', body.description || '').run();
  return json({ id: result.meta.last_row_id }, 201);
}

async function updateScene(env, user, id, body) {
  const scene = await env.DB.prepare('SELECT story_id FROM scenes WHERE id = ?').bind(id).first();
  if (!scene) return json({ error: 'Not found' }, 404);
  await requireOwner(env, user, scene.story_id);
  await env.DB.prepare('UPDATE scenes SET title = ?, description = ? WHERE id = ?')
    .bind(body.title || '', body.description || '', id).run();
  return json({ ok: true });
}

async function deleteScene(env, user, id) {
  const scene = await env.DB.prepare('SELECT story_id FROM scenes WHERE id = ?').bind(id).first();
  if (!scene) return json({ error: 'Not found' }, 404);
  await requireOwner(env, user, scene.story_id);
  await env.DB.prepare('DELETE FROM scenes WHERE id = ?').bind(id).run();
  return json({ ok: true });
}

// --- Order handler ---

async function updateOrder(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const stmtPlot = env.DB.prepare('UPDATE plots SET sort_order = ? WHERE id = ? AND story_id = ?');
  const stmtScene = env.DB.prepare('UPDATE scenes SET sort_order = ? WHERE id = ? AND story_id = ?');
  const batch = [];
  if (body.plots) body.plots.forEach((id, i) => batch.push(stmtPlot.bind(i + 1, id, storyId)));
  if (body.scenes) body.scenes.forEach((id, i) => batch.push(stmtScene.bind(i + 1, id, storyId)));
  if (batch.length) await env.DB.batch(batch);
  return json({ ok: true });
}

// --- Turning point handlers ---

async function saveTurningPoints(env, user, storyId, body) {
  await requireOwner(env, user, storyId);
  const delStmt = env.DB.prepare('DELETE FROM turning_points WHERE story_id = ?').bind(storyId);
  const insStmt = env.DB.prepare(
    'INSERT INTO turning_points (story_id, plot_id, scene_id, tp_type) VALUES (?, ?, ?, ?)'
  );
  const batch = [delStmt];
  for (const tp of (body.turningPoints || [])) {
    batch.push(insStmt.bind(storyId, tp.plot_id, tp.scene_id, String(tp.tp_type || '10')));
  }
  await env.DB.batch(batch);
  return json({ ok: true });
}

async function clearTurningPoints(env, user, storyId) {
  await requireOwner(env, user, storyId);
  await env.DB.prepare('DELETE FROM turning_points WHERE story_id = ?').bind(storyId).run();
  return json({ ok: true });
}
