PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS stories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL DEFAULT '',
  private INTEGER NOT NULL DEFAULT 1,
  userid TEXT NOT NULL,
  email TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_stories_userid ON stories(userid);
CREATE INDEX IF NOT EXISTS idx_stories_public ON stories(private, updated_at);

CREATE TABLE IF NOT EXISTS plots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 100
);

CREATE INDEX IF NOT EXISTS idx_plots_story ON plots(story_id, sort_order);

CREATE TABLE IF NOT EXISTS scenes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 100
);

CREATE INDEX IF NOT EXISTS idx_scenes_story ON scenes(story_id, sort_order);

CREATE TABLE IF NOT EXISTS turning_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  plot_id INTEGER NOT NULL REFERENCES plots(id) ON DELETE CASCADE,
  scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
  tp_type TEXT NOT NULL DEFAULT 'None',
  UNIQUE(plot_id, scene_id)
);

CREATE INDEX IF NOT EXISTS idx_tp_story ON turning_points(story_id);
