#!/usr/bin/env node

import { readFile } from "node:fs/promises";

export const bannedEditorialPatterns = [
  "this may change today's wider context",
  "event context currently points",
  "reporting is currently coming through",
  "the grouping shows overlapping coverage",
  "facts reported by multiple distinct sources",
  "the briefing keeps",
  "this is presented as source reporting",
  "source reporting, with specific figures",
  "\\bthe app\\b",
  "\\bthe card\\b"
];

const bannedPattern = new RegExp(bannedEditorialPatterns.join("|"), "i");

export function validateEditorialPayload(queue, apply) {
  const queuedIDs = new Set((queue.stories ?? []).map((item) => item.summary?.id).filter(Boolean));
  const errors = [];

  if (!apply.date || typeof apply.date !== "string") {
    errors.push("Apply payload needs a string date.");
  }

  if (!Array.isArray(apply.stories) || apply.stories.length === 0) {
    errors.push("Apply payload needs a non-empty stories array.");
  }

  for (const story of apply.stories ?? []) {
    const label = story.id || "<missing id>";
    if (!queuedIDs.has(story.id)) {
      errors.push(`${label}: id is not present in the queue.`);
    }

    for (const field of ["headline", "summary", "whyItMatters", "whatHappened", "confidenceReason"]) {
      if (typeof story[field] !== "string" || story[field].trim().length === 0) {
        errors.push(`${label}: ${field} must be a non-empty string.`);
        continue;
      }
      if (bannedPattern.test(story[field])) {
        errors.push(`${label}: ${field} contains banned template/app wording.`);
      }
    }

    for (const field of ["whatWeKnow", "whatIsUnclear", "biasAuditNotes"]) {
      if (!Array.isArray(story[field]) || story[field].length === 0) {
        errors.push(`${label}: ${field} must be a non-empty array.`);
      }
    }

    if (!story.framingCheck || typeof story.framingCheck !== "object") {
      errors.push(`${label}: framingCheck must be an object.`);
    } else {
      for (const field of ["westernMainstream", "localRegional", "officialGovernment", "affectedPopulation", "independentEvidence"]) {
        const value = story.framingCheck[field];
        if (typeof value !== "string" || value.trim().length === 0) {
          errors.push(`${label}: framingCheck.${field} must be a non-empty string.`);
        }
        if (typeof value === "string" && bannedPattern.test(value)) {
          errors.push(`${label}: framingCheck.${field} contains banned template/app wording.`);
        }
      }
    }
  }

  return errors;
}

async function main() {
  const queuePath = process.env.SIGNAL_DAILY_EDITORIAL_QUEUE_PATH ?? "tmp/codex-editorial-queue.json";
  const applyPath = process.env.SIGNAL_DAILY_EDITORIAL_APPLY_PATH ?? "tmp/codex-editorial-apply.json";

  if (process.argv.includes("--help")) {
    console.log("Usage: npm run editorial:validate");
    console.log("Optional env: SIGNAL_DAILY_EDITORIAL_QUEUE_PATH, SIGNAL_DAILY_EDITORIAL_APPLY_PATH");
    return;
  }

  const queue = JSON.parse(await readFile(queuePath, "utf8"));
  const apply = JSON.parse(await readFile(applyPath, "utf8"));
  const errors = validateEditorialPayload(queue, apply);

  if (errors.length > 0) {
    console.error(errors.join("\n"));
    process.exit(1);
  }

  console.log(`Validated ${apply.stories.length} editorial patches for ${apply.date}.`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  });
}
