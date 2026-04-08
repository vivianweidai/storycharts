# StoryCharts

Interactive story structure visualization tool. Writers create stories with multiple plots, each plotted as a line on a 2D chart where turning points can be dragged to shape the narrative arc.

Hobby project at storycharts.com.

## Stack

- **Cloudflare Pages** — static frontend (HTML/JS/CSS)
- **Cloudflare Pages Functions** — backend API (single catch-all Worker)
- **Cloudflare D1** — SQLite database
- **Cloudflare Access** — Zero Trust auth

## Structure

```
storycharts/
  wrangler.toml              # Cloudflare config
  package.json               # wrangler dev dependency
  public/                    # Static frontend
    index.html               # Story listing + create
    story.html               # Chart editor (raw Canvas 2D)
    app.js                   # Shared: API client, modal, header
    app.css                  # Styles
    favicon/                 # Icons
  functions/api/[[path]].js  # All API routes (single file)
```

## Data Model

- **Stories** — title, owner
- **Plots** — belong to a story, have title + description (2-4 per story)
- **Chart Points** — belong to a plot, stored as (x_pos, y_val) integers 0-10000
  - Displayed as percentages (0-100%) on a square chart
  - 5000 = 50% = midpoint (neutral baseline)
  - Portable: any client (web, iOS) can interpret 0-10000 as normalized coordinates

## Chart

- Raw Canvas 2D (no library dependencies)
- Square 1:1 aspect ratio, blue-tinted blueprint style
- 20x20 grid, midline at y=50%
- Touch + mouse drag to reposition turning points
- Tap to select point (2x size), tap empty to deselect
- Auto-saves on drag end

## Dev Workflow

- Push to `main` auto-deploys to Cloudflare
- `POST /api/admin/reset` — delete all data (requires auth)
- Always work on `main`, commit + push after changes
