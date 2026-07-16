import { describe, expect, it } from "vitest";
import { validateEditorialPayload } from "../scripts/validate-codex-editorial-payload.mjs";
import { buildCodexEditorialPrompt, missingEditorialEnvironment } from "../scripts/run-codex-editorial-pass.mjs";

const queue = {
  date: "2026-05-20",
  stories: [{
    summary: {
      id: "story_one"
    }
  }]
};

const validPatch = {
  date: "2026-05-20",
  stories: [{
    id: "story_one",
    headline: "Health teams expand monitoring after outbreak reports",
    summary: "Health officials and local clinics reported expanded monitoring after outbreak-risk reports in eastern DR Congo.",
    whyItMatters: "Monitoring decisions can affect treatment capacity, public guidance, and support for communities already facing displacement.",
    whatHappened: "Local health teams reported expanded monitoring after outbreak-risk reports. Current evidence supports that monitoring increased, while case totals and transmission details remain attributed to officials.",
    whatWeKnow: ["Monitoring was reported by health sources.", "The reports concern DR Congo."],
    whatIsUnclear: ["Case totals remain attributed.", "The source set is still limited."],
    confidenceReason: "The broad event is supported by the provided source evidence, but detailed figures remain attributed.",
    framingCheck: {
      westernMainstream: "May frame the story through regional health-security risks.",
      localRegional: "May focus on clinic capacity and community disruption.",
      officialGovernment: "Officials frame monitoring as a public-health response.",
      affectedPopulation: "Affected residents may focus on access to care and movement disruption.",
      independentEvidence: "The available evidence supports monitoring reports, not all detailed figures.",
      humanRightsNGO: null,
      opposingSide: null
    },
    biasAuditNotes: ["Claims are attributed.", "Uncertainty is stated clearly."]
  }]
};

describe("Codex editorial helper scripts", () => {
  it("accepts a complete calm editorial payload", () => {
    expect(validateEditorialPayload(queue, validPatch)).toEqual([]);
  });

  it("rejects generic fallback wording before apply", () => {
    const patch = structuredClone(validPatch);
    patch.stories[0].summary = "This may change today's wider context in Health.";

    expect(validateEditorialPayload(queue, patch)).toContain("story_one: summary contains banned template/app wording.");
  });

  it("requires patches to preserve queued story ids", () => {
    const patch = structuredClone(validPatch);
    patch.stories[0].id = "story_two";

    expect(validateEditorialPayload(queue, patch)).toContain("story_two: id is not present in the queue.");
  });

  it("does not require an OpenAI API key for the Codex editorial runner", () => {
    expect(missingEditorialEnvironment({ PIPELINE_ADMIN_TOKEN: "present" })).toBeNull();
    expect(missingEditorialEnvironment({ OPENAI_API_KEY: "not-enough" })).toContain("PIPELINE_ADMIN_TOKEN");
  });

  it("builds a prompt that forbids OpenAI API synthesis", () => {
    const prompt = buildCodexEditorialPrompt();

    expect(prompt).toContain("Do not call the OpenAI API");
    expect(prompt).toContain("Do not use OPENAI_API_KEY");
    expect(prompt).toContain("Do not enable Worker OpenAI synthesis");
    expect(prompt).toContain("npm run editorial:validate");
    expect(prompt).toContain("npm run editorial:apply");
  });
});
