# Spoiler Free Highlights

A spoiler-free way to watch sports highlights from YouTube. The app monitors a
configurable list of YouTube channels, classifies their uploads, and shows a
clean feed of highlight videos with **no scores, winners, thumbnails, or original
YouTube titles** — just a safe matchup title and an embedded player.

## Architecture

```
YouTube Data API v3
        │
   Rails backend  ──  PostgreSQL
        │
    JSON API  (/api/v1)
        │
  React frontend (Vite)
```

- **`backend/`** — Rails 8 API-only app. Talks to YouTube, runs background jobs
  (Active Job + Solid Queue), stores channels/videos, classifies videos, and
  exposes a spoiler-safe JSON API.
- **`frontend/`** — React + Vite. Fetches from the Rails API and renders
  spoiler-safe cards. Never talks to YouTube directly (except the embed player
  on click).

## Local development

Prerequisites: Ruby 3.3, PostgreSQL running, Node 22 (`nvm use` in `frontend/`).

### Backend (port 3002)

```bash
cd backend
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/dev            # Rails API + Solid Queue worker (foreman)
```

Set `backend/.env` (copy from `.env.example`):

```
YOUTUBE_API_KEY=your-key-here
FRONTEND_ORIGIN=http://localhost:5180
```

### Frontend (port 5180)

```bash
cd frontend
nvm use
npm install
npm run dev
```

Vite proxies `/api` → `http://localhost:3002`, so the browser only ever talks to
the frontend origin.

## Syncing videos

```bash
# All active channels
bin/rails youtube:sync

# One channel by id
bin/rails "youtube:sync_channel[1]"
```

Or in the console: `ChannelSynchronizer.new(Channel.first).call`

The background job `FetchYoutubeVideosJob` does the same across all active
channels and is what you'd schedule every 15–30 min later.

## Data model (V1)

`Sport` → `Competition` → `Video` (a `Video` also `belongs_to :channel`).
`sport` is derived per-video via its `competition`, never stored on `Channel`,
because one channel (e.g. NBC Sports) carries multiple sports.

Only competitions flagged `active: true` are classified and shown. V1 ships
Premier League; Champions League and College Football are seeded but inactive.
