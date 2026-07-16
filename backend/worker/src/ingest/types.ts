export type ConfidenceRating = "High" | "Medium-high" | "Medium" | "Low" | "Unverified" | "Disputed";
export type EmotionalLoad = "Low" | "Medium" | "Heavy" | "Graphic / distressing";

export interface RawDiscoveredArticle {
  id: string;
  url: string;
  title: string;
  domain: string;
  language: string;
  sourceCountry: string;
  seenAt: string;
  imageUrl: string | null;
  topic: string;
  query: string;
  excerpt?: string | null;
}

export interface SourceRecord {
  id: string;
  name: string;
  type: string;
  region: string;
  url: string;
  publishedAt: string;
  framing: string;
  qualityScore?: number;
  qualityLabel?: string;
}

export interface SourceMix {
  wire: number;
  localRegional: number;
  official: number;
  ngo: number;
  primary: number;
  commentary: number;
  other: number;
  labels: string[];
}

export interface BriefingUpdateRecord {
  id: string;
  storyId: string | null;
  headline: string;
  region: string;
  category: string;
  whatChanged: string;
  whyItMatters: string;
  confidence: ConfidenceRating;
  emotionalLoad: EmotionalLoad;
  sourceCount: number;
  sourceTypes: string[];
  sourceMix: SourceMix;
  isCritical: boolean;
}

export interface BriefingUpdatesDocument {
  date: string;
  generatedAt: string;
  status: "meaningful-updates" | "no-major-updates";
  summary: string;
  updates: BriefingUpdateRecord[];
}

export interface RawDiscoverySnapshot {
  date: string;
  generatedAt: string;
  provider: string;
  window: "1h";
  queryCount: number;
  articleCount: number;
  articles: RawDiscoveredArticle[];
}
