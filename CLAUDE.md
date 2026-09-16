# Spoiler Free Highlights

A spoiler-free way to watch sports highlights from YouTube. The backend monitors
a list of YouTube channels, classifies their uploads, and stores game highlights.
The frontend shows a clean feed — **safe matchup title only, no scores, winners,
thumbnails, or original YouTube titles** — with an embedded player on click.

```
YouTube Data API v3  →  Rails backend  →  PostgreSQL  →  JSON API (/api/v1)  →  React (Vite)
```

## Repo layout

- `backend/`  — Rails 8, API-only, PostgreSQL, Active Job + Solid Queue
- `frontend/` — React 19 + Vite, plain CSS, dark theme (JS/JSX, no TypeScript)

Keep the two clearly separated. The frontend never talks to the YouTube API.

## Local development

Prereqs: Ruby 3.3 (rbenv), PostgreSQL running, Node 22 via nvm.

**Non-standard ports** (chosen to avoid collisions with other local apps):
- backend → **3002** (not 3000)
- frontend → **5180** (not 5173), `strictPort`

```bash
# backend — API on :3002 + Solid Queue worker (foreman)
cd backend && bundle install && bin/rails db:prepare && bin/rails db:seed && bin/dev

# frontend — Vite on :5180, proxies /api → :3002
cd frontend && nvm use && npm install && npm run dev
```

The shell's default Node is v14 (unusable). `nvm use` reads `frontend/.nvmrc` (22).

### Env (`backend/.env`, gitignored — copy from `.env.example`)

- `YOUTUBE_API_KEY` — YouTube Data API v3, server-side only, never sent to React
- `CLOUDINARY_URL` — Active Storage uses the Cloudinary service in **development
  and production** (see `config/storage.yml`); tests use local Disk
- `FRONTEND_ORIGIN` — CORS allow-origin (default `http://localhost:5180`)

## Conventions & gotchas

- **Spoiler-safe API contract**: `original_title` and `raw_payload` must **never**
  appear in any `/api/v1` response. Serializers (`app/serializers/`) are explicit
  POROs so the safe-field boundary stays visible. `original_title` is stored only
  for classification/debugging.
- **`json` gem is pinned to `~> 2.21`** in the Gemfile. `json` 3.x drops the
  positional-options form of `JSON.parse` that Rails 8.1.3's ActiveSupport JSON
  decoder still uses, which breaks `jsonb` deserialization. Do not unpin.
- **Single-database setup**: Solid Queue / Solid Cache tables live in the primary
  database as regular migrations (`*_create_solid_queue_tables.rb` etc.). There is
  **no** separate queue/cache database and **no** `config.solid_queue.connects_to`.
  Production is one `DATABASE_URL`. Don't reintroduce the multi-database layout.
- **`sport` is derived per-video** via `video.competition.sport`, never stored on
  `Channel` — one channel (NBC Sports) carries multiple sports.
- A competition is classified and shown only when `active: true`. Premier League,
  Champions League, Carabao Cup, and College Football are all active.
- Ruby style: `rubocop-rails-omakase`. Tests: Minitest (`bin/rails test`).

## Video classification (`app/services/`)

Deterministic, title-based, no AI. Kept out of the job and the YouTube client.

- `VideoClassifier#classify(upload)` — exclude keyword filters (reaction,
  analysis, press conference, pre/postgame, preview, predictions…), then tries
  each active competition's title rule. Falls back to a global `/highlights/i`
  include check only when no rule claims the upload (some channels, e.g. ESPN/FOX
  college football, omit the word), so a positive rule match always wins.
- `Classification::TitleRules::REGISTRY` — maps a competition slug to a rule class
  (`PremierLeagueTitleRule`, `ChampionsLeagueTitleRule`, `CollegeFootballTitleRule`).
- `Classification::MatchupParser` — splits "Home v. Away" / "Home vs. Away" and
  strips channel cruft: NBC/CBS suffixes ("(En Español)", ": Extended Highlights"),
  the FOX "🏈 FOX College Football" tail, an ESPN hype phrase before the matchup
  (set off by an emoji), and AP-ranking prefixes ("No. 12 ", "#3 ").
- `Classification::Result` — `highlight?`, `competition`, `safe_title`, `reason`.

**To add a competition**: add a `*TitleRule` (implements `safe_title_for(title)`),
register it in `TitleRules`, add the competition to `db/seeds.rb` with
`active: true`, add a channel if needed, dry-run classify against real uploads,
then sync. If the channel was already synced while the competition was inactive,
run `bin/rails youtube:reclassify` to re-run the classifier over stored uploads.
Add classifier tests with real title strings.

## YouTube sync

- `ChannelSynchronizer#call` — resolve uploads playlist → fetch recent uploads →
  skip known video ids → fetch details → classify → persist. Stores non-highlights
  too (`is_highlight: false`, `competition: nil`) so they aren't re-classified.
- `Youtube::Client` — fetch only (playlistItems, videos, channels-by-handle).
- `FetchYoutubeVideosJob` — loops `Channel.active`, per-channel error isolation.
  Recurring `every 20 minutes` in `config/recurring.yml` (production only).
- Rake: `bin/rails youtube:sync`, `bin/rails "youtube:sync_channel[ID]"`,
  `bin/rails youtube:enqueue_sync`, `bin/rails youtube:reclassify` (re-runs the
  classifier over stored uploads, no API calls).
- **Lookback is 300** (`ChannelSynchronizer::DEFAULT_LOOKBACK`). NBC/CBS post
  30–40 videos/day; 50 only reaches ~1.5 days and misses match highlights.
- **Geography**: the Data API is not geo-restricted by caller IP, so the job runs
  fine anywhere. Only *playback* (the IFrame embed in the viewer's browser) is
  region-locked — the API stores `region_restricted` / `embeddable` per video and
  the UI shows a neutral note instead of a broken player.

## Data model

`Sport` → `Competition` → `Video` (a `Video` also `belongs_to :channel`).

- `Sport`: name, slug, `font_awesome_class` (e.g. `"fa-solid fa-futbol"`)
- `Competition`: name, slug, `active`, `video_naming_convention`, `api_url` (V3),
  `has_one_attached :photo` (league crest, Cloudinary)
- `Channel`: name, `youtube_channel_id`, `youtube_url` (public channel link,
  shown in the UI), `uploads_playlist_id`, `active`, `last_synced_at`
- `Video`: `youtube_video_id` (unique), `original_title` (private), `safe_title`,
  `published_at`, `duration_seconds`, `is_highlight`, `region_restricted`,
  `embeddable`, `raw_payload` (jsonb, private), `competition_id` (nullable)

## API

- `GET /api/v1/videos` — displayable highlights, newest first. Filters:
  `?sport=<slug>`, `?competition=<slug>`. Paginated by date, not offset (highlights
  arrive continuously, so page numbers would shift): `?since=<ISO8601>` and/or
  `?before=<ISO8601>`; with neither given, defaults to the last 7 days. To load
  an older page, pass `since`/`before` as the next 7-day window back from the
  oldest `published_at` already loaded. Each item: `safe_title`,
  `sport {name, slug, icon}`, `competition {name, slug, photo_url}`,
  `channel {name, youtube_url}`, `published_at`, `duration_seconds`,
  `duration_iso8601`, `youtube_video_id`, `region_restricted`, `embeddable`.
  `channel.youtube_url` drives the frontend's "sourced from" link strip, so
  the UI doesn't read like a rehosted stream — it's derived per-video rather
  than from a separate channels endpoint, so it only ever lists channels
  actually represented in the current feed.
- `GET /api/v1/sports` — sports with ≥1 active competition, competitions nested.

## Frontend

- Routes are bookmarkable: `/`, `/:sportSlug`, `/:sportSlug/:competitionSlug`
  (`HighlightsPage` reads `useParams`).
- `FilterBar` (sport → then competition), `SourceChannels` (links to the
  YouTube channels behind the currently-shown videos, shown between the
  filters and the feed), `VideoCard` (neutral — league crest + safe title, no thumbnails),
  `VideoPlayer` (YouTube `nocookie` embed, mounted only on "Watch Highlights"
  click), `SportLabel` (FA icon + name).
- Font Awesome 6 via a `<link>` in `index.html` (no npm dep). Icon class comes
  from the API (`sport.icon`).
- `src/api/client.js` — `fetch` wrapper, base `import.meta.env.VITE_API_BASE_URL`
  (default `/api/v1`, via the Vite proxy).
- Dependencies are deliberately minimal: React, React Router, Vite. No Redux, no
  UI kit, no Hotwire/Turbo/Stimulus.
- **PWA**: hand-rolled, no `vite-plugin-pwa` (keeps the no-extra-deps rule above).
  `public/manifest.webmanifest` + icons, linked from `index.html`.
  `public/sw.js` is registered from `main.jsx` in production builds only (a
  service worker in dev would cache against Vite's HMR). The worker never
  caches `/api/*` — that data changes continuously — and is network-first for
  navigations so React Router paths always get a fresh `index.html`; it's
  cache-first only for same-origin static assets (Vite's hashed build output).

## Roadmap

- **V1 (done)**: NBC Sports → Premier League highlights, end to end.
- **V2 (done)**: Champions League via CBS Sports Golazo; NCAA college football
  via NBC Sports, CFB ON FOX, ESPN College Football, and CBS Sports CFB.
- **V3**: `Game` + `Highlight` models, schedule APIs (`Competition#api_url`), match
  highlights to scheduled games, "awaiting highlights" state.
- **Later**: team models/following, watched state, user accounts, notifications,
  AI-assisted classification / safe-title generation, thumbnail spoiler detection.
  Keep the schema flexible for these; don't build them early.
