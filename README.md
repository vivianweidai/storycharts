# Story Charts

Visualize your story's narrative structure. Drag scenes on a 2D chart to shape character arcs, track subplots, and see how your story flows — available on [web](https://storycharts.com), iPhone, iPad, and Apple Watch.

## What It Does

Create stories with multiple color-coded plots (character arcs, subplots, themes). Each plot contains scenes positioned on a timeline (x-axis) with emotional intensity (y-axis). Drag scenes to reshape the narrative. A midline at 50% represents the emotional baseline.

## Tech Stack

- **Web** — HTML/JS/CSS with raw Canvas 2D rendering (no frameworks or charting libraries)
- **iOS/watchOS** — SwiftUI, targeting iOS 17+ and watchOS 10+
- **Backend** — Cloudflare Pages Functions (D1 SQLite database)
- **Auth** — Cloudflare Access (email-based OAuth)

## Project Structure

```
www/             Static frontend (index.html, story.html, app.js)
functions/api/   Catch-all Cloudflare Worker handling REST API
apple/           SwiftUI apps (iPhone, iPad, Apple Watch)
  shared/        Models, API client, auth, and views shared across platforms
  iphone/        iOS app entry point
  watch/         watchOS app with chart playback
```

## Development

```sh
npm install
npm start        # wrangler pages dev www --d1=DB
```

## License

All rights reserved.
