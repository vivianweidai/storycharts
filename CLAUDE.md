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
- **Cloudflare Pages** — hosts the frontend (static HTML/JS/CSS)
- **Cloudflare Pages Functions** — backend API (single catch-all Worker)
- **Cloudflare D1** — SQLite database (replaces NDB/Datastore)
- **Cloudflare Access** — Zero Trust auth (replaces Google Users API)
- **GitHub repo** — push to `main` auto-deploys to Cloudflare

### Cloudflare Free Tier (sufficient for low traffic)
- Pages: unlimited sites, unlimited bandwidth
- Workers: 100k requests/day
- D1: 5M reads/day, 100k writes/day, 5GB storage

### Project Structure
```
storycharts/
  wrangler.toml              # Cloudflare config
  package.json               # wrangler dev dependency
  schema.sql                 # D1 database schema
  public/                    # Static frontend (served by Cloudflare Pages)
    index.html               # Story listing
    story.html               # View/edit story + chart
    chart.html               # Turning point editor with live preview
    app.js                   # Shared JS: API client, Chart.js rendering, modals
    app.css                  # Stylesheet
  functions/api/[[path]].js  # Single catch-all Worker (all API routes)
```

### Deployment Steps
1. Create D1 database: `wrangler d1 create storycharts`
2. Update `wrangler.toml` with real database_id
3. Connect GitHub repo to Cloudflare Pages for auto-deploy
4. Configure Cloudflare Access for auth (Zero Trust dashboard)
5. Point storycharts.com DNS to Cloudflare Pages

### Design Principles
- Concise simplicity — minimal code, minimal dependencies
- Single-developer workflow — no complex branching, push to `main` to deploy
- Clean UI — modern replacement for jQuery Mobile
- Moderation — admin visibility into all user content via D1 dashboard or a simple admin route
