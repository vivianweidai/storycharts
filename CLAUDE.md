# StoryCharts — Project Instructions

## Overview

StoryCharts (storycharts.com) is a web app that helps writers plan and visualize story structure. Users log in, create stories, define plots and scenes, and map turning points on a visual chart showing how each plot progresses through each scene.

This is a hobby project — low priority, worked on when time permits.

## Legacy App (this repo's initial commit)

The original app ran on **Google App Engine** (Python 2.7) with:
- **webapp2** web framework
- **NDB** (Google Cloud Datastore) for data
- **Google App Engine Users API** for auth (Google login)
- **jQuery Mobile** frontend with Django templates
- **Google Charts** for the story chart visualization
- **Memcache** for caching

Key files:
- `StoryCharts.py` — single-file backend (415 lines), all CRUD handlers
- `app.yaml` — App Engine config
- `index.yaml` — Datastore index definitions
- `templates/` — 8 HTML templates (Template, Index, Story, Create, Plot, Scene, Chart, Order)
- `static/` — jQuery, jQuery Mobile, icons, favicon

Data models: Story, Plot, Scene, TurningPoint — hierarchical (story contains plots and scenes, turning points map plots to scenes).

## Planned Rewrite

Modernize onto **Cloudflare** stack with **GitHub** for version control and auto-deploy:

### Stack
- **Cloudflare Pages** — hosts the frontend
- **Cloudflare Workers** — backend logic (replaces App Engine handlers)
- **Cloudflare D1** — SQLite database (replaces NDB/Datastore)
- **Google OAuth** — keep Google login (original app used this)
- **GitHub private repo** — push to `main` auto-deploys to Cloudflare (repo is public for now to preserve legacy code, switch to private when rewrite begins)

### Cloudflare Free Tier (sufficient for low traffic)
- Pages: unlimited sites, unlimited bandwidth
- Workers: 100k requests/day
- D1: 5M reads/day, 100k writes/day, 5GB storage

### Rewrite Steps
1. Scaffold a Cloudflare Workers project with D1
2. Port the data models (Story, Plot, Scene, TurningPoint) to D1/SQLite schema
3. Port the API routes (CRUD for each model, ordering, chart data)
4. Build a clean modern frontend (replace jQuery Mobile)
5. Wire up Google OAuth
6. Connect GitHub repo to Cloudflare Pages for auto-deploy

### Design Principles
- Concise simplicity — minimal code, minimal dependencies
- Single-developer workflow — no complex branching, push to `main` to deploy
- Clean UI — modern replacement for jQuery Mobile
- Moderation — admin visibility into all user content via D1 dashboard or a simple admin route
