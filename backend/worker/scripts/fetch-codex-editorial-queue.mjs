#!/usr/bin/env node

import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const baseURL = process.env.SIGNAL_DAILY_API_BASE_URL ?? "https://signal-daily-api.nathancoleasi.workers.dev";
const token = process.env.PIPELINE_ADMIN_TOKEN;
const date = process.env.SIGNAL_DAILY_EDITORIAL_DATE ?? new Date().toISOString().slice(0, 10);
const limit = process.env.SIGNAL_DAILY_EDITORIAL_LIMIT ?? "12";
const outputPath = resolve(process.env.SIGNAL_DAILY_EDITORIAL_QUEUE_PATH ?? "tmp/codex-editorial-queue.json");

if (process.argv.includes("--help")) {
  console.log("Usage: PIPELINE_ADMIN_TOKEN=... npm run editorial:queue");
  console.log("Optional env: SIGNAL_DAILY_EDITORIAL_DATE, SIGNAL_DAILY_EDITORIAL_LIMIT, SIGNAL_DAILY_EDITORIAL_QUEUE_PATH, SIGNAL_DAILY_API_BASE_URL");
  process.exit(0);
}

if (!token) {
  console.error("PIPELINE_ADMIN_TOKEN is required.");
  process.exit(1);
}

const url = new URL("/api/admin/editorial/queue", baseURL);
url.searchParams.set("date", date);
url.searchParams.set("limit", limit);

const response = await fetch(url, {
  headers: {
    authorization: `Bearer ${token}`
  }
});

const body = await response.text();
if (!response.ok) {
  console.error(body);
  process.exit(1);
}

await mkdir(resolve(outputPath, ".."), { recursive: true });
await writeFile(outputPath, body);

const queue = JSON.parse(body);
console.log(`Wrote ${queue.selected}/${queue.total} editorial stories for ${queue.date} to ${outputPath}`);
console.log("Next: write patches to tmp/codex-editorial-apply.json, then run npm run editorial:apply.");
