# Signal Daily Worker API

Cloudflare Worker backend scaffold for the Signal Daily iOS app.

## Endpoints

- `GET /api/briefings/today`
- `GET /api/briefings/:date`
- `GET /api/briefings/today/updates`
- `GET /api/briefings/:date/updates`
- `GET /api/pipeline/latest`
- `GET /api/articles/:articleId`
- `GET /api/sources/:sourceId`
- `POST /api/users/preferences`
- `GET /api/users/preferences`
- `POST /api/depth-tokens/use`
- `GET /api/depth-tokens/today`

The Worker reads R2 first and falls back to mock JSON while local content generation is not wired yet. A Cron Trigger runs hourly and writes raw discovery snapshots plus a finite calm-update object to R2 for the current day.

## R2 object layout

- `briefings/yyyy-mm-dd/global.json`
- `briefings/yyyy-mm-dd/updates.json`
- `briefings/yyyy-mm-dd/uk.json`
- `raw/yyyy-mm-dd/gdelt/hh.json`
- `pipeline/latest.json`
- `articles/{articleId}.json`
- `images/{imageId}.jpg`
- `sources/{sourceId}.json`

## Local development

```sh
npm install
npm run types
npm test
npm run dev
```

To test the scheduled update writer locally:

```sh
wrangler dev --test-scheduled
# then visit http://localhost:8787/__scheduled
```

The scheduled handler runs at `0 * * * *` UTC. It queries GDELT DOC Article List mode for the last hour, stores the raw discovery snapshot at `raw/yyyy-mm-dd/gdelt/hh.json`, writes source records, updates `pipeline/latest.json`, and publishes `briefings/yyyy-mm-dd/updates.json`.

This is intentionally a finite meaningful-updates lane, not an infinite feed. Generated update copy should describe discovery and corroboration status, not present feed headlines as independently verified fact.

The iOS app points at `http://127.0.0.1:8787` when `SignalDailyUseMocks` is set to `NO`.

## Fixture upload examples

```sh
wrangler r2 object put signal-daily-briefings/briefings/2026-05-17/global.json --file fixtures/briefings/2026-05-17/global.json
wrangler r2 object put signal-daily-briefings/articles/story_001.json --file fixtures/articles/story_001.json
wrangler r2 object put signal-daily-briefings/sources/source_001.json --file fixtures/sources/source_001.json
```
