# Signal Daily

Signal Daily is a calm, evidence-weighted iOS news briefing app. It gives users one finite global briefing per day with source transparency, framing checks, emotional-load controls, and explicit uncertainty.

## What is included

- SwiftUI iOS 17 app using MVVM-style feature state.
- Codable models for briefings, stories, sources, confidence, framing checks, user preferences, depth tokens, evidence checks, and bias audits.
- Finite calm-update models for meaningful changes after the main daily briefing.
- StoreKit 2 subscription scaffolding for a monthly Signal Daily Plus plan.
- Async/await API client for a backend that proxies Cloudflare R2 content.
- Local file cache for offline access to the most recently downloaded briefing.
- Mock briefing data for development.
- Tests for JSON decoding, depth token behavior, cache persistence, and neutrality/bias-audit guardrails.

## Backend contract

The app expects a backend API rather than direct R2 access:

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

R2 can store objects behind that API at paths such as:

- `/briefings/yyyy-mm-dd/global.json`
- `/briefings/yyyy-mm-dd/updates.json`
- `/briefings/yyyy-mm-dd/uk.json`
- `/raw/yyyy-mm-dd/gdelt/hh.json`
- `/pipeline/latest.json`
- `/articles/{articleId}.json`
- `/images/{imageId}.jpg`
- `/sources/{sourceId}.json`

## Local setup

```sh
xcodegen generate
xcodebuild test -project SignalDaily.xcodeproj -scheme SignalDaily -destination 'platform=iOS Simulator,name=iPhone 17'
```

## API wiring

Debug builds default to `SignalDailyUseMocks=YES`. Set `SIGNAL_DAILY_USE_MOCKS=NO` in the Xcode build settings or generated Info.plist config to make the app call `SignalDailyAPIBaseURL`, which defaults to the deployed Worker at `https://signal-daily-api.nathancoleasi.workers.dev`.

The local Worker scaffold lives in `backend/worker`:

```sh
cd backend/worker
npm install
npm run types
npm test
npm run dev
```

For local Worker testing, temporarily set `SIGNAL_DAILY_API_BASE_URL` to `http://127.0.0.1:8787`.

## Live pipeline

The deployed Worker runs an hourly Cloudflare Cron Trigger at `0 * * * *` UTC. Each run pulls one hour of public GDELT DOC article discovery data, stores a raw R2 snapshot, updates source records, and publishes a finite `updates.json` document for the app. The update lane is intentionally bounded and cautious: it describes newly detected reporting and corroboration level rather than treating a feed headline as confirmed fact.

## Subscription setup

Create one auto-renewable subscription in App Store Connect:

- Product ID: `signal_daily_monthly`
- Reference name: `Signal Daily Plus Monthly`
- Duration: 1 month
- UK target price: `£0.99` or the nearest available App Store Connect price point

The app uses StoreKit 2 to load products, purchase, restore purchases, and check current entitlements. Keep using App Store in-app purchase for this digital content subscription.
