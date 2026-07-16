#!/usr/bin/env node

import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

export function missingEditorialEnvironment(env = process.env) {
  if (!env.PIPELINE_ADMIN_TOKEN) {
    return "PIPELINE_ADMIN_TOKEN is required so Codex can fetch/apply the protected editorial queue. Do not use OPENAI_API_KEY for this workflow.";
  }
  return null;
}

export function buildCodexEditorialPrompt({
  queuePath = "tmp/codex-editorial-queue.json",
  applyPath = "tmp/codex-editorial-apply.json",
  validateCommand = "npm run editorial:validate",
  applyCommand = "npm run editorial:apply"
} = {}) {
  return `Use $the-brief-editorial for The Brief.

You are running inside the SignalDaily backend worker project.

Goal:
Rewrite the queued The Brief cards using Codex itself. Do not call the OpenAI API. Do not use OPENAI_API_KEY. Do not enable Worker OpenAI synthesis.

Inputs:
- Queue file: ${queuePath}
- Output file to create: ${applyPath}

Rules:
- Preserve every story id from the queue.
- Preserve ratings, regions, categories, emotional load, and source counts.
- Use sourceEvidence first. Use web search only if the queue is genuinely too thin.
- Write calm, specific, evidence-led copy.
- Attribute official, government, military, armed-group, company, NGO, police, court, and analyst claims.
- Apply the same evidence standard to all countries and actors.
- Do not write "the app", "the briefing", or "the card" in user-facing fields.
- Do not reuse detail text across unrelated stories.

Steps:
1. Read ${queuePath}.
2. Write ${applyPath} as JSON shaped { "date": "YYYY-MM-DD", "stories": [...] }.
3. Run \`${validateCommand}\`.
4. If validation passes, run \`${applyCommand}\`.
5. Spot-check the applied IDs using the live article endpoint.
6. Report applied IDs and any weak-source stories.`;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    stdio: "inherit",
    shell: false,
    ...options
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} exited with ${result.status}`);
  }
}

async function readQueueSummary(queuePath) {
  if (!existsSync(queuePath)) {
    return { selected: 0, total: 0 };
  }
  const queue = JSON.parse(await readFile(queuePath, "utf8"));
  return {
    selected: Number(queue.selected ?? queue.stories?.length ?? 0),
    total: Number(queue.total ?? queue.stories?.length ?? 0),
    date: queue.date
  };
}

async function main() {
  if (process.argv.includes("--help")) {
    console.log("Usage: npm run editorial:codex");
    console.log("Runs the no-OpenAI-API-key Codex editorial pass.");
    console.log("Required env: PIPELINE_ADMIN_TOKEN");
    console.log("Optional env: SIGNAL_DAILY_EDITORIAL_LIMIT, SIGNAL_DAILY_EDITORIAL_DATE, CODEX_BIN, CODEX_EDITORIAL_MODEL");
    return;
  }

  const missing = missingEditorialEnvironment();
  if (missing) {
    console.error(missing);
    process.exit(1);
  }

  const cwd = process.cwd();
  const queuePath = process.env.SIGNAL_DAILY_EDITORIAL_QUEUE_PATH ?? "tmp/codex-editorial-queue.json";
  const applyPath = process.env.SIGNAL_DAILY_EDITORIAL_APPLY_PATH ?? "tmp/codex-editorial-apply.json";
  const codexBin = process.env.CODEX_BIN ?? "codex";

  run("npm", ["run", "editorial:queue"], { cwd, env: process.env });

  const queueSummary = await readQueueSummary(resolve(cwd, queuePath));
  if (queueSummary.selected === 0) {
    console.log(`No editorial stories queued for ${queueSummary.date ?? "today"}.`);
    return;
  }

  const prompt = buildCodexEditorialPrompt({ queuePath, applyPath });
  const args = [
    "exec",
    "--cd",
    cwd,
    "--ask-for-approval",
    "never",
    "--sandbox",
    "danger-full-access",
    "--search"
  ];

  if (process.env.CODEX_EDITORIAL_MODEL) {
    args.push("--model", process.env.CODEX_EDITORIAL_MODEL);
  }

  args.push(prompt);
  run(codexBin, args, { cwd, env: process.env });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  });
}
