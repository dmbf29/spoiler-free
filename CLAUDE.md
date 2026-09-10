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
- A competition is classified and shown only when `active: true`. Premier League
  and Champions League are active; College Football is seeded but inactive.
- Ruby style: `rubocop-rails-omakase`. Tests: Minitest (`bin/rails test`).

## Video classification (`app/services/`)

Deterministic, title-based, no AI. Kept out of the job and the YouTube client.

- `VideoClassifier#classify(upload)` — global include (`/highlights/i`) + exclude
  keyword filters (reaction, analysis, press conference, pre/postgame, preview,
  predictions…), then tries each active competition's title rule.
- `Classification::TitleRules::REGISTRY` — maps a competition slug to a rule class
  (`PremierLeagueTitleRule`, `ChampionsLeagueTitleRule`).
- `Classification::MatchupParser` — splits "Home v. Away" / "Home vs. Away" and
  strips NBC/CBS suffixes ("(En Español)", ": Extended Highlights").
- `Classification::Result` — `highlight?`, `competition`, `safe_title`, `reason`.

**To add a competition**: add a `*TitleRule` (implements `safe_title_for(title)`),
register it in `TitleRules`, add the competition to `db/seeds.rb` with
`active: true`, add a channel if needed, dry-run classify against real uploads,
then sync. Add classifier tests with real title strings.

## YouTube sync

- `ChannelSynchronizer#call` — resolve uploads playlist → fetch recent uploads →
  skip known video ids → fetch details → classify → persist. Stores non-highlights
  too (`is_highlight: false`, `competition: nil`) so they aren't re-classified.
- `Youtube::Client` — fetch only (playlistItems, videos, channels-by-handle).
- `FetchYoutubeVideosJob` — loops `Channel.active`, per-channel error isolation.
  Recurring `every 20 minutes` in `config/recurring.yml` (production only).
- Rake: `bin/rails youtube:sync`, `bin/rails "youtube:sync_channel[ID]"`,
  `bin/rails youtube:enqueue_sync`.
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
- `Channel`: name, `youtube_channel_id`, `uploads_playlist_id`, `active`,
  `last_synced_at`
- `Video`: `youtube_video_id` (unique), `original_title` (private), `safe_title`,
  `published_at`, `duration_seconds`, `is_highlight`, `region_restricted`,
  `embeddable`, `raw_payload` (jsonb, private), `competition_id` (nullable)

## API

- `GET /api/v1/videos` — displayable highlights, newest first. Filters:
  `?sport=<slug>`, `?competition=<slug>`. Each item: `safe_title`,
  `sport {name, slug, icon}`, `competition {name, slug, photo_url}`,
  `published_at`, `duration_seconds`, `duration_iso8601`, `youtube_video_id`,
  `region_restricted`, `embeddable`.
- `GET /api/v1/sports` — sports with ≥1 active competition, competitions nested.

## Frontend

- Routes are bookmarkable: `/`, `/:sportSlug`, `/:sportSlug/:competitionSlug`
  (`HighlightsPage` reads `useParams`).
- `FilterBar` (sport → then competition), `VideoCard` (neutral — league crest +
  safe title, no thumbnails), `VideoPlayer` (YouTube `nocookie` embed, mounted
  only on "Watch Highlights" click), `SportLabel` (FA icon + name).
- Font Awesome 6 via a `<link>` in `index.html` (no npm dep). Icon class comes
  from the API (`sport.icon`).
- `src/api/client.js` — `fetch` wrapper, base `import.meta.env.VITE_API_BASE_URL`
  (default `/api/v1`, via the Vite proxy).
- Dependencies are deliberately minimal: React, React Router, Vite. No Redux, no
  UI kit, no Hotwire/Turbo/Stimulus.

## Roadmap

- **V1 (done)**: NBC Sports → Premier League highlights, end to end.
- **V2 (in progress)**: Champions League via CBS Sports Golazo (done); NCAA
  college football via NBC Sports (rule + activate `college-football`).
- **V3**: `Game` + `Highlight` models, schedule APIs (`Competition#api_url`), match
  highlights to scheduled games, "awaiting highlights" state.
- **Later**: team models/following, watched state, user accounts, notifications,
  AI-assisted classification / safe-title generation, thumbnail spoiler detection.
  Keep the schema flexible for these; don't build them early.
