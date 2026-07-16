# Codex Editorial Automation

This app keeps the hourly Cloudflare Worker as the reliable collector and uses Codex as the editorial writer.

The Worker should:
- fetch live sources hourly,
- cluster and rank stories,
- write baseline briefing/article JSON to R2,
- avoid OpenAI synthesis by default.

Codex should:
- fetch a protected editorial queue,
- rewrite only the queued card/detail fields,
- validate the rewritten payload for missing IDs and generic template language,
- apply patches through the protected editorial endpoint.

The complete local runner is:

```bash
npm run editorial:codex
```

That command uses Codex itself as the editor. It does not require `OPENAI_API_KEY`, and it must not enable Worker-side OpenAI synthesis.

## Codex skill

Use the personal Codex skill:

```text
$the-brief-editorial
```

The skill lives at:

```text
/Users/main/.codex/skills/the-brief-editorial
```

It contains the repeatable queue, rewrite, validation, and apply workflow for this app.

## Required secret

The Codex automation needs `PIPELINE_ADMIN_TOKEN` available in its environment. Do not paste the value into chat or commit it.

## Automation schedule

Run hourly, ideally 5-10 minutes after the Cloudflare Worker cron:

```cron
10 * * * *
```

## Automation prompt

Use this as the recurring Codex automation prompt:

```text
You are the editorial automation for The Brief.

Work in:
/Users/main/Documents/Codex/2026-05-17/create-a-new-folder-and-project/SignalDaily/backend/worker

Goal:
Rewrite the latest queued briefing cards using Codex, not the OpenAI API.

Steps:
1. Use `$the-brief-editorial`.
2. Run `npm run editorial:queue`.
3. Read `tmp/codex-editorial-queue.json`.
4. Create `tmp/codex-editorial-apply.json` shaped exactly as:
   {
     "date": "YYYY-MM-DD",
     "stories": [
       {
         "id": "...",
         "headline": "...",
         "summary": "...",
         "whyItMatters": "...",
         "whatHappened": "...",
         "whatWeKnow": ["...", "..."],
         "whatIsUnclear": ["...", "..."],
         "confidenceReason": "...",
         "framingCheck": {
           "westernMainstream": "...",
           "localRegional": "...",
           "officialGovernment": "...",
           "affectedPopulation": "...",
           "independentEvidence": "...",
           "humanRightsNGO": null,
           "opposingSide": null
         },
         "biasAuditNotes": ["Claims are attributed.", "Uncertainty is stated clearly."]
       }
     ]
   }
5. Preserve every story id.
6. Do not change ratings, regions, categories, emotional load, or source counts.
7. Use the provided source evidence first. Use web search only when needed for context.
8. Write calm, specific copy. Do not repeat the headline.
9. Separate confirmed reporting from claims.
10. Attribute government, military, armed-group, company, NGO, and official claims.
11. Apply the same evidence standard to all countries and actors.
12. Avoid loaded words as neutral fact.
13. Never write “the app”, “the briefing”, or “the card” in user-facing fields.
14. Run `npm run editorial:validate`.
15. Run `npm run editorial:apply`.
16. Summarize applied story IDs and any rejected/weak source-quality items.
```

## Useful environment overrides

```bash
SIGNAL_DAILY_EDITORIAL_LIMIT=20 npm run editorial:queue
SIGNAL_DAILY_EDITORIAL_DATE=2026-05-19 npm run editorial:queue
SIGNAL_DAILY_EDITORIAL_APPLY_PATH=tmp/custom-apply.json npm run editorial:apply
CODEX_EDITORIAL_MODEL=gpt-5.5 npm run editorial:codex
```

## Backend endpoints

- `GET /api/admin/editorial/queue?date=YYYY-MM-DD&limit=12`
- `POST /api/admin/editorial/apply`

Both require:

```http
Authorization: Bearer <PIPELINE_ADMIN_TOKEN>
```

## Cost control

`OPENAI_SYNTHESIS_ENABLED` is set to `NO` in `wrangler.jsonc`, so the scheduled Worker does not spend OpenAI API credits during normal hourly collection.

The Codex editorial runner uses the signed-in Codex app/CLI session rather than an OpenAI API key. It still needs `PIPELINE_ADMIN_TOKEN` so it can read and apply protected R2 editorial payloads.
