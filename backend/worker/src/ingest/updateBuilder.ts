import { sourceMixForArticles, sourceRecordForArticle, sourceTypeForDomain } from "./sourceRegistry";
import type {
  BriefingUpdateRecord,
  BriefingUpdatesDocument,
  ConfidenceRating,
  EmotionalLoad,
  RawDiscoveredArticle,
  RawDiscoverySnapshot,
  SourceRecord
} from "./types";

interface Cluster {
  key: string;
  articles: RawDiscoveredArticle[];
}

export function buildRawSnapshot(
  articles: RawDiscoveredArticle[],
  generatedAt: Date,
  provider: RawDiscoverySnapshot["provider"] = "gdelt-doc"
): RawDiscoverySnapshot {
  return {
    date: dateKey(generatedAt),
    generatedAt: generatedAt.toISOString(),
    provider,
    window: "1h",
    queryCount: new Set(articles.map((article) => article.query)).size,
    articleCount: articles.length,
    articles
  };
}

export function buildUpdatesDocument(
  articles: RawDiscoveredArticle[],
  generatedAt: Date
): BriefingUpdatesDocument {
  const clusters = clusterArticles(articles);
  const updates = clusters
    .map((cluster) => updateFromCluster(cluster))
    .sort((left, right) => right.sourceCount - left.sourceCount)
    .slice(0, 5);

  return {
    date: dateKey(generatedAt),
    generatedAt: generatedAt.toISOString(),
    status: updates.length > 0 ? "meaningful-updates" : "no-major-updates",
    summary: summaryForUpdates(updates),
    updates
  };
}

export function buildSourceRecords(articles: RawDiscoveredArticle[]): SourceRecord[] {
  const byId = new Map<string, SourceRecord>();
  for (const article of articles) {
    const source = sourceRecordForArticle(article);
    byId.set(source.id, source);
  }
  return [...byId.values()].sort((left, right) => left.id.localeCompare(right.id));
}

function clusterArticles(articles: RawDiscoveredArticle[]): Cluster[] {
  const clusters = new Map<string, RawDiscoveredArticle[]>();
  for (const article of articles) {
    const key = clusterKey(article);
    const existing = clusters.get(key) ?? [];
    existing.push(article);
    clusters.set(key, existing);
  }
  return [...clusters.entries()]
    .map(([key, groupedArticles]) => ({
      key,
      articles: groupedArticles.sort((left, right) => right.seenAt.localeCompare(left.seenAt))
    }))
    .sort((left, right) => right.articles.length - left.articles.length);
}

function updateFromCluster(cluster: Cluster): BriefingUpdateRecord {
  const lead = cluster.articles[0];
  const sourceTypes = [...new Set(cluster.articles.map((article) => sourceTypeForDomain(article.domain)))].sort();
  const sourceCountries = [...new Set(cluster.articles.map((article) => article.sourceCountry).filter(Boolean))];
  const sourceCount = new Set(cluster.articles.map((article) => article.domain)).size;

  return {
    id: `update_${cluster.key}`,
    storyId: null,
    headline: lead.title,
    region: regionForArticle(lead),
    category: lead.topic,
    whatChanged: `New reporting was detected in the last hour across ${sourceCount} distinct source${sourceCount === 1 ? "" : "s"}. The article framing is treated as a source claim until corroborated.`,
    whyItMatters: whyItMattersForTopic(lead.topic, sourceCountries),
    confidence: confidenceForSourceCount(sourceCount, sourceTypes),
    emotionalLoad: emotionalLoadForTopic(lead.topic),
    sourceCount,
    sourceTypes,
    sourceMix: sourceMixForArticles(cluster.articles),
    isCritical: false
  };
}

function summaryForUpdates(updates: BriefingUpdateRecord[]): string {
  if (updates.length === 0) {
    return "No meaningful update changed the shape of today’s briefing in the last hour.";
  }
  return `${updates.length} meaningful update${updates.length === 1 ? "" : "s"} changed the shape of today’s briefing. None are treated as urgent without further verification.`;
}

function confidenceForSourceCount(sourceCount: number, sourceTypes: string[]): ConfidenceRating {
  if (sourceCount >= 4 && sourceTypes.length >= 2) {
    return "Medium-high";
  }
  if (sourceCount >= 2) {
    return "Medium";
  }
  return "Low";
}

function emotionalLoadForTopic(topic: string): EmotionalLoad {
  switch (topic) {
    case "Conflict":
    case "Humanitarian":
      return "Heavy";
    case "Climate":
    case "Health":
    case "Economy":
      return "Medium";
    default:
      return "Low";
  }
}

function whyItMattersForTopic(topic: string, sourceCountries: string[]): string {
  const countryContext = sourceCountries.length > 0 ? ` Reporting sources currently include ${sourceCountries.slice(0, 3).join(", ")}.` : "";
  switch (topic) {
    case "Conflict":
      return `Conflict updates can affect civilian safety, negotiations, and regional escalation risk.${countryContext}`;
    case "Climate":
      return `Climate and disaster updates can change risk assessments for infrastructure, health, and displacement.${countryContext}`;
    case "Health":
      return `Health updates can affect public guidance, medical capacity, and vulnerable populations.${countryContext}`;
    case "Economy":
      return `Economic updates can affect household costs, public budgets, and market expectations.${countryContext}`;
    case "Humanitarian":
      return `Humanitarian updates can affect aid access, civilian protection, and displacement planning.${countryContext}`;
    default:
      return `This update may change the context of today’s briefing, but it still needs corroboration.${countryContext}`;
  }
}

function regionForCountry(country: string): string {
  const normalized = country.toLowerCase();
  if (["united states", "canada"].includes(normalized)) {
    return "US";
  }
  if (["united kingdom", "ireland", "france", "germany", "spain", "italy", "netherlands"].includes(normalized)) {
    return "Europe";
  }
  if (["israel", "palestine", "lebanon", "iran", "iraq", "syria", "jordan", "saudi arabia", "yemen"].includes(normalized)) {
    return "Middle East";
  }
  if (["china", "india", "japan", "pakistan", "malaysia", "singapore", "philippines"].includes(normalized)) {
    return "Asia";
  }
  if (["nigeria", "south africa", "kenya", "egypt", "ghana", "ethiopia"].includes(normalized)) {
    return "Africa";
  }
  if (["brazil", "mexico", "argentina", "chile", "colombia", "peru"].includes(normalized)) {
    return "Latin America";
  }
  return country || "World";
}

function regionForArticle(article: RawDiscoveredArticle): string {
  const title = article.title.toLowerCase();
  if (containsAny(title, ["congo", "kenya", "nigeria", "south africa", "sudan", "ethiopia", "ghana", "egypt"])) {
    return "Africa";
  }
  if (containsAny(title, ["gaza", "israel", "palestinian", "lebanon", "iran", "iraq", "syria", "abu dhabi", "uae", "yemen"])) {
    return "Middle East";
  }
  if (containsAny(title, ["china", "india", "japan", "pakistan", "malaysia", "singapore", "philippines"])) {
    return "Asia";
  }
  if (containsAny(title, ["brazil", "mexico", "argentina", "chile", "colombia", "peru"])) {
    return "Latin America";
  }
  if (containsAny(title, ["moscow", "russia", "ukraine", "italy", "france", "germany", "spain", "britain", "uk "])) {
    return "Europe";
  }
  if (containsAny(title, ["united states", "america", "canada", "washington"])) {
    return "US";
  }
  return regionForCountry(article.sourceCountry);
}

function containsAny(value: string, needles: string[]): boolean {
  return needles.some((needle) => value.includes(needle));
}

function clusterKey(article: RawDiscoveredArticle): string {
  const tokens = article.title
    .toLowerCase()
    .replace(/[^a-z0-9 ]+/g, " ")
    .split(/\s+/)
    .filter((token) => token.length > 3 && !STOP_WORDS.has(token))
    .slice(0, 5);
  return `${slugify(article.topic)}_${slugify(tokens.join("_") || article.domain)}`;
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 56);
}

function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

const STOP_WORDS = new Set([
  "about",
  "after",
  "amid",
  "from",
  "have",
  "into",
  "more",
  "over",
  "said",
  "says",
  "than",
  "that",
  "their",
  "this",
  "with",
  "will",
  "your"
]);
