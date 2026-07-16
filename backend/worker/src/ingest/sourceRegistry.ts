import type { RawDiscoveredArticle, SourceMix, SourceRecord } from "./types";

type SourceMixKey = Exclude<keyof SourceMix, "labels">;

interface SourceProfile {
  domains: readonly string[];
  name: string;
  type: string;
  region: string;
  framing: string;
  mixKey: SourceMixKey;
}

export interface SourceQuality {
  score: number;
  label: string;
}

const SOURCE_PROFILES: readonly SourceProfile[] = [
  {
    domains: ["reuters.com"],
    name: "Reuters",
    type: "wire",
    region: "International",
    framing: "International wire framing; useful for event confirmation, not automatically neutral.",
    mixKey: "wire"
  },
  {
    domains: ["apnews.com"],
    name: "Associated Press",
    type: "wire",
    region: "International",
    framing: "International wire framing; useful for event confirmation, not automatically neutral.",
    mixKey: "wire"
  },
  {
    domains: ["afp.com"],
    name: "Agence France-Presse",
    type: "wire",
    region: "International",
    framing: "International wire framing; useful for event confirmation, not automatically neutral.",
    mixKey: "wire"
  },
  {
    domains: ["bbc.co.uk"],
    name: "BBC",
    type: "local/regional",
    region: "United Kingdom",
    framing: "UK public-broadcaster framing; useful for broad confirmation, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["theguardian.com"],
    name: "The Guardian",
    type: "local/regional",
    region: "United Kingdom",
    framing: "UK newsroom framing; useful for broad context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["aljazeera.com"],
    name: "Al Jazeera",
    type: "local/regional",
    region: "Qatar / Middle East",
    framing: "Qatar-based international newsroom framing; useful for Middle East and Global South perspectives, still checked against local, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["france24.com"],
    name: "France 24",
    type: "local/regional",
    region: "France / Europe",
    framing: "French international broadcaster framing; useful for European and francophone context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["dw.com"],
    name: "Deutsche Welle",
    type: "local/regional",
    region: "Germany / Europe",
    framing: "German international broadcaster framing; useful for European context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["npr.org"],
    name: "NPR",
    type: "local/regional",
    region: "United States",
    framing: "US public-radio framing; useful for US and international reporting, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["abc.net.au"],
    name: "ABC Australia",
    type: "local/regional",
    region: "Australia / Asia-Pacific",
    framing: "Australian public-broadcaster framing; useful for Asia-Pacific context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["africanews.com"],
    name: "Africanews",
    type: "local/regional",
    region: "Africa",
    framing: "Pan-African newsroom framing; useful for regional context and affected-area perspectives, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["allafrica.com"],
    name: "AllAfrica",
    type: "local/regional",
    region: "Africa",
    framing: "Pan-African aggregation and newsroom framing; useful for regional source discovery, still checked against original reporting and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["thehindu.com"],
    name: "The Hindu",
    type: "local/regional",
    region: "India / Asia",
    framing: "Indian newsroom framing; useful for South Asian context, still checked against local, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["scmp.com"],
    name: "South China Morning Post",
    type: "local/regional",
    region: "Hong Kong / Asia",
    framing: "Hong Kong newsroom framing; useful for China and Asia-Pacific context, still checked against local, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["euronews.com"],
    name: "Euronews",
    type: "local/regional",
    region: "Europe",
    framing: "European international newsroom framing; useful for continental context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["news.sky.com", "sky.com"],
    name: "Sky News",
    type: "local/regional",
    region: "United Kingdom",
    framing: "UK commercial-news framing; useful for fast international coverage, still checked against local, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["rfi.fr"],
    name: "RFI",
    type: "local/regional",
    region: "France / Francophone world",
    framing: "French international radio framing; useful for francophone, African, and diplomatic context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["middleeasteye.net"],
    name: "Middle East Eye",
    type: "local/regional",
    region: "Middle East / North Africa",
    framing: "Middle East-focused newsroom framing; useful for regional and affected-population perspectives, still checked against primary and opposing-side sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["channelnewsasia.com"],
    name: "Channel NewsAsia",
    type: "local/regional",
    region: "Singapore / Asia",
    framing: "Singapore-based regional newsroom framing; useful for Asia-Pacific context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["arabnews.com"],
    name: "Arab News",
    type: "local/regional",
    region: "Saudi Arabia / Middle East",
    framing: "Saudi-based regional newsroom framing; useful for Gulf and Middle East context, still checked against local, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["ndtv.com"],
    name: "NDTV",
    type: "local/regional",
    region: "India / Asia",
    framing: "Indian newsroom framing; useful for South Asian context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["timesofindia.indiatimes.com", "indiatimes.com"],
    name: "Times of India",
    type: "local/regional",
    region: "India / Asia",
    framing: "Indian newsroom framing; useful for South Asian context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["asia.nikkei.com", "nikkei.com"],
    name: "Nikkei Asia",
    type: "local/regional",
    region: "Japan / Asia",
    framing: "Japan-based Asia business and regional-news framing; useful for economic and Asia-Pacific context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["japantoday.com"],
    name: "Japan Today",
    type: "local/regional",
    region: "Japan / Asia",
    framing: "Japan-based newsroom framing; useful for Japanese and Asia-Pacific context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["pbs.org"],
    name: "PBS NewsHour",
    type: "local/regional",
    region: "United States",
    framing: "US public-broadcast framing; useful for US and international context, still checked against local, primary, and affected-population sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["cbsnews.com"],
    name: "CBS News",
    type: "local/regional",
    region: "United States",
    framing: "US newsroom framing; useful for fast confirmation, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["cnn.com"],
    name: "CNN",
    type: "local/regional",
    region: "United States",
    framing: "US international-news framing; useful for broad coverage, still checked against local, primary, and non-US sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["voanews.com"],
    name: "Voice of America",
    type: "local/regional",
    region: "United States / International",
    framing: "US-funded international broadcaster framing; useful for global coverage but always checked against local and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["aa.com.tr"],
    name: "Anadolu Agency",
    type: "local/regional",
    region: "Turkey / Middle East",
    framing: "Turkey-based wire and regional-news framing; useful for regional context, still checked against local, primary, and opposing-side sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["trtworld.com"],
    name: "TRT World",
    type: "local/regional",
    region: "Turkey / Middle East",
    framing: "Turkey-based international broadcaster framing; useful for regional context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["thenationalnews.com"],
    name: "The National",
    type: "local/regional",
    region: "United Arab Emirates / Middle East",
    framing: "UAE-based regional newsroom framing; useful for Gulf and Middle East context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["timesofisrael.com"],
    name: "Times of Israel",
    type: "local/regional",
    region: "Israel / Middle East",
    framing: "Israel-based newsroom framing; useful for Israeli official, public, and security context, still checked against Palestinian, regional, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["jpost.com"],
    name: "Jerusalem Post",
    type: "local/regional",
    region: "Israel / Middle East",
    framing: "Israel-based newsroom framing; useful for Israeli political and security context, still checked against Palestinian, regional, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["english.news.cn", "news.cn"],
    name: "Xinhua",
    type: "official",
    region: "China / International",
    framing: "Chinese state-news framing; useful for official Chinese positions and source comparison, not treated as neutral fact.",
    mixKey: "primary"
  },
  {
    domains: ["globaltimes.cn"],
    name: "Global Times",
    type: "local/regional",
    region: "China / Asia",
    framing: "China-based state-affiliated framing; useful for Chinese official-adjacent perspectives, checked against local, primary, and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["www3.nhk.or.jp", "nhk.or.jp"],
    name: "NHK World",
    type: "local/regional",
    region: "Japan / Asia",
    framing: "Japan public-broadcaster framing; useful for Japan and Asia-Pacific context, still checked against local and primary sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["mexiconewsdaily.com"],
    name: "Mexico News Daily",
    type: "local/regional",
    region: "Mexico / Latin America",
    framing: "Mexico-focused newsroom framing; useful for local context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["batimes.com.ar"],
    name: "Buenos Aires Times",
    type: "local/regional",
    region: "Argentina / Latin America",
    framing: "Argentina-based newsroom framing; useful for local and regional context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["riotimesonline.com"],
    name: "The Rio Times",
    type: "local/regional",
    region: "Brazil / Latin America",
    framing: "Brazil-focused regional-news framing; useful for Latin America context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["dailymaverick.co.za"],
    name: "Daily Maverick",
    type: "local/regional",
    region: "South Africa / Africa",
    framing: "South Africa-based newsroom framing; useful for local and regional context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["punchng.com"],
    name: "Punch Nigeria",
    type: "local/regional",
    region: "Nigeria / Africa",
    framing: "Nigeria-based newsroom framing; useful for local and regional context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["english.ahram.org.eg"],
    name: "Ahram Online",
    type: "local/regional",
    region: "Egypt / Africa",
    framing: "Egypt-based newsroom framing; useful for Egypt, North Africa, and regional context, still checked against primary and independent sources.",
    mixKey: "localRegional"
  },
  {
    domains: ["news.un.org"],
    name: "UN News",
    type: "primary",
    region: "International",
    framing: "United Nations framing; useful for official UN positions and humanitarian context, not a substitute for independent verification.",
    mixKey: "primary"
  },
  {
    domains: ["reliefweb.int"],
    name: "ReliefWeb",
    type: "NGO",
    region: "International",
    framing: "Humanitarian information framing; useful for aid, displacement, and affected-population context.",
    mixKey: "ngo"
  },
  {
    domains: ["amnesty.org", "hrw.org", "crisisgroup.org"],
    name: "Human Rights / Conflict NGO",
    type: "NGO",
    region: "International",
    framing: "Human rights or conflict-analysis framing; useful for affected-population and legal-risk context.",
    mixKey: "ngo"
  },
  {
    domains: ["who.int"],
    name: "World Health Organization",
    type: "primary",
    region: "International",
    framing: "International public-health body framing; useful for official health guidance and primary health context.",
    mixKey: "primary"
  }
];

const OFFICIAL_HINTS = [".gov", ".mil", "mod.gov", "defense.gov", "mfa.gov"];
const OFFICIAL_OR_STATE_AFFILIATED_DOMAINS = new Set([
  "aa.com.tr",
  "english.news.cn",
  "globaltimes.cn",
  "news.cn",
  "trtworld.com",
  "voanews.com",
  "www3.nhk.or.jp"
]);

export function sourceIdForDomain(domain: string): string {
  return `source_${slugify(domain)}`;
}

export function sourceTypeForDomain(domain: string): string {
  const profile = sourceProfileForDomain(domain);
  if (profile) {
    return profile.type;
  }
  const normalized = normalizeDomain(domain);
  if (OFFICIAL_HINTS.some((hint) => normalized.includes(hint))) {
    return "official";
  }
  return "local/regional";
}

export function sourceQualityForDomain(domain: string): SourceQuality {
  const normalized = normalizeDomain(domain);
  const type = sourceTypeForDomain(normalized);
  if (OFFICIAL_OR_STATE_AFFILIATED_DOMAINS.has(normalized)) {
    return { score: 58, label: "Context source" };
  }
  if (type === "wire") {
    return { score: 90, label: "High contribution" };
  }
  if (type === "primary") {
    return { score: 88, label: "Primary evidence" };
  }
  if (type === "NGO") {
    return { score: 82, label: "Specialist context" };
  }
  if (type === "official") {
    return { score: 74, label: "Official claim source" };
  }
  if (sourceProfileForDomain(normalized)) {
    return { score: 76, label: "Useful corroboration" };
  }
  return { score: 50, label: "Early signal" };
}

export function sourceMixForArticles(articles: RawDiscoveredArticle[]): SourceMix {
  const mix: SourceMix = {
    wire: 0,
    localRegional: 0,
    official: 0,
    ngo: 0,
    primary: 0,
    commentary: 0,
    other: 0,
    labels: []
  };
  const labels = new Set<string>();

  for (const domain of new Set(articles.map((article) => normalizeDomain(article.domain)))) {
    const key = sourceMixKeyForDomain(domain);
    mix[key] += 1;
    labels.add(sourceTypeForDomain(domain));
  }

  mix.labels = [...labels].sort((left, right) => sourceMixOrder(left) - sourceMixOrder(right) || left.localeCompare(right));
  return mix;
}

export function sourceRecordForArticle(article: {
  domain: string;
  sourceCountry: string;
  url: string;
  seenAt: string;
}): SourceRecord {
  const domain = normalizeDomain(article.domain);
  const profile = sourceProfileForDomain(domain);
  const type = profile?.type ?? sourceTypeForDomain(domain);
  const quality = sourceQualityForDomain(domain);
  return {
    id: sourceIdForDomain(domain),
    name: profile?.name ?? displayNameForDomain(domain),
    type,
    region: (profile?.region ?? article.sourceCountry) || "Unknown",
    url: `https://${domain}`,
    publishedAt: article.seenAt,
    framing: profile?.framing ?? framingForSourceType(type, article.sourceCountry),
    qualityScore: quality.score,
    qualityLabel: quality.label
  };
}

function sourceMixKeyForDomain(domain: string): SourceMixKey {
  const profile = sourceProfileForDomain(domain);
  if (profile) {
    return profile.mixKey;
  }
  const normalized = normalizeDomain(domain);
  if (OFFICIAL_HINTS.some((hint) => normalized.includes(hint))) {
    return "official";
  }
  return "localRegional";
}

function sourceProfileForDomain(domain: string): SourceProfile | undefined {
  const normalized = normalizeDomain(domain);
  return SOURCE_PROFILES.find((profile) => profile.domains.some((profileDomain) => normalized === profileDomain || normalized.endsWith(`.${profileDomain}`)));
}

function framingForSourceType(type: string, sourceCountry: string): string {
  switch (type) {
    case "wire":
      return "International wire framing; useful for event confirmation, not automatically neutral.";
    case "NGO":
      return "Human rights or humanitarian framing; useful for affected-population and legal-risk context.";
    case "official":
      return "Official-source framing; claims must be attributed and independently checked.";
    default:
      return `${sourceCountry || "Local"} regional framing; useful for local context and affected-area perspective.`;
  }
}

function sourceMixOrder(label: string): number {
  switch (label) {
    case "wire":
      return 1;
    case "local/regional":
      return 2;
    case "official":
      return 3;
    case "primary":
      return 4;
    case "NGO":
      return 5;
    case "analysis":
      return 6;
    default:
      return 7;
  }
}

function displayNameForDomain(domain: string): string {
  return domain
    .replace(/^www\./, "")
    .split(".")[0]
    .split("-")
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}

function normalizeDomain(domain: string): string {
  return domain.trim().toLowerCase().replace(/^www\./, "");
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}
