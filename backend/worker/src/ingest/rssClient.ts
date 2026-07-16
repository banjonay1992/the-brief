import { inferTopic } from "./gdeltClient";
import type { RawDiscoveredArticle } from "./types";

interface RSSFeed {
  name: string;
  url: string;
  domain: string;
  sourceCountry: string;
  region: string;
  topicFallback: string;
}

export const CURATED_RSS_FEEDS: readonly RSSFeed[] = [
  {
    name: "BBC World",
    url: "https://feeds.bbci.co.uk/news/world/rss.xml",
    domain: "bbc.co.uk",
    sourceCountry: "United Kingdom",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "The Guardian World",
    url: "https://www.theguardian.com/world/rss",
    domain: "theguardian.com",
    sourceCountry: "United Kingdom",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "Al Jazeera",
    url: "https://www.aljazeera.com/xml/rss/all.xml",
    domain: "aljazeera.com",
    sourceCountry: "Qatar",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "France 24",
    url: "https://www.france24.com/en/rss",
    domain: "france24.com",
    sourceCountry: "France",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "Deutsche Welle",
    url: "https://rss.dw.com/rdf/rss-en-all",
    domain: "dw.com",
    sourceCountry: "Germany",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "NPR World",
    url: "https://feeds.npr.org/1004/rss.xml",
    domain: "npr.org",
    sourceCountry: "United States",
    region: "US",
    topicFallback: "World"
  },
  {
    name: "ABC Australia World",
    url: "https://www.abc.net.au/news/feed/51120/rss.xml",
    domain: "abc.net.au",
    sourceCountry: "Australia",
    region: "Asia-Pacific",
    topicFallback: "World"
  },
  {
    name: "Africanews",
    url: "https://www.africanews.com/feed/rss",
    domain: "africanews.com",
    sourceCountry: "Pan-African",
    region: "Africa",
    topicFallback: "Africa"
  },
  {
    name: "AllAfrica",
    url: "https://allafrica.com/tools/headlines/rdf/latest/headlines.rdf",
    domain: "allafrica.com",
    sourceCountry: "Pan-African",
    region: "Africa",
    topicFallback: "Africa"
  },
  {
    name: "The Hindu International",
    url: "https://www.thehindu.com/news/international/feeder/default.rss",
    domain: "thehindu.com",
    sourceCountry: "India",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "South China Morning Post World",
    url: "https://www.scmp.com/rss/91/feed",
    domain: "scmp.com",
    sourceCountry: "Hong Kong",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Euronews",
    url: "https://www.euronews.com/rss?level=theme&name=news",
    domain: "euronews.com",
    sourceCountry: "Europe",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "Sky News World",
    url: "https://feeds.skynews.com/feeds/rss/world.xml",
    domain: "news.sky.com",
    sourceCountry: "United Kingdom",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "RFI English",
    url: "https://www.rfi.fr/en/rss",
    domain: "rfi.fr",
    sourceCountry: "France",
    region: "Europe",
    topicFallback: "World"
  },
  {
    name: "Middle East Eye",
    url: "https://www.middleeasteye.net/rss",
    domain: "middleeasteye.net",
    sourceCountry: "United Kingdom",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "Channel NewsAsia World",
    url: "https://www.channelnewsasia.com/api/v1/rss-outbound-feed?_format=xml&category=6311",
    domain: "channelnewsasia.com",
    sourceCountry: "Singapore",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Arab News",
    url: "https://www.arabnews.com/rss.xml",
    domain: "arabnews.com",
    sourceCountry: "Saudi Arabia",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "NDTV World",
    url: "https://feeds.feedburner.com/ndtvnews-world-news",
    domain: "ndtv.com",
    sourceCountry: "India",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Times of India World",
    url: "https://timesofindia.indiatimes.com/rssfeeds/296589292.cms",
    domain: "timesofindia.indiatimes.com",
    sourceCountry: "India",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Nikkei Asia",
    url: "https://asia.nikkei.com/rss/feed/nar",
    domain: "asia.nikkei.com",
    sourceCountry: "Japan",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Japan Today",
    url: "https://japantoday.com/feed",
    domain: "japantoday.com",
    sourceCountry: "Japan",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "UN News",
    url: "https://news.un.org/feed/subscribe/en/news/all/rss.xml",
    domain: "news.un.org",
    sourceCountry: "International",
    region: "International",
    topicFallback: "Humanitarian"
  },
  {
    name: "PBS NewsHour World",
    url: "https://www.pbs.org/newshour/feeds/rss/world",
    domain: "pbs.org",
    sourceCountry: "United States",
    region: "US",
    topicFallback: "World"
  },
  {
    name: "CBS News World",
    url: "https://www.cbsnews.com/latest/rss/world",
    domain: "cbsnews.com",
    sourceCountry: "United States",
    region: "US",
    topicFallback: "World"
  },
  {
    name: "CNN World",
    url: "http://rss.cnn.com/rss/edition_world.rss",
    domain: "cnn.com",
    sourceCountry: "United States",
    region: "US",
    topicFallback: "World"
  },
  {
    name: "VOA News",
    url: "https://www.voanews.com/api/epiqq",
    domain: "voanews.com",
    sourceCountry: "United States",
    region: "US",
    topicFallback: "World"
  },
  {
    name: "Anadolu Agency World",
    url: "https://www.aa.com.tr/en/rss/default?cat=world",
    domain: "aa.com.tr",
    sourceCountry: "Turkey",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "TRT World",
    url: "https://www.trtworld.com/rss",
    domain: "trtworld.com",
    sourceCountry: "Turkey",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "The National",
    url: "https://www.thenationalnews.com/arc/outboundfeeds/rss/?outputType=xml",
    domain: "thenationalnews.com",
    sourceCountry: "United Arab Emirates",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "Times of Israel",
    url: "https://www.timesofisrael.com/feed/",
    domain: "timesofisrael.com",
    sourceCountry: "Israel",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "Jerusalem Post",
    url: "https://www.jpost.com/Rss/RssFeedsHeadlines.aspx",
    domain: "jpost.com",
    sourceCountry: "Israel",
    region: "Middle East",
    topicFallback: "World"
  },
  {
    name: "Xinhua World",
    url: "https://english.news.cn/rss/world.xml",
    domain: "english.news.cn",
    sourceCountry: "China",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Global Times World",
    url: "https://www.globaltimes.cn/rss/World.xml",
    domain: "globaltimes.cn",
    sourceCountry: "China",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "NHK World",
    url: "https://www3.nhk.or.jp/nhkworld/en/news/rss.xml",
    domain: "www3.nhk.or.jp",
    sourceCountry: "Japan",
    region: "Asia",
    topicFallback: "World"
  },
  {
    name: "Mexico News Daily",
    url: "https://mexiconewsdaily.com/feed/",
    domain: "mexiconewsdaily.com",
    sourceCountry: "Mexico",
    region: "Latin America",
    topicFallback: "World"
  },
  {
    name: "Buenos Aires Times",
    url: "https://www.batimes.com.ar/feed",
    domain: "batimes.com.ar",
    sourceCountry: "Argentina",
    region: "Latin America",
    topicFallback: "World"
  },
  {
    name: "The Rio Times",
    url: "https://www.riotimesonline.com/feed/",
    domain: "riotimesonline.com",
    sourceCountry: "Brazil",
    region: "Latin America",
    topicFallback: "World"
  },
  {
    name: "Daily Maverick",
    url: "https://www.dailymaverick.co.za/dmrss/",
    domain: "dailymaverick.co.za",
    sourceCountry: "South Africa",
    region: "Africa",
    topicFallback: "World"
  },
  {
    name: "Punch Nigeria",
    url: "https://punchng.com/feed/",
    domain: "punchng.com",
    sourceCountry: "Nigeria",
    region: "Africa",
    topicFallback: "World"
  },
  {
    name: "Ahram Online",
    url: "https://english.ahram.org.eg/RSS.aspx?ID=1",
    domain: "english.ahram.org.eg",
    sourceCountry: "Egypt",
    region: "Africa",
    topicFallback: "World"
  }
];

const MAX_RSS_BYTES = 1_000_000;

export async function fetchCuratedRSSArticles(fetcher: typeof fetch = fetch): Promise<RawDiscoveredArticle[]> {
  const batches: RawDiscoveredArticle[][] = [];
  for (const feed of CURATED_RSS_FEEDS) {
    try {
      batches.push(await fetchRSSFeed(feed, fetcher));
    } catch (error) {
      console.warn(JSON.stringify({
        level: "warn",
        event: "rss-feed-skipped",
        feed: feed.name,
        message: errorMessage(error)
      }));
    }
  }
  return balancedArticles(dedupeArticles(batches.flat()), 240);
}

async function fetchRSSFeed(feed: RSSFeed, fetcher: typeof fetch): Promise<RawDiscoveredArticle[]> {
  const response = await fetcher(feed.url, {
    headers: { accept: "application/rss+xml, application/xml, text/xml" }
  });
  if (!response.ok) {
    throw new Error(`RSS fetch failed: ${response.status}`);
  }

  const contentLength = Number(response.headers.get("content-length") ?? "0");
  if (contentLength > MAX_RSS_BYTES) {
    throw new Error(`RSS feed too large: ${contentLength}`);
  }

  const xml = await response.text();
  if (xml.length > MAX_RSS_BYTES) {
    throw new Error(`RSS feed too large: ${xml.length}`);
  }

  return extractRSSItems(xml).slice(0, 18).map((item) => ({
    id: articleId(item.link),
    url: item.link,
    title: item.title,
    domain: feed.domain,
    language: "English",
    sourceCountry: feed.sourceCountry,
    seenAt: item.pubDate,
    imageUrl: null,
    topic: inferTopic(item.title, feed.topicFallback),
    query: `feed:${feed.url}`,
    excerpt: item.description
  }));
}

function balancedArticles(articles: RawDiscoveredArticle[], limit: number): RawDiscoveredArticle[] {
  const byFeed = new Map<string, RawDiscoveredArticle[]>();
  for (const article of articles) {
    byFeed.set(article.query, [...(byFeed.get(article.query) ?? []), article]);
  }

  const selected: RawDiscoveredArticle[] = [];
  let round = 0;
  while (selected.length < limit) {
    let added = 0;
    for (const batch of byFeed.values()) {
      const article = batch[round];
      if (article) {
        selected.push(article);
        added += 1;
        if (selected.length >= limit) {
          break;
        }
      }
    }
    if (added === 0) {
      break;
    }
    round += 1;
  }
  return selected;
}

function extractRSSItems(xml: string): Array<{ title: string; link: string; pubDate: string; description: string | null }> {
  const items = [...xml.matchAll(/<item\b[^>]*>([\s\S]*?)<\/item>/gi)];
  return items
    .map((match) => {
      const body = match[1] ?? "";
      const publishedAt = cleanXMLText(
        extractTag(body, "pubDate") || extractTag(body, "dc:date") || extractTag(body, "updated")
      );
      const description = cleanXMLText(
        extractTag(body, "description") ||
        extractTag(body, "content:encoded") ||
        extractTag(body, "summary")
      );
      return {
        title: cleanXMLText(extractTag(body, "title")),
        link: cleanXMLText(extractTag(body, "link")),
        pubDate: parseRSSDate(publishedAt),
        description: description.length > 0 ? trimText(description, 520) : null
      };
    })
    .filter((item) => item.title.length > 0 && item.link.startsWith("http"));
}

function extractTag(xml: string, tag: string): string {
  const match = xml.match(new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i"));
  return match?.[1] ?? "";
}

function cleanXMLText(value: string): string {
  return normalizeTitleSpacing(
    decodeEntities(value.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]+>/g, ""))
  );
}

function trimText(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }
  const clipped = value.slice(0, maxLength - 1);
  const lastSentence = Math.max(clipped.lastIndexOf("."), clipped.lastIndexOf(";"), clipped.lastIndexOf(","));
  if (lastSentence > 180) {
    return clipped.slice(0, lastSentence + 1).trim();
  }
  const lastSpace = clipped.lastIndexOf(" ");
  return `${clipped.slice(0, lastSpace > 120 ? lastSpace : clipped.length).trim()}…`;
}

function decodeEntities(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/&#039;/g, "'")
    .replace(/&#x27;/gi, "'");
}

function parseRSSDate(value: string): string {
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return new Date().toISOString();
  }
  return new Date(timestamp).toISOString();
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

function articleId(url: string): string {
  return `rss_${hashString(url)}`;
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

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown error";
}
