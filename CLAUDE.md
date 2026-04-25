# StoryCharts

Interactive story structure visualization tool. Writers create stories with multiple plots, each plotted as a line on a 2D chart where scenes can be dragged to shape the narrative arc.

Hobby project at storycharts.com.

## Stack

- **Cloudflare Workers + Static Assets** — single Worker serves `web/` static files and `/api/*` from one fetch handler
- **Cloudflare D1** — SQLite database
- **Cloudflare Access** — Zero Trust auth (login flow only; read API is public, mutations require auth)
- **SwiftUI** — native Apple apps (iPhone, iPad, Apple Watch)
- **Kotlin + Jetpack Compose** — native Android apps (phone + Wear OS)

## Structure

```
storycharts/
  pipeline/worker/           # Cloudflare Worker
    wrangler.toml            #   Worker config + D1 + Static Assets bindings
    package.json             #   pnpm dev/deploy scripts
    src/index.js             #   fetch handler — routes /api/* + falls through to env.ASSETS
  web/                       # Static frontend (served by env.ASSETS binding)
    index.html               # Story listing + create
    story.html               # Chart editor (raw Canvas 2D)
    app.js                   # Shared: API client, modal, header
    app.css                  # Styles
    favicon.ico              # Site icon
  apple/                     # Native Apple apps
    StoryCharts.xcodeproj    # Xcode project (2 targets)
    shared/                  # Code shared across all Apple platforms
      models/                # Story, Plot, ChartPoint structs
      api/                   # APIClient hitting storycharts.com/api
      views/                 # ChartView, StoryListView, StoryDetailView
    iphone/                  # iOS app (universal: iPhone + iPad)
    watch/                   # watchOS companion app (read-only charts)
  android/                   # Gradle multi-module project
    settings.gradle.kts      # includes :shared, :app, :wear
    shared/                  # Android library — models, ApiClient, charts
    app/                     # Phone app (com.jamesdai.storycharts)
    wear/                    # Wear OS companion (read-only, auto-playback)
```

## Apple Apps

- Team ID: CR3TXC4TRW (James Dai Limited)
- Bundle ID: `com.jamesdai.storycharts` (iOS), `.watchkitapp` (watchOS)
- Targets iOS 17+ and watchOS 10+
- All platforms share models, API client, and ChartView via Shared/
- Watch app is read-only (view stories and chart thumbnails)

## Android Apps

- Package: `com.jamesdai.storycharts` (phone + wear both — ship standalone)
- Min SDK 26 (Android 8.0+), compile SDK 35, phone targetSdk 35, wear targetSdk 34
  (wear-compose 1.4.0 crashes on targetSdk 35 — see comment in wear/build.gradle.kts)
- Release signing: `android/keystore.properties` (git-ignored) points at
  `~/keystores/storycharts-release.jks`
- `:shared` library holds data + chart + playback code reused by both apps
- OAuth callback handled via `storycharts://` deep link

## Data Model

- **Stories** — title, userid (owner)
- **Plots** — belong to a story, have title, color, sort_order
- **Scenes** (chart_points in DB) — belong to a plot, stored as (x_pos, y_val) integers 0-10000
  - Displayed as percentages (0-100%) on a square chart
  - 5000 = 50% = midpoint (neutral baseline)
  - Portable: any client (web, iOS, Android) can interpret 0-10000 as normalized coordinates

## Chart

- Raw Canvas 2D (no library dependencies)
- Square 1:1 aspect ratio, blue-tinted blueprint style
- 20x20 grid, midline at y=50%
- Touch + mouse drag to reposition scenes
- Tap to select scene (2x size), tap empty to deselect
- Auto-saves on drag end

## Dev Workflow

- GitHub is source control only — no auto-deploy
- Deploy: `cd pipeline/worker && pnpm run deploy` (note: `pnpm deploy` is a built-in pnpm command, must use `run`)
- Local dev: `cd pipeline/worker && pnpm dev` (port 4321; D1 + assets via local emulation, add `--remote` for live D1)
- `POST /api/admin/reset` — delete all data (requires auth)
- Always work on `main`
