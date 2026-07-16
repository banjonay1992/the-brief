#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const baseURL = process.env.SIGNAL_DAILY_API_BASE_URL ?? "https://signal-daily-api.nathancoleasi.workers.dev";
const token = process.env.PIPELINE_ADMIN_TOKEN;
const inputPath = resolve(process.env.SIGNAL_DAILY_EDITORIAL_APPLY_PATH ?? "tmp/codex-editorial-apply.json");

if (process.argv.includes("--help")) {
  console.log("Usage: PIPELINE_ADMIN_TOKEN=... npm run editorial:apply");
  console.log("Optional env: SIGNAL_DAILY_EDITORIAL_APPLY_PATH, SIGNAL_DAILY_API_BASE_URL");
  process.exit(0);
}

if (!token) {
  console.error("PIPELINE_ADMIN_TOKEN is required.");
  process.exit(1);
}

const payload = await readFile(inputPath, "utf8");
const parsed = JSON.parse(payload);
if (!parsed.date || !Array.isArray(parsed.stories)) {
  console.error("Patch file must be JSON shaped as { date, stories: [...] }.");
  process.exit(1);
}

const response = await fetch(new URL("/api/admin/editorial/apply", baseURL), {
  method: "POST",
  headers: {
    authorization: `Bearer ${token}`,
    "content-type": "application/json"
  },
  body: JSON.stringify(parsed)
});

const body = await response.text();
if (!response.ok) {
  console.error(body);
  process.exit(1);
}

const result = JSON.parse(body);
console.log(`Applied ${result.applied}/${result.requested} Codex editorial patches for ${result.date}.`);
console.log(result.storyIDs.join("\n"));
