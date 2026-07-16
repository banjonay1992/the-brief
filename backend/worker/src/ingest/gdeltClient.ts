import type { RawDiscoveredArticle } from "./types";

const GDELT_DOC_URL = "https://api.gdeltproject.org/api/v2/doc/doc";

interface GDELTArticle {
  url?: string;
  title?: string;
  seendate?: string;
  socialimage?: string;
  domain?: string;
  language?: string;
  sourcecountry?: string;
}

interface GDELTResponse {
  articles?: GDELTArticle[];
}

export interface GDELTQuery {
  topic: string;
  query: string;
}

export const HOURLY_DISCOVERY_QUERIES: readonly GDELTQuery[] = [
  {
    topic: "World",
    query: '(ceasefire OR airstrike OR flood OR wildfire OR outbreak OR inflation OR "central bank" OR "artificial intelligence" OR battery OR humanitarian OR refugees OR "civilian casualties") sourcelang:english'
  },
  {
    topic: "Middle East",
    query: '(Gaza OR Israel OR Palestinian OR Lebanon OR Syria OR Iran OR Yemen OR "Red Sea" OR ceasefire OR hostage OR airstrike) sourcelang:english'
  },
  {
    topic: "Africa",
    query: '(Sudan OR Congo OR Nigeria OR Kenya OR Ethiopia OR Ghana OR "South Africa" OR Sahel OR displacement OR outbreak OR election) sourcelang:english'
  },
  {
    topic: "Asia",
    query: '(China OR India OR Pakistan OR Japan OR Philippines OR Taiwan OR Myanmar OR "South China Sea" OR election OR flood OR technology) sourcelang:english'
  },
  {
    topic: "Latin America",
    query: '(Brazil OR Mexico OR Argentina OR Chile OR Colombia OR Peru OR Ecuador OR Venezuela OR migration OR election OR climate) sourcelang:english'
  },
  {
    topic: "Europe",
    query: '(Ukraine OR Russia OR EU OR France OR Germany OR "United Kingdom" OR NATO OR sanctions OR election OR energy) sourcelang:english'
  },
  {
    topic: "Science & Tech",
    query: '("artificial intelligence" OR cybersecurity OR battery OR space OR research OR semiconductor OR climate technology OR health technology) sourcelang:english'
  }
];

export async function fetchHourlyGDELTArticles(fetcher: typeof fetch = fetch): Promise<RawDiscoveredArticle[]> {
  const batches: RawDiscoveredArticle[][] = [];
  for (const query of HOURLY_DISCOVERY_QUERIES) {
    try {
      batches.push(await fetchGDELTQuery(query, fetcher));
    } catch (error) {
      console.warn(JSON.stringify({
        level: "warn",
        event: "gdelt-query-skipped",
        topic: query.topic,
        message: errorMessage(error)
      }));
    }
  }
  return dedupeArticles(batches.flat()).slice(0, 420);
}

async function fetchGDELTQuery(query: GDELTQuery, fetcher: typeof fetch): Promise<RawDiscoveredArticle[]> {
  const url = new URL(GDELT_DOC_URL);
  url.searchParams.set("query", query.query);
  url.searchParams.set("mode", "artlist");
  url.searchParams.set("format", "json");
  url.searchParams.set("maxrecords", "100");
  url.searchParams.set("timespan", "1h");
  url.searchParams.set("sort", "datedesc");

  const response = await fetchWithRetry(url.toString(), fetcher);

  if (!response.ok) {
    throw new Error(`GDELT query failed for ${query.topic}: ${response.status}`);
  }

  const payload = await response.json() as GDELTResponse;
  return (payload.articles ?? [])
    .map((article) => normalizeGDELTArticle(article, query))
    .filter((article): article is RawDiscoveredArticle => article !== null);
}

async function fetchWithRetry(url: string, fetcher: typeof fetch): Promise<Response> {
  const response = await fetchGDELTURL(url, fetcher);
  if (response.status !== 429 && response.status < 500) {
    return response;
  }

  await delay(900);
  return fetchGDELTURL(url, fetcher);
}

function fetchGDELTURL(url: string, fetcher: typeof fetch): Promise<Response> {
  return fetcher(url, {
    headers: {
      accept: "application/json"
    }
  });
}

function normalizeGDELTArticle(article: GDELTArticle, query: GDELTQuery): RawDiscoveredArticle | null {
  if (!article.url || !article.title || !article.domain || !article.seendate) {
    return null;
  }

  return {
    id: articleId(article.url),
    url: article.url,
    title: cleanTitle(article.title),
    domain: article.domain.toLowerCase(),
    language: article.language ?? "Unknown",
    sourceCountry: article.sourcecountry ?? "Unknown",
    seenAt: parseGDELTDate(article.seendate),
    imageUrl: article.socialimage || null,
    topic: inferTopic(article.title, query.topic),
    query: query.query
  };
}

export function inferTopic(title: string, fallback: string): string {
  const normalized = title.toLowerCase();
  if (containsAnyTopicTerm(normalized, ["ceasefire", "airstrike", "attack", "attacks", "armed", "sanction", "sanctions", "military", "war", "hostage", "killed", "death toll", "rocket attack"])) {
    return "Conflict";
  }
  if (containsAnyTopicTerm(normalized, ["flood", "wildfire", "drought", "climate", "storm", "heat"])) {
    return "Climate";
  }
  if (containsAnyTopicTerm(normalized, ["outbreak", "hospital", "vaccine", "health", "disease", "virus"])) {
    return "Health";
  }
  if (containsAnyTopicTerm(normalized, ["inflation", "central bank", "unemployment", "trade", "debt", "market"])) {
    return "Economy";
  }
  if (containsAnyTopicTerm(normalized, ["artificial intelligence", "battery", "space", "research", "cybersecurity", "technology", "semiconductor"])) {
    return "Science & Tech";
  }
  if (containsAnyTopicTerm(normalized, ["aid", "displacement", "refugee", "refugees", "humanitarian", "civilian"])) {
    return "Humanitarian";
  }
  return TOPIC_FALLBACKS.has(fallback) ? fallback : "World";
}

const TOPIC_FALLBACKS = new Set([
  "World",
  "Conflict",
  "Climate",
  "Health",
  "Economy",
  "Science & Tech",
  "Humanitarian"
]);

function containsAnyTopicTerm(value: string, needles: string[]): boolean {
  return needles.some((needle) => {
    if (needle.includes(" ")) {
      return value.includes(needle);
    }
    return new RegExp(`\\b${escapeRegExp(needle)}\\b`, "i").test(value);
  });
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function dedupeArticles(articles: RawDiscoveredArticle[]): RawDiscoveredArticle[] {
  const seen = new Set<string>();
  const deduped: RawDiscoveredArticle[] = [];
  for (const article of articles) {
    const key = article.url.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    deduped.push(article);
  }
  return deduped;
}

export function parseGDELTDate(value: string): string {
  const match = value.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/);
  if (!match) {
    return new Date(0).toISOString();
  }
  const [, year, month, day, hour, minute, second] = match;
  return `${year}-${month}-${day}T${hour}:${minute}:${second}Z`;
}

function cleanTitle(title: string): string {
  return normalizeTitleSpacing(decodeEntities(title));
}

function decodeEntities(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/&#039;/g, "'");
}

function articleId(url: string): string {
  return `raw_${hashString(url)}`;
}

function normalizeTitleSpacing(value: string): string {
  return value
    .replace(/\s+/g, " ")
    .replace(/\s+([,.;:!?])/g, "$1")
    .replace(/([([{])\s+/g, "$1")
    .replace(/\s+([)\]}])/g, "$1")
    .replace(/(\d),\s+(\d{3})/g, "$1,$2")
    .replace(/\bU\s+\.\s*S\s+\./g, "U.S.")
    .replace(/\bU\.\s+S\./g, "U.S.")
    .trim();
}

function hashString(value: string): string {
  let hash = 5381;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) + hash) ^ value.charCodeAt(index);
  }
  return (hash >>> 0).toString(36);
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown error";
}
