import type { BriefingDocument, StoryDetailDocument } from "./briefingBuilder";
import type { SourceRecord } from "./types";

export interface BriefingArtifacts {
  briefing: BriefingDocument;
  details: StoryDetailDocument[];
}

interface OpenAISynthesisOptions {
  apiKey?: string;
  model?: string;
  fetcher?: typeof fetch;
  batchSize?: number;
  storyLimit?: number;
  retryDelayMs?: number;
}

interface StoryPatch {
  id: string;
  headline: string;
  summary: string;
  whyItMatters: string;
  whatHappened: string;
  whatWeKnow: string[];
  whatIsUnclear: string[];
  confidenceReason: string;
  framingCheck: StoryDetailDocument["framingCheck"];
  additionalSources: Array<{
    name: string;
    type: string;
    region: string;
    url: string;
    framing: string;
  }>;
  sortPriority: number;
}

interface SynthesisResponse {
  stories: StoryPatch[];
}

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_OPENAI_MODEL = "gpt-5.4-nano";
const DEFAULT_STORY_LIMIT = 40;
const DEFAULT_BATCH_SIZE = 4;
const DEFAULT_RETRY_DELAY_MS = 30_000;

export async function enhanceBriefingWithOpenAI(
  artifacts: BriefingArtifacts,
  options: OpenAISynthesisOptions = {}
): Promise<BriefingArtifacts> {
  if (!options.apiKey) {
    return artifacts;
  }

  try {
    const synthesisArtifacts = limitedArtifactsForSynthesis(artifacts, options.storyLimit ?? DEFAULT_STORY_LIMIT);
    const responses: SynthesisResponse[] = [];
    let sortOffset = 0;
    for (const batch of batchesFor(synthesisArtifacts, options.batchSize ?? DEFAULT_BATCH_SIZE)) {
      try {
        const response = await requestSynthesis(batch, {
          apiKey: options.apiKey,
          model: options.model ?? DEFAULT_OPENAI_MODEL,
          fetcher: options.fetcher ?? workerFetch,
          batchSize: options.batchSize ?? DEFAULT_BATCH_SIZE,
          storyLimit: options.storyLimit ?? DEFAULT_STORY_LIMIT,
          retryDelayMs: options.retryDelayMs ?? DEFAULT_RETRY_DELAY_MS
        }, 1);
        responses.push({
          stories: response.stories.map((story) => ({
            ...story,
            sortPriority: story.sortPriority + sortOffset
          }))
        });
      } catch (error) {
        console.warn(JSON.stringify({
          level: "warn",
          event: "openai-synthesis-batch-skipped",
          message: errorMessage(error)
        }));
      }
      sortOffset += batch.briefing.storyCount;
    }
    return applySynthesis(artifacts, {
      stories: responses.flatMap((response) => response.stories)
    });
  } catch (error) {
    console.warn(JSON.stringify({
      level: "warn",
      event: "openai-synthesis-skipped",
      message: errorMessage(error)
    }));
    return artifacts;
  }
}

const workerFetch: typeof fetch = (input, init) => fetch(input, init);

function batchesFor(artifacts: BriefingArtifacts, batchSize: number): BriefingArtifacts[] {
  const stories = artifacts.briefing.sections.flatMap((section) => section.stories);
  if (stories.length <= batchSize) {
    return [artifacts];
  }

  const detailsByID = new Map(artifacts.details.map((detail) => [detail.id, detail]));
  const batches: BriefingArtifacts[] = [];
  for (let index = 0; index < stories.length; index += batchSize) {
    const batchStories = stories.slice(index, index + batchSize);
    const ids = new Set(batchStories.map((story) => story.id));
    batches.push({
      briefing: {
        ...artifacts.briefing,
        storyCount: batchStories.length,
        sections: artifacts.briefing.sections
          .map((section) => ({
            ...section,
            stories: section.stories.filter((story) => ids.has(story.id))
          }))
          .filter((section) => section.stories.length > 0)
      },
      details: batchStories.flatMap((story) => {
        const detail = detailsByID.get(story.id);
        return detail ? [detail] : [];
      })
    });
  }
  return batches;
}

function limitedArtifactsForSynthesis(artifacts: BriefingArtifacts, storyLimit: number): BriefingArtifacts {
  const stories = artifacts.briefing.sections.flatMap((section) => section.stories).slice(0, storyLimit);
  const ids = new Set(stories.map((story) => story.id));
  const detailsByID = new Map(artifacts.details.map((detail) => [detail.id, detail]));
  return {
    briefing: {
      ...artifacts.briefing,
      storyCount: stories.length,
      sections: artifacts.briefing.sections
        .map((section) => ({
          ...section,
          stories: section.stories.filter((story) => ids.has(story.id))
        }))
        .filter((section) => section.stories.length > 0)
    },
    details: stories.flatMap((story) => {
      const detail = detailsByID.get(story.id);
      return detail ? [detail] : [];
    })
  };
}

async function requestSynthesis(
  artifacts: BriefingArtifacts,
  options: Required<OpenAISynthesisOptions>,
  retriesRemaining: number
): Promise<SynthesisResponse> {
  const response = await options.fetcher(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      authorization: `Bearer ${options.apiKey}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: options.model,
      reasoning: { effort: "medium" },
      max_output_tokens: 20000,
      tools: [
        {
          type: "web_search"
        }
      ],
      tool_choice: "auto",
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text: synthesisSystemPrompt()
            }
          ]
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify(synthesisInputFor(artifacts))
            }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "signal_daily_briefing_synthesis",
          strict: true,
          schema: synthesisSchema()
        }
      }
    })
  });

  if (!response.ok) {
    if ((response.status === 429 || response.status >= 500) && retriesRemaining > 0) {
      await delay(retryDelayFor(response, options.retryDelayMs));
      return requestSynthesis(artifacts, options, retriesRemaining - 1);
    }
    throw new Error(`OpenAI synthesis failed: ${response.status}`);
  }

  const body = await response.json() as unknown;
  const text = outputTextFromResponse(body);
  const parsed = JSON.parse(text) as SynthesisResponse;
  if (!Array.isArray(parsed.stories)) {
    throw new Error("OpenAI synthesis response did not include stories.");
  }
  return parsed;
}

function retryDelayFor(response: Response, fallbackMilliseconds: number): number {
  const retryAfter = response.headers.get("retry-after");
  const retryAfterSeconds = retryAfter ? Number(retryAfter) : Number.NaN;
  if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0) {
    return Math.min(retryAfterSeconds * 1000, 120_000);
  }
  return fallbackMilliseconds;
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

function applySynthesis(artifacts: BriefingArtifacts, response: SynthesisResponse): BriefingArtifacts {
  const patches = new Map(response.stories.map((story) => [story.id, sanitizePatch(story)]));
  const details = artifacts.details.map((detail) => {
    const patch = patches.get(detail.id);
    if (!patch) {
      return detail;
    }
    const sources = mergeSources(detail.sources, patch.additionalSources);
    return {
      ...detail,
      headline: patch.headline,
      whatHappened: patch.whatHappened,
      whyItMatters: patch.whyItMatters,
      whatWeKnow: patch.whatWeKnow,
      whatIsUnclear: patch.whatIsUnclear,
      framingCheck: patch.framingCheck,
      confidence: {
        ...detail.confidence,
        reason: patch.confidenceReason
      },
      sources,
      evidenceCheck: {
        ...detail.evidenceCheck,
        claim: patch.headline,
        why: evidenceCheckReasonForSources(sources)
      }
    };
  });
  const sourceCountByStoryID = new Map(details.map((detail) => [detail.id, detail.sources.length]));

  const briefing = {
    ...artifacts.briefing,
    sections: artifacts.briefing.sections.map((section) => ({
      ...section,
      stories: section.stories
        .map((story) => {
          const patch = patches.get(story.id);
          if (!patch) {
            return story;
          }
          return {
            ...story,
            headline: patch.headline,
            summary: patch.summary,
            whyItMatters: patch.whyItMatters,
            sourceCount: sourceCountByStoryID.get(story.id) ?? story.sourceCount
          };
        })
        .sort((left, right) => sortPriorityFor(left.id, patches) - sortPriorityFor(right.id, patches))
    }))
  };

  return { briefing, details };
}

function evidenceCheckReasonForSources(sources: SourceRecord[]): string {
  if (sources.length >= 3) {
    return `${sources.length} distinct sources report the same broad story, so the event is treated as corroborated reporting while figures, responsibility claims, motives, and official statements stay attributed.`;
  }
  if (sources.length === 2) {
    return "Two distinct sources report the same broad story, giving early corroboration while details still need attribution and further checking.";
  }
  const sourceType = sources[0]?.type ?? "source";
  return `This currently rests on one ${sourceType} source, so it is treated as plausible reporting until another independent source, primary document, or local report corroborates it.`;
}

function sortPriorityFor(id: string, patches: Map<string, StoryPatch>): number {
  return patches.get(id)?.sortPriority ?? 999;
}

function synthesisInputFor(artifacts: BriefingArtifacts): unknown {
  const detailsByID = new Map(artifacts.details.map((detail) => [detail.id, detail]));
  return {
    instruction: "Rewrite and sort these already-clustered briefing cards. Use web search to understand the actual reported event behind each card, not just the headline. Preserve IDs, ratings, regions, and categories. Source counts may increase only when additionalSources contains distinct real URLs.",
    stories: artifacts.briefing.sections.flatMap((section) => section.stories.map((story) => {
      const detail = detailsByID.get(story.id);
      return {
        id: story.id,
        section: section.title,
        headline: story.headline,
        region: story.region,
        category: story.category,
        sourceCount: story.sourceCount,
        confidence: story.confidence,
        emotionalLoad: story.emotionalLoad,
        summary: story.summary,
        whyItMatters: story.whyItMatters,
        whatHappened: detail?.whatHappened,
        whatWeKnow: detail?.whatWeKnow,
        whatIsUnclear: detail?.whatIsUnclear,
        confidenceReason: detail?.confidence.reason,
        articleEvidence: articleEvidenceForDetail(detail),
        sources: detail?.sources.map((source) => ({
          name: source.name,
          type: source.type,
          region: source.region,
          url: source.url,
          framing: source.framing
        })) ?? []
      };
    }))
  };
}

function articleEvidenceForDetail(detail: StoryDetailDocument | undefined): Array<{
  sourceName: string;
  title: string;
  url: string;
  excerpt: string | null;
  sourceCountry: string;
}> {
  return detail?.sourceEvidence ?? detail?.sources.map((source) => ({
    sourceName: source.name,
    title: detail.headline,
    url: source.url,
    excerpt: null,
    sourceCountry: source.region
  })) ?? [];
}

function synthesisSystemPrompt(): string {
  return [
    "You are the Signal Daily briefing editor.",
    "Create calm, evidence-weighted briefing copy from clustered source reports.",
    "Use the provided articleEvidence first, then web search to understand the actual reported event behind each card.",
    "Use web search to add context, primary sources, local/regional reporting, affected-population sources, NGO/human-rights sources, and opposing-side framing where useful.",
    "Do not add factual claims unless they are supported by provided sources or web-search results.",
    "Separate confirmed reporting from claims. Attribute official or actor claims.",
    "Apply the same evidence standards to Western, non-Western, allied, adversarial, state, and non-state actors.",
    "Avoid loaded terms as neutral fact, including terrorist, regime, defensive operation, precision strike, human shield, and unprovoked attack.",
    "Do not soften civilian harm by one actor or exaggerate it by another.",
    "Return calm app-ready copy with enough substance for a paid news briefing.",
    "For summary, write 2-3 concise story-specific sentences that explain the actual development, place, actor or institution, and known consequence.",
    "For whatHappened, write 3-4 calm sentences with enough detail for an article popup: what changed, who reported or claimed it, where it happened, and what is still attributed.",
    "For whyItMatters, write 2-3 story-specific sentences naming the affected place, people, institutions, markets, risks, or policy consequences where supported.",
    "Do not leave generic category copy such as 'health developments can affect public guidance' or 'this may change today's wider context' unless the story genuinely lacks more detail.",
    "Never refer to Signal Daily, the app, the briefing, the briefing card, the card, or the popup in user-facing fields. Write directly about the event and evidence.",
    "Do not start confidenceReason with labels such as 'Confidence:', 'Confidence is', or the rating name. Write the reason only.",
    "Every prose field must end as a complete sentence with normal punctuation.",
    "Do not merely repeat the headline. If the source is a market/index/business item, explain the concrete market, company, investor, supply-chain, or policy implication.",
    "Do not include markdown links, inline citations, bracketed citations, or raw URLs in headline, summary, whyItMatters, whatHappened, list items, confidenceReason, or framing text. Put URLs only in additionalSources.",
    "Headlines should be under 90 characters. List items should be short.",
    "Add at most three additionalSources per story, only for distinct real URLs you consulted or can cite from web search.",
    "Use additionalSources to improve framing and source transparency, not to pad the source count.",
    "Preserve every story id exactly. Preserve confidence ratings; rewrite text fields, update framing, add sources where justified, and assign sortPriority."
  ].join(" ");
}

function synthesisSchema(): unknown {
  const framingProperties = {
    westernMainstream: { type: "string" },
    localRegional: { type: "string" },
    officialGovernment: { type: "string" },
    affectedPopulation: { type: "string" },
    independentEvidence: { type: "string" },
    humanRightsNGO: { type: ["string", "null"] },
    opposingSide: { type: ["string", "null"] }
  };
  return {
    type: "object",
    additionalProperties: false,
    required: ["stories"],
    properties: {
      stories: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "id",
            "headline",
            "summary",
            "whyItMatters",
            "whatHappened",
            "whatWeKnow",
            "whatIsUnclear",
            "confidenceReason",
            "framingCheck",
            "additionalSources",
            "sortPriority"
          ],
          properties: {
            id: { type: "string" },
            headline: { type: "string", maxLength: 100 },
            summary: { type: "string", minLength: 140, maxLength: 620 },
            whyItMatters: { type: "string", minLength: 140, maxLength: 620 },
            whatHappened: { type: "string", minLength: 220, maxLength: 1100 },
            whatWeKnow: {
              type: "array",
              minItems: 2,
              maxItems: 5,
              items: { type: "string", maxLength: 180 }
            },
            whatIsUnclear: {
              type: "array",
              minItems: 2,
              maxItems: 5,
              items: { type: "string", maxLength: 180 }
            },
            confidenceReason: { type: "string", maxLength: 260 },
            framingCheck: {
              type: "object",
              additionalProperties: false,
              required: [
                "westernMainstream",
                "localRegional",
                "officialGovernment",
                "affectedPopulation",
                "independentEvidence",
                "humanRightsNGO",
                "opposingSide"
              ],
              properties: framingProperties
            },
            additionalSources: {
              type: "array",
              maxItems: 3,
              items: {
                type: "object",
                additionalProperties: false,
                required: ["name", "type", "region", "url", "framing"],
                properties: {
                  name: { type: "string", maxLength: 100 },
                  type: { type: "string", enum: ["wire", "local/regional", "official", "primary", "NGO", "analysis", "commentary", "other"] },
                  region: { type: "string", maxLength: 80 },
                  url: { type: "string", maxLength: 500 },
                  framing: { type: "string", maxLength: 260 }
                }
              }
            },
            sortPriority: { type: "integer", minimum: 1 }
          }
        }
      }
    }
  };
}

function sanitizePatch(patch: StoryPatch): StoryPatch {
  return {
    ...patch,
    headline: cleanAppCopy(patch.headline),
    summary: cleanAppCopy(patch.summary),
    whyItMatters: cleanAppCopy(patch.whyItMatters),
    whatHappened: cleanAppCopy(patch.whatHappened),
    whatWeKnow: patch.whatWeKnow.map(cleanAppCopy),
    whatIsUnclear: patch.whatIsUnclear.map(cleanAppCopy),
    confidenceReason: stripConfidencePrefix(cleanAppCopy(patch.confidenceReason)),
    framingCheck: {
      westernMainstream: cleanAppCopy(patch.framingCheck.westernMainstream),
      localRegional: cleanAppCopy(patch.framingCheck.localRegional),
      officialGovernment: cleanAppCopy(patch.framingCheck.officialGovernment),
      affectedPopulation: cleanAppCopy(patch.framingCheck.affectedPopulation),
      independentEvidence: cleanAppCopy(patch.framingCheck.independentEvidence),
      humanRightsNGO: patch.framingCheck.humanRightsNGO ? cleanAppCopy(patch.framingCheck.humanRightsNGO) : null,
      opposingSide: patch.framingCheck.opposingSide ? cleanAppCopy(patch.framingCheck.opposingSide) : null
    },
    additionalSources: patch.additionalSources.map((source) => ({
      ...source,
      name: cleanAppCopy(source.name),
      region: cleanAppCopy(source.region),
      framing: cleanAppCopy(source.framing)
    }))
  };
}

function cleanAppCopy(value: string): string {
  return stripInlineCitations(value)
    .replace(/\b[Tt]he card\b/g, "The source item")
    .replace(/\b[Tt]his card\b/g, "This source item")
    .replace(/\b[Tt]he briefing card\b/g, "The source item")
    .replace(/\b[Tt]he briefing\b/g, "The reporting")
    .replace(/\b[Tt]his briefing\b/g, "This reporting")
    .replace(/\b[Tt]he app\b/g, "The evidence review")
    .replace(/\b[Tt]his app\b/g, "This evidence review")
    .trim();
}

function stripInlineCitations(value: string): string {
  return value
    .replace(/\s*\(\[[^\]]+\]\(https?:\/\/[^)]+\)\)/g, "")
    .replace(/\s*\[[0-9,\s]+\]/g, "")
    .replace(/\s+([.,;:])/g, "$1")
    .replace(/\s{2,}/g, " ")
    .replace(/[,;:]\s*$/g, ".")
    .trim();
}

function stripConfidencePrefix(value: string): string {
  return value
    .replace(/^confidence\s*(?:is|:)?\s*(?:high|medium-high|medium|low|unverified|disputed)?\s*[.:,-]\s*/i, "")
    .replace(/^(?:high|medium-high|medium|low|unverified|disputed)\s+confidence\s*[:.-]\s*/i, "")
    .trim();
}

function mergeSources(existing: SourceRecord[], additional: StoryPatch["additionalSources"]): SourceRecord[] {
  const sources = new Map(existing.map((source) => [normalizeURL(source.url), source]));
  for (const source of additional) {
    const url = normalizeURL(source.url);
    if (!url || sources.has(url)) {
      continue;
    }
    sources.set(url, {
      id: `source_ai_${hashString(url)}`,
      name: source.name,
      type: source.type,
      region: source.region,
      url,
      publishedAt: new Date().toISOString(),
      framing: source.framing,
      ...qualityForAdditionalSource(source.type)
    });
  }
  return [...sources.values()].slice(0, 10);
}

function qualityForAdditionalSource(type: string): { qualityScore: number; qualityLabel: string } {
  switch (type) {
    case "wire":
      return { qualityScore: 90, qualityLabel: "High contribution" };
    case "primary":
      return { qualityScore: 88, qualityLabel: "Primary evidence" };
    case "NGO":
      return { qualityScore: 82, qualityLabel: "Specialist context" };
    case "official":
      return { qualityScore: 74, qualityLabel: "Official claim source" };
    case "commentary":
      return { qualityScore: 35, qualityLabel: "Commentary only" };
    default:
      return { qualityScore: 62, qualityLabel: "Useful context" };
  }
}

function normalizeURL(value: string): string {
  try {
    const url = new URL(value);
    url.hash = "";
    return url.toString();
  } catch {
    return "";
  }
}

function hashString(value: string): string {
  let hash = 5381;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) + hash) ^ value.charCodeAt(index);
  }
  return (hash >>> 0).toString(36);
}

function outputTextFromResponse(body: unknown): string {
  if (typeof body === "object" && body && "output_text" in body && typeof body.output_text === "string") {
    return body.output_text;
  }
  const output = (body as { output?: Array<{ content?: Array<{ type?: string; text?: string }> }> }).output ?? [];
  for (const item of output) {
    for (const content of item.content ?? []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }
  throw new Error("OpenAI response did not contain output text.");
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown error";
}
