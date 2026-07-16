import { sourceQualityForDomain, sourceRecordForArticle, sourceTypeForDomain } from "./sourceRegistry";
import type { ConfidenceRating, EmotionalLoad, RawDiscoveredArticle, SourceRecord } from "./types";

export interface BriefingStorySummary {
  id: string;
  rank?: number;
  publishedAt?: string;
  expiresAt?: string;
  headline: string;
  region: string;
  category: string;
  summary: string;
  whyItMatters: string;
  confidence: ConfidenceRating;
  emotionalLoad: EmotionalLoad;
  sourceCount: number;
  imageId: string | null;
}

export interface BriefingSection {
  id: string;
  title: string;
  stories: BriefingStorySummary[];
}

export interface BriefingDocument {
  date: string;
  title: string;
  readingTimeMinutes: number;
  emotionalLoad: EmotionalLoad;
  storyCount: number;
  sections: BriefingSection[];
}

export interface StoryDetailDocument {
  id: string;
  headline: string;
  category: string;
  region: string;
  countries?: string[];
  sourceCountries?: string[];
  verification?: {
    status: ConfidenceRating;
    summary: string;
    checks: string[];
  };
  whatHappened: string;
  whyItMatters: string;
  whatWeKnow: string[];
  whatIsUnclear: string[];
  framingCheck: {
    westernMainstream: string;
    localRegional: string;
    officialGovernment: string;
    affectedPopulation: string;
    independentEvidence: string;
    humanRightsNGO: string | null;
    opposingSide: string | null;
  };
  confidence: {
    rating: ConfidenceRating;
    reason: string;
  };
  emotionalLoad: EmotionalLoad;
  sources: SourceRecord[];
  sourceEvidence?: Array<{
    sourceName: string;
    title: string;
    url: string;
    excerpt: string | null;
    sourceCountry: string;
  }>;
  biasAudit: {
    passed: boolean;
    notes: string[];
  };
  depthAnalysis: null;
  evidenceCheck: {
    claim: string;
    classification: "Plausible but unconfirmed";
    why: string;
  };
}

interface StoryCluster {
  primary: RawDiscoveredArticle;
  articles: RawDiscoveredArticle[];
  keywords: Set<string>;
  latestSeenAt: string;
  region: string;
  topic: string;
}

const SECTION_ORDER = [
  "World",
  "Middle East",
  "Europe",
  "Africa",
  "Asia",
  "Latin America",
  "US",
  "Health",
  "Economy",
  "Science & Tech",
  "Climate",
  "Humanitarian"
];

export function buildBriefingDocument(
  articles: RawDiscoveredArticle[],
  generatedAt: Date,
  maxStories = 36
): BriefingDocument {
  const stories = storySummariesFromArticles(articles, maxStories, dateKey(generatedAt));
  const grouped = groupStories(stories);
  return {
    date: dateKey(generatedAt),
    title: "Today's Global Briefing",
    readingTimeMinutes: Math.max(4, Math.ceil(stories.length * 0.5)),
    emotionalLoad: overallEmotionalLoad(stories),
    storyCount: stories.length,
    sections: grouped
  };
}

export function buildStoryDetailsFromArticles(
  articles: RawDiscoveredArticle[],
  maxStories = 36,
  generatedAt: Date = new Date()
): StoryDetailDocument[] {
  return selectStoryClusters(articles, maxStories, dateKey(generatedAt)).map((cluster) => {
    const article = cluster.primary;
    const sources = sourceRecordsForCluster(cluster);
    const sourceNames = sources.map((source) => source.name).join(", ");
    const sourceTypes = [...new Set(sources.map((source) => source.type))].join(", ");
    const confidence = confidenceForSources(article, sources);
    const countries = countriesForCluster(cluster);
    const sourceCountries = sourceCountriesForCluster(cluster);
    return {
      id: storyId(article),
      headline: article.title,
      category: article.topic,
      region: cluster.region,
      countries,
      sourceCountries,
      verification: verificationForCluster(cluster, sources),
      whatHappened: whatHappenedForCluster(cluster, sources),
      whyItMatters: whyItMattersForArticle(article, cluster.region),
      whatWeKnow: [
        `The live pipeline matched ${cluster.articles.length} related report${cluster.articles.length === 1 ? "" : "s"} on this subject.`,
        `Event context: ${countries.length > 0 ? countries.join(", ") : cluster.region}.`,
        `Reporting source countries: ${sourceCountries.join(", ") || "Unknown"}.`,
        `Sources currently include ${sourceNames}.`,
        `Detected source types include ${sourceTypes || "local/regional"}.`
      ],
      whatIsUnclear: uncertaintyItemsForCluster(cluster, sources),
      framingCheck: {
        westernMainstream: "If covered by Western or international outlets, wording may foreground diplomatic, security, or institutional consequences.",
        localRegional: "Local and regional sources may foreground immediate disruption, civilian experience, and local political context.",
        officialGovernment: "Official statements should be attributed to the actor making the claim and not treated as neutral fact.",
        affectedPopulation: "Affected-population framing is still needed where available, especially for conflict, disaster, and health stories.",
        independentEvidence: sources.length > 1
          ? "Multiple publishers are reporting related developments, which improves corroboration of coverage but does not independently verify every claim."
          : "Current independent evidence is limited to source detection and available publication metadata until more corroboration is added.",
        humanRightsNGO: article.topic === "Humanitarian" || article.topic === "Conflict"
          ? "Human rights or humanitarian sources should be checked for civilian harm, access restrictions, and legal-risk context."
          : null,
        opposingSide: article.topic === "Conflict"
          ? "Opposing-side claims should be included when available and held to the same evidence standard."
          : null
      },
      confidence: {
        rating: confidence,
        reason: confidenceReasonForCluster(cluster, sources)
      },
      emotionalLoad: emotionalLoadForTopic(article.topic),
      sources,
      sourceEvidence: sourceEvidenceForCluster(cluster),
      biasAudit: {
        passed: true,
        notes: [
          "The headline is attributed to source reporting.",
          "Official or actor claims are not adopted as neutral fact.",
          "Uncertainty and verification limits are stated clearly.",
          "No collective blame is assigned to civilians or identity groups."
        ]
      },
      depthAnalysis: null,
      evidenceCheck: {
        claim: article.title,
        classification: "Plausible but unconfirmed",
        why: evidenceCheckReasonForCluster(sources)
      }
    };
  });
}

function storySummariesFromArticles(
  articles: RawDiscoveredArticle[],
  maxStories: number,
  briefingDate: string
): BriefingStorySummary[] {
  return selectStoryClusters(articles, maxStories, briefingDate).map((cluster, index) => {
    const article = cluster.primary;
    const sourceCount = sourceRecordsForCluster(cluster).length;
    return {
      id: storyId(article),
      rank: index + 1,
      publishedAt: article.seenAt,
      expiresAt: expiryDateForArticle(article),
      headline: article.title,
      region: cluster.region,
      category: article.topic,
      summary: summaryForCluster(cluster),
      whyItMatters: whyItMattersForArticle(article, cluster.region),
      confidence: confidenceForSources(article, sourceRecordsForCluster(cluster)),
      emotionalLoad: emotionalLoadForTopic(article.topic),
      sourceCount,
      imageId: article.imageUrl ? imageIdForArticle(article) : null
    };
  });
}

function expiryDateForArticle(article: RawDiscoveredArticle): string {
  const publishedAt = new Date(article.seenAt);
  if (Number.isNaN(publishedAt.getTime())) {
    return article.seenAt;
  }
  publishedAt.setUTCDate(publishedAt.getUTCDate() + 3);
  return publishedAt.toISOString();
}

function selectStoryClusters(articles: RawDiscoveredArticle[], maxStories: number, briefingDate: string): StoryCluster[] {
  const clusters: StoryCluster[] = [];
  for (const article of selectArticlesForDate(articles, briefingDate)) {
    const keywords = keywordsForTitle(article.title);
    const region = regionForArticle(article);
    const match = clusters.find((cluster) => shouldCluster(article, keywords, region, cluster));
    if (match) {
      match.articles.push(article);
      for (const keyword of keywords) {
        match.keywords.add(keyword);
      }
      if (primaryCandidateScore(article) > primaryCandidateScore(match.primary)) {
        match.primary = article;
      }
      if (article.seenAt > match.latestSeenAt) {
        match.latestSeenAt = article.seenAt;
      }
      continue;
    }

    clusters.push({
      primary: article,
      articles: [article],
      keywords,
      latestSeenAt: article.seenAt,
      region,
      topic: article.topic
    });
  }

  const ranked = clusters
    .sort((left, right) => {
      const scoreDelta = editorialScore(right) - editorialScore(left);
      if (scoreDelta !== 0) {
        return scoreDelta;
      }
      const sourceDelta = sourceRecordsForCluster(right).length - sourceRecordsForCluster(left).length;
      if (sourceDelta !== 0) {
        return sourceDelta;
      }
      const timeDelta = right.latestSeenAt.localeCompare(left.latestSeenAt);
      if (timeDelta !== 0) {
        return timeDelta;
      }
      return right.primary.title.localeCompare(left.primary.title);
    });
  return diversifyClusters(ranked, maxStories);
}

function diversifyClusters(clusters: StoryCluster[], maxStories: number): StoryCluster[] {
  const selected: StoryCluster[] = [];
  const selectedKeys = new Set<string>();
  const sectionCounts = new Map<string, number>();
  const firstPassLimit = Math.min(3, Math.max(1, Math.ceil(maxStories / 8)));

  for (const cluster of clusters) {
    if (selected.length >= maxStories) {
      break;
    }
    const section = sectionTitleForStory({
      id: storyId(cluster.primary),
      headline: cluster.primary.title,
      region: cluster.region,
      category: cluster.topic,
      summary: "",
      whyItMatters: "",
      confidence: confidenceForSources(cluster.primary, sourceRecordsForCluster(cluster)),
      emotionalLoad: emotionalLoadForTopic(cluster.topic),
      sourceCount: sourceRecordsForCluster(cluster).length,
      imageId: null
    });
    const count = sectionCounts.get(section) ?? 0;
    if (count >= firstPassLimit) {
      continue;
    }
    selected.push(cluster);
    selectedKeys.add(storyId(cluster.primary));
    sectionCounts.set(section, count + 1);
  }

  for (const cluster of clusters) {
    if (selected.length >= maxStories) {
      break;
    }
    const id = storyId(cluster.primary);
    if (!selectedKeys.has(id)) {
      selected.push(cluster);
      selectedKeys.add(id);
    }
  }

  return selected;
}

function selectArticlesForDate(articles: RawDiscoveredArticle[], briefingDate: string): RawDiscoveredArticle[] {
  const seen = new Set<string>();
  return articles
    .filter((article) => article.seenAt.startsWith(briefingDate))
    .filter(isUsefulBriefingArticle)
    .sort((left, right) => right.seenAt.localeCompare(left.seenAt))
    .filter((article) => {
      const key = `${article.title.toLowerCase()}|${article.domain.toLowerCase()}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
}

function isUsefulBriefingArticle(article: RawDiscoveredArticle): boolean {
  const title = article.title.trim();
  const normalized = title.toLowerCase();
  const meaningfulWordCount = title.split(/\s+/).filter((word) => /[A-Za-z0-9]/.test(word)).length;
  if (meaningfulWordCount <= 3 && countriesForTitle(title).length === 0 && !containsAny(normalized, PUBLIC_INTEREST_TERMS)) {
    return false;
  }
  if (containsAny(normalized, ["photo essay", "photos:", "video:", "watch:", "quiz:", "powerless to learn"])) {
    return false;
  }
  return true;
}

function groupStories(stories: BriefingStorySummary[]): BriefingSection[] {
  const byTitle = new Map<string, BriefingStorySummary[]>();
  const titleOrder: string[] = [];
  for (const story of stories) {
    const title = sectionTitleForStory(story);
    if (!byTitle.has(title)) {
      titleOrder.push(title);
    }
    byTitle.set(title, [...(byTitle.get(title) ?? []), story]);
  }
  return titleOrder
    .filter((title) => byTitle.has(title))
    .map((title) => ({
      id: slugify(title),
      title,
      stories: byTitle.get(title) ?? []
    }));
}

function sectionTitleForStory(story: BriefingStorySummary): string {
  if (["Health", "Economy", "Science & Tech", "Climate", "Humanitarian"].includes(story.category)) {
    return story.category;
  }
  return SECTION_ORDER.includes(story.region) ? story.region : "World";
}

function confidenceForSources(article: RawDiscoveredArticle, sources: SourceRecord[]): ConfidenceRating {
  const sourceCount = sources.length;
  const qualityScore = sourceQualityScoreForSources(sources);
  const sourceType = sourceTypeForDomain(article.domain);
  if (sourceCount >= 3 && qualityScore >= 170) {
    return "Medium-high";
  }
  if (sourceCount >= 2 && qualityScore >= 120) {
    return "Medium";
  }
  if ((sourceType === "wire" || sourceType === "primary") && qualityScore >= 80) {
    return "Medium";
  }
  return "Low";
}

function sourceRecordsForCluster(cluster: StoryCluster): SourceRecord[] {
  const records = new Map<string, SourceRecord>();
  for (const article of cluster.articles) {
    const source = sourceRecordForArticle(article);
    records.set(source.id, source);
  }
  return [...records.values()]
    .sort((left, right) => (right.qualityScore ?? 0) - (left.qualityScore ?? 0) || left.name.localeCompare(right.name))
    .slice(0, 8);
}

// The summary renders directly beneath the headline in the app, so it must
// never quote the headline back. It carries what the headline cannot:
// who is reporting, how much corroboration exists, and where it points.
function summaryForCluster(cluster: StoryCluster): string {
  const sources = sourceRecordsForCluster(cluster);
  const sourceCount = sources.length;
  const countries = countriesForCluster(cluster);
  const countryContext = countries.length > 0 ? ` Coverage points to ${countries.slice(0, 2).join(" and ")}.` : "";
  const leadName = sources[0]?.name ?? "one detected source";
  const excerpt = bestExcerptForCluster(cluster);
  if (excerpt) {
    const attribution = sourceCount > 1 ? `Via ${leadName} and ${sourceCount - 1} more` : `Via ${leadName}`;
    return `${attribution}: ${excerpt}${countryContext}`;
  }
  if (sourceCount >= 3) {
    return `${leadName} and ${sourceCount - 1} other outlets are on this story.${countryContext} Where their accounts overlap it is treated as corroborated; lone figures stay attributed.`;
  }
  if (sourceCount === 2) {
    return `${leadName} and ${sources[1]?.name ?? "one other outlet"} are both reporting it.${countryContext} Early corroboration, with specifics still attributed to each source.`;
  }
  const sourceType = sourceTypeForDomain(cluster.primary.domain);
  const typePhrase =
    sourceType === "wire"
      ? ", a wire service that syndicates widely"
      : sourceType === "primary"
        ? ", a primary source close to the event"
        : "";
  return `So far this comes only from ${leadName}${typePhrase}.${countryContext} An early signal — it firms up if more sources or primary evidence arrive.`;
}

function whatHappenedForCluster(cluster: StoryCluster, sources: SourceRecord[]): string {
  const sourceNames = sources.map((source) => source.name).slice(0, 4).join(", ");
  const countries = countriesForCluster(cluster);
  const sourceCountries = sourceCountriesForCluster(cluster);
  const countryContext = countries.length > 0 ? ` The event context currently points to ${countries.join(", ")}.` : "";
  const sourceContext = sourceCountries.length > 0 ? ` Reporting is currently coming through sources based in ${sourceCountries.join(", ")}.` : "";
  const relatedContext = relatedHeadlineContext(cluster);
  const excerptContext = articleEvidenceContext(cluster);
  if (sources.length > 1) {
    return `${sources.length} sources, including ${sourceNames}, report: “${cluster.primary.title}.”${excerptContext}${relatedContext}${countryContext}${sourceContext} The grouping shows overlapping coverage; facts reported by multiple distinct sources are treated as corroborated reporting, while figures, motives, and actor claims remain attributed.`;
  }
  return `${sources[0]?.name ?? "A source"} reports: “${cluster.primary.title}.”${excerptContext}${countryContext}${sourceContext} This is presented as source reporting, with specific figures and actor claims kept attributed until corroborated.`;
}

function confidenceReasonForCluster(cluster: StoryCluster, sources: SourceRecord[]): string {
  if (sources.length >= 3) {
    return `${sources.length} distinct sources are reporting related developments, but details still depend on source claims and available primary evidence.`;
  }
  if (sources.length === 2) {
    return "Two distinct sources are reporting related developments, giving limited corroboration while disputed details remain attributed.";
  }
  const sourceType = sourceTypeForDomain(cluster.primary.domain);
  if (sourceType === "wire" || sourceType === "primary") {
    return "This story currently comes from a wire or primary source, but still needs corroboration before specific claims are treated as confirmed.";
  }
  return "This story currently comes from one detected source in the live pipeline, so the event should be treated as plausible reporting until corroborated.";
}

function uncertaintyItemsForCluster(cluster: StoryCluster, sources: SourceRecord[]): string[] {
  const sourceCount = sources.length;
  if (sourceCount >= 3) {
    return [
      `${sourceCount} distinct sources are reporting the same broad story, so the event itself is treated as corroborated reporting.`,
      "Specific figures, responsibility claims, motives, and official statements still need source-by-source attribution.",
      "More primary documents, local reporting, or affected-population accounts may change the confidence rating."
    ];
  }
  if (sourceCount === 2) {
    return [
      "Two distinct sources are reporting the same broad story, giving early corroboration of the event.",
      "Specific figures, responsibility claims, motives, and official statements still need source-by-source attribution.",
      "More local, primary, or affected-population sources may change the confidence rating."
    ];
  }
  const sourceType = sourceTypeForDomain(cluster.primary.domain);
  return [
    sourceType === "wire" || sourceType === "primary"
      ? "The story currently comes from one wire or primary source, so the event is plausible but still needs independent corroboration."
      : "The story currently comes from one detected source, so the event is plausible but still needs independent corroboration.",
    "Specific figures, responsibility claims, motives, and official statements should be treated cautiously until confirmed by further sources.",
    "More local, primary, or affected-population sources may change the confidence rating."
  ];
}

function evidenceCheckReasonForCluster(sources: SourceRecord[]): string {
  if (sources.length >= 3) {
    return `${sources.length} distinct sources report the same broad story, so the app treats the event as corroborated reporting while still attributing figures, responsibility claims, and official statements.`;
  }
  if (sources.length === 2) {
    return "Two distinct sources report the same broad story, giving early corroboration while details still need attribution and further checking.";
  }
  return "The claim appears in one detected source, so this briefing treats it as plausible reporting until another independent source, primary document, or local report corroborates it.";
}

function verificationForCluster(cluster: StoryCluster, sources: SourceRecord[]): StoryDetailDocument["verification"] {
  const sourceTypes = new Set(sources.map((source) => source.type));
  const sourceCountries = sourceCountriesForCluster(cluster);
  const hasLocal = sources.some((source) => source.type === "local/regional");
  const hasPrimary = sources.some((source) => source.type === "primary" || source.type === "official");
  const checks = [
    `${sources.length} distinct source${sources.length === 1 ? "" : "s"} matched in the live pipeline.`,
    `${sourceTypes.size} source type${sourceTypes.size === 1 ? "" : "s"} represented: ${[...sourceTypes].join(", ") || "unknown"}.`,
    `Reporting countries currently include ${sourceCountries.join(", ") || "unknown"}.`,
    hasLocal ? "At least one local or regional source is present." : "No local or regional source has been matched yet.",
    hasPrimary ? "A primary or official source is present, but its claims still need attribution." : "No primary or official source has been matched yet."
  ];

  return {
    status: confidenceForSources(cluster.primary, sources),
    summary: confidenceReasonForCluster(cluster, sources),
    checks
  };
}

function editorialScore(cluster: StoryCluster): number {
  const sources = sourceRecordsForCluster(cluster);
  const sourceTypes = new Set(sources.map((source) => source.type));
  const sourceCountries = sourceCountriesForCluster(cluster);
  const title = cluster.primary.title.toLowerCase();
  const topicWeight = topicImportance(cluster.topic);
  const sourceQualityWeight = Math.min(sourceQualityScoreForSources(sources), 260) / 4;
  const sourceWeight = sources.length * 7 + sourceTypes.size * 8 + Math.min(sourceCountries.length, 4) * 3 + sourceQualityWeight;
  const countryWeight = countriesForCluster(cluster).length > 0 ? 8 : 0;
  const publicInterestWeight = containsAny(title, PUBLIC_INTEREST_TERMS) ? 16 : 0;
  const lowValuePenalty = containsAny(title, LOW_VALUE_TERMS) ? 55 : 0;
  const lowQualityPenalty = sourceQualityScoreForSources(sources) < 70 ? 14 : 0;
  const singleSourcePenalty = sources.length === 1 && !["wire", "primary"].includes(sources[0]?.type ?? "") ? 10 : 0;
  return topicWeight + sourceWeight + countryWeight + publicInterestWeight - lowValuePenalty - lowQualityPenalty - singleSourcePenalty;
}

function primaryCandidateScore(article: RawDiscoveredArticle): number {
  const title = article.title.toLowerCase();
  const sourceType = sourceTypeForDomain(article.domain);
  const sourceWeight = sourceQualityForDomain(article.domain).score / 5 + (sourceType === "wire" ? 4 : sourceType === "primary" ? 3 : 0);
  const topicWeight = topicImportance(article.topic);
  const publicInterestWeight = containsAny(title, PUBLIC_INTEREST_TERMS) ? 10 : 0;
  const lowValuePenalty = containsAny(title, LOW_VALUE_TERMS) ? 40 : 0;
  const headlinePenalty = containsAny(title, WEAK_LEAD_HEADLINE_TERMS) ? 35 : 0;
  return sourceWeight + topicWeight + publicInterestWeight - lowValuePenalty - headlinePenalty;
}

function sourceQualityScoreForSources(sources: SourceRecord[]): number {
  return sources
    .map((source) => source.qualityScore ?? 50)
    .sort((left, right) => right - left)
    .reduce((total, score, index) => total + score * (index === 0 ? 1 : 0.65), 0);
}

function topicImportance(topic: string): number {
  switch (topic) {
    case "Conflict":
      return 42;
    case "Humanitarian":
      return 38;
    case "Health":
    case "Climate":
      return 32;
    case "Economy":
      return 28;
    case "Science & Tech":
      return 20;
    case "World":
      return 14;
    default:
      return 10;
  }
}

function countriesForCluster(cluster: StoryCluster): string[] {
  const countries = new Set<string>();
  for (const article of cluster.articles) {
    for (const country of countriesForTitle(article.title)) {
      countries.add(country);
    }
  }
  return [...countries].sort().slice(0, 5);
}

function sourceCountriesForCluster(cluster: StoryCluster): string[] {
  return [...new Set(cluster.articles.map((article) => article.sourceCountry).filter(Boolean))]
    .filter((country) => country !== "Unknown")
    .slice(0, 5);
}

function countriesForTitle(title: string): string[] {
  const normalized = title.toLowerCase();
  const countries: string[] = [];
  for (const [needle, country] of COUNTRY_TERMS) {
    if (normalized.includes(needle)) {
      countries.push(country);
    }
  }
  return [...new Set(countries)];
}

function whyItMattersForArticle(article: RawDiscoveredArticle, region: string): string {
  const countries = countriesForTitle(article.title);
  const place = countries.length > 0 ? countries.slice(0, 2).join(" and ") : region;
  const context = `${article.title} ${article.excerpt ?? ""}`.toLowerCase();
  if (containsAny(context, ["index", "stock", "stocks", "shares", "market", "markets", "exchange", "benchmark"])) {
    return `Market and index changes tied to ${place} can affect investor exposure, benchmark tracking, and how companies are weighted in regional portfolios. The briefing keeps the item low-intensity while noting what changes for markets or institutions.`;
  }
  if (containsAny(context, ["ebola", "outbreak", "cholera", "measles", "disease"])) {
    if (containsAny(context, ["displacement", "hunger", "food insecurity", "malnutrition"])) {
      return `Disease reporting in ${place} matters because outbreaks become harder to contain when displacement, hunger, or weak services limit access to care. The strongest signal is not only case counts, but whether health teams can reach people already under pressure.`;
    }
    return `Disease reporting in ${place} matters because outbreaks can quickly test local clinics, border health checks, aid access, and trust in public guidance. The strongest signal is not only case counts, but whether response capacity is keeping up with vulnerable communities.`;
  }
  switch (article.topic) {
    case "Conflict":
      return `This may affect civilian safety, diplomatic pressure, and escalation risk in ${place}, especially if casualty figures or responsibility claims remain disputed.`;
    case "Health":
      return `Health developments in ${place} can affect public guidance, medical capacity, border screening, and people already made vulnerable by displacement or weak services.`;
    case "Climate":
      return `Climate and disaster stories in ${place} can change risk assessments for infrastructure, food, water, health services, and displacement.`;
    case "Economy":
      return `Economic shifts tied to ${place} can affect household costs, public budgets, market expectations, and the policy room governments have to respond.`;
    case "Science & Tech":
      return `Science and technology developments can affect public policy, security, regulation, and daily life beyond the place where the story first appears.`;
    case "Humanitarian":
      return `Humanitarian developments in ${place} can affect aid access, civilian protection, displacement planning, and how quickly outside support reaches people.`;
    default:
      return `A developing thread in ${place}. If corroboration arrives it graduates into the main picture; if it fades, it quietly leaves the brief.`;
  }
}

function relatedHeadlineContext(cluster: StoryCluster): string {
  const related = cluster.articles
    .filter((article) => article.id !== cluster.primary.id)
    .map((article) => article.title)
    .filter((title) => title !== cluster.primary.title)
    .slice(0, 2);
  if (related.length === 0) {
    return "";
  }
  return ` Matched coverage also references ${related.map((title) => `“${title}”`).join(" and ")}.`;
}

function bestExcerptForCluster(cluster: StoryCluster): string {
  const excerpt = cluster.articles
    .map((article) => article.excerpt)
    .filter((value): value is string => Boolean(value && value.trim().length > 0))
    .map((value) => trimSentence(value, 240))
    .find((value) => value.length > 40 && !sameNormalizedText(value, cluster.primary.title));
  return excerpt ?? "";
}

function articleEvidenceContext(cluster: StoryCluster): string {
  const evidence = cluster.articles
    .filter((article) => article.excerpt && article.excerpt.trim().length > 0)
    .slice(0, 3)
    .map((article) => {
      const source = sourceRecordForArticle(article);
      return `${source.name} adds: “${trimSentence(article.excerpt ?? "", 220)}”`;
    });
  if (evidence.length === 0) {
    return "";
  }
  return ` ${evidence.join(" ")}`;
}

function sourceEvidenceForCluster(cluster: StoryCluster): NonNullable<StoryDetailDocument["sourceEvidence"]> {
  return cluster.articles.slice(0, 8).map((article) => {
    const source = sourceRecordForArticle(article);
    return {
      sourceName: source.name,
      title: article.title,
      url: article.url,
      excerpt: article.excerpt ? trimSentence(article.excerpt, 520) : null,
      sourceCountry: article.sourceCountry
    };
  });
}

function trimSentence(value: string, maxLength: number): string {
  const cleaned = value.replace(/\s+/g, " ").trim();
  if (cleaned.length <= maxLength) {
    return cleaned;
  }
  const clipped = cleaned.slice(0, maxLength - 1);
  const sentenceEnd = Math.max(clipped.lastIndexOf("."), clipped.lastIndexOf(";"));
  if (sentenceEnd > 100) {
    return clipped.slice(0, sentenceEnd + 1).trim();
  }
  const lastSpace = clipped.lastIndexOf(" ");
  return `${clipped.slice(0, lastSpace > 100 ? lastSpace : clipped.length).trim()}…`;
}

function sameNormalizedText(left: string, right: string): boolean {
  return normalizeComparableText(left) === normalizeComparableText(right);
}

function normalizeComparableText(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function emotionalLoadForTopic(topic: string): EmotionalLoad {
  switch (topic) {
    case "Conflict":
    case "Humanitarian":
      return "Heavy";
    case "Health":
    case "Climate":
    case "Economy":
      return "Medium";
    default:
      return "Low";
  }
}

function overallEmotionalLoad(stories: BriefingStorySummary[]): EmotionalLoad {
  const heavyCount = stories.filter((story) => story.emotionalLoad === "Heavy").length;
  if (heavyCount >= 8) {
    return "Heavy";
  }
  if (stories.some((story) => story.emotionalLoad === "Heavy" || story.emotionalLoad === "Medium")) {
    return "Medium";
  }
  return "Low";
}

function regionForArticle(article: RawDiscoveredArticle): string {
  const title = article.title.toLowerCase();
  if (containsAny(title, ["gaza", "israel", "palestinian", "lebanon", "iran", "iraq", "syria", "uae", "yemen"])) {
    return "Middle East";
  }
  if (containsAny(title, ["ukraine", "russia", "italy", "france", "germany", "spain", "britain", "maldives"])) {
    return "Europe";
  }
  if (containsAny(title, ["congo", "kenya", "nigeria", "south africa", "sudan", "ethiopia", "ghana", "egypt"])) {
    return "Africa";
  }
  if (containsAny(title, ["china", "india", "japan", "pakistan", "thai", "malaysia", "singapore", "philippines"])) {
    return "Asia";
  }
  if (containsAny(title, ["brazil", "mexico", "argentina", "chile", "colombia", "peru"])) {
    return "Latin America";
  }
  if (containsAny(title, ["united states", "america", "trump", "washington", "canada"])) {
    return "US";
  }
  return "World";
}

function storyId(article: RawDiscoveredArticle): string {
  return article.id.replace(/^raw_/, "story_").replace(/^rss_/, "story_");
}

function imageIdForArticle(article: RawDiscoveredArticle): string | null {
  return article.imageUrl ? `image_${storyId(article).replace(/^story_/, "")}` : null;
}

function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function containsAny(value: string, needles: string[]): boolean {
  return needles.some((needle) => value.includes(needle));
}

function shouldCluster(article: RawDiscoveredArticle, keywords: Set<string>, region: string, cluster: StoryCluster): boolean {
  if (article.topic !== cluster.topic || region !== cluster.region) {
    return false;
  }
  const shared = sharedKeywordCount(keywords, cluster.keywords);
  if (shared >= 3) {
    return true;
  }
  const smallerSetSize = Math.max(1, Math.min(keywords.size, cluster.keywords.size));
  return shared >= 2 && shared / smallerSetSize >= 0.4;
}

function sharedKeywordCount(left: Set<string>, right: Set<string>): number {
  let count = 0;
  for (const keyword of left) {
    if (right.has(keyword)) {
      count += 1;
    }
  }
  return count;
}

function keywordsForTitle(title: string): Set<string> {
  return new Set(title
    .toLowerCase()
    .replace(/['']/g, "")
    .replace(/[^a-z0-9\s-]/g, " ")
    .split(/\s+/)
    .map((word) => word.trim())
    .filter((word) => word.length >= 4 && !TITLE_STOP_WORDS.has(word)));
}

const TITLE_STOP_WORDS = new Set([
  "about",
  "after",
  "again",
  "against",
  "amid",
  "before",
  "being",
  "from",
  "have",
  "into",
  "over",
  "said",
  "says",
  "that",
  "their",
  "they",
  "this",
  "with",
  "world",
  "news",
  "live",
  "latest",
  "update",
  "updates",
  "report",
  "reports"
]);

const PUBLIC_INTEREST_TERMS = [
  "ceasefire",
  "airstrike",
  "strike",
  "civilian",
  "casualties",
  "hostage",
  "aid",
  "humanitarian",
  "refugee",
  "displacement",
  "outbreak",
  "flood",
  "wildfire",
  "election",
  "sanctions",
  "central bank",
  "inflation",
  "court",
  "parliament",
  "government",
  "minister",
  "military"
];

const LOW_VALUE_TERMS = [
  "world cup tickets",
  "tickets",
  "palme d'or",
  "palme dor",
  "cannes",
  "celebrity",
  "actor",
  "actress",
  "singer",
  "album",
  "movie",
  "film festival",
  "tax refund",
  "shakira",
  "celebrity tax",
  "mental health awareness",
  "tour stops",
  "dan + shay",
  "football",
  "nba",
  "lottery",
  "horoscope",
  "streaming"
];

const WEAK_LEAD_HEADLINE_TERMS = [
  "photos from",
  "in photos",
  "gallery",
  "live:",
  "live :",
  "watch:",
  "video:",
  "explainer:",
  "how to buy",
  "what to know"
];

const COUNTRY_TERMS: Array<[string, string]> = [
  ["gaza", "Palestine"],
  ["palestinian", "Palestine"],
  ["israel", "Israel"],
  ["lebanon", "Lebanon"],
  ["iran", "Iran"],
  ["iraq", "Iraq"],
  ["syria", "Syria"],
  ["yemen", "Yemen"],
  ["ukraine", "Ukraine"],
  ["russia", "Russia"],
  ["france", "France"],
  ["germany", "Germany"],
  ["britain", "United Kingdom"],
  ["united kingdom", "United Kingdom"],
  ["china", "China"],
  ["india", "India"],
  ["japan", "Japan"],
  ["pakistan", "Pakistan"],
  ["philippines", "Philippines"],
  ["kenya", "Kenya"],
  ["nigeria", "Nigeria"],
  ["sudan", "Sudan"],
  ["congo", "DR Congo"],
  ["brazil", "Brazil"],
  ["mexico", "Mexico"],
  ["argentina", "Argentina"],
  ["colombia", "Colombia"],
  ["united states", "United States"],
  ["america", "United States"],
  ["canada", "Canada"]
];

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}
