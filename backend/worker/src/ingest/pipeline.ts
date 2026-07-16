import { fetchHourlyGDELTArticles } from "./gdeltClient";
import { fetchReliefWebReports } from "./reliefWebClient";
import { fetchCuratedRSSArticles } from "./rssClient";
import { buildBriefingDocument, buildStoryDetailsFromArticles } from "./briefingBuilder";
import { enhanceBriefingWithOpenAI } from "./openAISynthesizer";
import { buildRawSnapshot, buildSourceRecords, buildUpdatesDocument } from "./updateBuilder";
import type { BriefingDocument, BriefingSection, BriefingStorySummary } from "./briefingBuilder";
import type { BriefingUpdatesDocument, RawDiscoveredArticle, RawDiscoverySnapshot, SourceRecord } from "./types";

export interface PipelineResult {
  date: string;
  generatedAt: string;
  articleCount: number;
  newStoryCount: number;
  minimumNewStoriesTarget: number;
  meetsMinimumNewStoriesTarget: boolean;
  updateCount: number;
  sourceCount: number;
  rawKey: string;
  updatesKey: string;
}

export async function runHourlyNewsPipeline(
  env: Env,
  generatedAt: Date,
  fetcher: typeof fetch = workerFetch
): Promise<PipelineResult> {
  const gdeltArticles = await fetchHourlyGDELTArticles(fetcher);
  const rssArticles = await fetchCuratedRSSArticles(fetcher);
  const reliefWebArticles = await fetchOptionalReliefWebReports(env, fetcher);
  const articles = filterArticlesForDate(
    mergeArticles(gdeltArticles, rssArticles, reliefWebArticles),
    generatedAt
  );
  const rawSnapshot = buildRawSnapshot(
    articles,
    generatedAt,
    providerFor({ gdelt: gdeltArticles.length, rss: rssArticles.length, reliefWeb: reliefWebArticles.length })
  );
  const updates = buildUpdatesDocument(articles, generatedAt);
  const sources = buildSourceRecords(articles);
  const existingBriefing = await readR2JSON<BriefingDocument>(env, briefingKey(rawSnapshot.date));
  const briefingArtifacts = await buildDailyBriefingArtifacts(env, articles, generatedAt, fetcher, existingBriefing);
  const newStoryCount = countNewStories(existingBriefing, briefingArtifacts.briefing);
  const minimumNewStoriesTarget = minimumNewStoriesTargetForEnv(env);

  await writePipelineObjects(env, rawSnapshot, updates, sources, briefingArtifacts, {
    newStoryCount,
    minimumNewStoriesTarget,
    meetsMinimumNewStoriesTarget: newStoryCount >= minimumNewStoriesTarget
  });

  return {
    date: rawSnapshot.date,
    generatedAt: rawSnapshot.generatedAt,
    articleCount: rawSnapshot.articleCount,
    newStoryCount,
    minimumNewStoriesTarget,
    meetsMinimumNewStoriesTarget: newStoryCount >= minimumNewStoriesTarget,
    updateCount: updates.updates.length,
    sourceCount: sources.length,
    rawKey: rawSnapshotKey(rawSnapshot.date, generatedAt),
    updatesKey: updatesKey(rawSnapshot.date)
  };
}

const workerFetch: typeof fetch = (input, init) => fetch(input, init);

async function buildDailyBriefingArtifacts(
  env: Env,
  articles: RawDiscoveredArticle[],
  generatedAt: Date,
  fetcher: typeof fetch,
  existingBriefing: BriefingDocument | null
) {
  const briefing = buildBriefingDocument(articles, generatedAt, maxStoriesForEnv(env));
  const details = buildStoryDetailsFromArticles(articles, maxStoriesForEnv(env), generatedAt);
  const enhanced = await enhanceBriefingWithOpenAI({ briefing, details }, {
    apiKey: openAISynthesisEnabled(env) ? openAIAPIKey(env) : undefined,
    model: openAIModel(env),
    fetcher,
    batchSize: openAIBatchSize(env),
    storyLimit: openAIStoryLimit(env)
  });
  return {
    briefing: mergeWithExistingBriefing(existingBriefing, enhanced.briefing, maxStoriesForEnv(env)),
    details: enhanced.details
  };
}

async function fetchOptionalReliefWebReports(env: Env, fetcher: typeof fetch): Promise<RawDiscoveredArticle[]> {
  try {
    return await fetchReliefWebReports(reliefWebAppName(env), fetcher);
  } catch (error) {
    console.warn(JSON.stringify({
      level: "warn",
      event: "reliefweb-skipped",
      message: errorMessage(error)
    }));
    return [];
  }
}

function mergeArticles(...batches: RawDiscoveredArticle[][]): RawDiscoveredArticle[] {
  const byUrl = new Map<string, RawDiscoveredArticle>();
  for (const article of batches.flat()) {
    byUrl.set(article.url.toLowerCase(), article);
  }
  return [...byUrl.values()].slice(0, 600);
}

function filterArticlesForDate(articles: RawDiscoveredArticle[], generatedAt: Date): RawDiscoveredArticle[] {
  const date = generatedAt.toISOString().slice(0, 10);
  return articles.filter((article) => article.seenAt.startsWith(date));
}

function providerFor(counts: { gdelt: number; rss: number; reliefWeb: number }): RawDiscoverySnapshot["provider"] {
  const providers: string[] = [];
  if (counts.gdelt > 0) {
    providers.push("gdelt-doc");
  }
  if (counts.rss > 0) {
    providers.push("curated-rss");
  }
  if (counts.reliefWeb > 0) {
    providers.push("reliefweb");
  }
  return providers.join("+") || "gdelt-doc";
}

function reliefWebAppName(env: Env): string | undefined {
  return (env as Env & { RELIEFWEB_APP_NAME?: string }).RELIEFWEB_APP_NAME;
}

function openAIAPIKey(env: Env): string | undefined {
  return (env as Env & { OPENAI_API_KEY?: string }).OPENAI_API_KEY;
}

function openAISynthesisEnabled(env: Env): boolean {
  const value = (env as Env & { OPENAI_SYNTHESIS_ENABLED?: string }).OPENAI_SYNTHESIS_ENABLED ?? "NO";
  return ["1", "true", "yes"].includes(value.trim().toLowerCase());
}

function openAIModel(env: Env): string | undefined {
  return (env as Env & { OPENAI_MODEL?: string }).OPENAI_MODEL ?? "gpt-5.4-nano";
}

function maxStoriesForEnv(env: Env): number {
  const value = Number((env as Env & { MAX_DAILY_STORIES?: string }).MAX_DAILY_STORIES ?? "120");
  return Number.isFinite(value) && value > 0 ? value : 120;
}

function openAIBatchSize(env: Env): number {
  const value = Number((env as Env & { OPENAI_SYNTHESIS_BATCH_SIZE?: string }).OPENAI_SYNTHESIS_BATCH_SIZE ?? "4");
  return Number.isFinite(value) && value > 0 ? value : 4;
}

function openAIStoryLimit(env: Env): number {
  const value = Number((env as Env & { OPENAI_SYNTHESIS_STORY_LIMIT?: string }).OPENAI_SYNTHESIS_STORY_LIMIT ?? "120");
  return Number.isFinite(value) && value > 0 ? value : 120;
}

function minimumNewStoriesTargetForEnv(env: Env): number {
  const value = Number((env as Env & { MIN_HOURLY_NEW_STORIES?: string }).MIN_HOURLY_NEW_STORIES ?? "5");
  return Number.isFinite(value) && value >= 0 ? value : 5;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown error";
}

async function writePipelineObjects(
  env: Env,
  rawSnapshot: RawDiscoverySnapshot,
  updates: BriefingUpdatesDocument,
  sources: SourceRecord[],
  briefingArtifacts: Awaited<ReturnType<typeof buildDailyBriefingArtifacts>>,
  storyFreshness: Pick<PipelineResult, "newStoryCount" | "minimumNewStoriesTarget" | "meetsMinimumNewStoriesTarget">
): Promise<void> {
  const rawKey = rawSnapshotKey(rawSnapshot.date, new Date(rawSnapshot.generatedAt));

  await Promise.all([
    putJSON(env, rawKey, rawSnapshot, "public, max-age=300"),
    putJSON(env, briefingKey(rawSnapshot.date), briefingArtifacts.briefing, "public, max-age=300"),
    putJSON(env, updatesKey(rawSnapshot.date), updates, "public, max-age=300"),
    putJSON(env, latestStatusKey(), {
      date: rawSnapshot.date,
      generatedAt: rawSnapshot.generatedAt,
      provider: rawSnapshot.provider,
      articleCount: rawSnapshot.articleCount,
      ...storyFreshness,
      updateCount: updates.updates.length,
      sourceCount: sources.length,
      rawKey,
      updatesKey: updatesKey(rawSnapshot.date),
      briefingKey: briefingKey(rawSnapshot.date)
    }, "public, max-age=60"),
    ...briefingArtifacts.details.map((detail) => putJSON(env, `articles/${detail.id}.json`, detail, "public, max-age=300")),
    ...sources.map((source) => putJSON(env, `sources/${source.id}.json`, source, "public, max-age=3600"))
  ]);
}

async function putJSON(env: Env, key: string, value: unknown, cacheControl: string): Promise<void> {
  await env.SIGNAL_DAILY_R2.put(key, JSON.stringify(value, null, 2), {
    httpMetadata: {
      contentType: "application/json; charset=utf-8",
      cacheControl
    }
  });
}

async function readR2JSON<T>(env: Env, key: string): Promise<T | null> {
  const object = await env.SIGNAL_DAILY_R2.get(key);
  if (!object) {
    return null;
  }
  return await object.json<T>();
}

function countNewStories(existing: BriefingDocument | null, merged: BriefingDocument): number {
  const existingIDs = new Set(existing?.sections.flatMap((section) => section.stories.map((story) => story.id)) ?? []);
  return merged.sections
    .flatMap((section) => section.stories)
    .filter((story) => !existingIDs.has(story.id))
    .length;
}

function mergeWithExistingBriefing(
  existing: BriefingDocument | null,
  incoming: BriefingDocument,
  maxStories: number
): BriefingDocument {
  if (!existing) {
    return incoming;
  }

  const byID = new Map<string, BriefingStorySummary>();
  for (const story of incoming.sections.flatMap((section) => section.stories)) {
    byID.set(story.id, story);
  }
  for (const story of existing.sections.flatMap((section) => section.stories)) {
    if (!byID.has(story.id)) {
      byID.set(story.id, story);
    }
  }

  const stories = [...byID.values()]
    .sort((left, right) => {
      const timeDelta = (right.publishedAt ?? "").localeCompare(left.publishedAt ?? "");
      if (timeDelta !== 0) {
        return timeDelta;
      }
      return (left.rank ?? 9999) - (right.rank ?? 9999);
    })
    .slice(0, maxStories)
    .map((story, index) => ({ ...story, rank: index + 1 }));

  return {
    ...incoming,
    readingTimeMinutes: Math.max(4, Math.ceil(stories.length * 0.5)),
    storyCount: stories.length,
    sections: groupBriefingStories(stories)
  };
}

function groupBriefingStories(stories: BriefingStorySummary[]): BriefingSection[] {
  const byTitle = new Map<string, BriefingStorySummary[]>();
  const order: string[] = [];
  for (const story of stories) {
    const title = sectionTitleForStory(story);
    if (!byTitle.has(title)) {
      order.push(title);
    }
    byTitle.set(title, [...(byTitle.get(title) ?? []), story]);
  }

  return order.map((title) => ({
    id: slugify(title),
    title,
    stories: byTitle.get(title) ?? []
  }));
}

function sectionTitleForStory(story: BriefingStorySummary): string {
  if (["Health", "Economy", "Science & Tech", "Climate", "Humanitarian"].includes(story.category)) {
    return story.category;
  }
  return story.region || "World";
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "world";
}

function rawSnapshotKey(date: string, generatedAt: Date): string {
  const hour = generatedAt.toISOString().slice(11, 13);
  return `raw/${date}/gdelt/${hour}.json`;
}

function updatesKey(date: string): string {
  return `briefings/${date}/updates.json`;
}

function briefingKey(date: string): string {
  return `briefings/${date}/global.json`;
}

function latestStatusKey(): string {
  return "pipeline/latest.json";
}
