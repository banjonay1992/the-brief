import { inferTopic } from "./gdeltClient";
import type { RawDiscoveredArticle } from "./types";

const RELIEFWEB_REPORTS_URL = "https://api.reliefweb.int/v2/reports";

interface ReliefWebResponse {
  data?: ReliefWebItem[];
}

interface ReliefWebItem {
  id?: string;
  fields?: {
    title?: string;
    url?: string;
    date?: {
      created?: string;
    };
    source?: Array<{
      name?: string;
    }>;
    primary_country?: Array<{
      name?: string;
    }>;
    theme?: Array<{
      name?: string;
    }>;
  };
}

export async function fetchReliefWebReports(
  appName: string | undefined,
  fetcher: typeof fetch = fetch
): Promise<RawDiscoveredArticle[]> {
  const approvedAppName = appName?.trim();
  if (!approvedAppName) {
    return [];
  }

  const url = new URL(RELIEFWEB_REPORTS_URL);
  url.searchParams.set("appname", approvedAppName);

  const response = await fetcher(url.toString(), {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json"
    },
    body: JSON.stringify({
      limit: 25,
      sort: ["date.created:desc"],
      fields: {
        include: ["title", "url", "date.created", "source.name", "primary_country.name", "theme.name"]
      }
    })
  });

  if (response.status === 403) {
    console.warn(JSON.stringify({
      level: "warn",
      event: "reliefweb-skipped",
      message: "ReliefWeb appname is not approved."
    }));
    return [];
  }

  if (!response.ok) {
    throw new Error(`ReliefWeb query failed: ${response.status}`);
  }

  const payload = await response.json() as ReliefWebResponse;
  return (payload.data ?? [])
    .map(normalizeReliefWebItem)
    .filter((article): article is RawDiscoveredArticle => article !== null);
}

function normalizeReliefWebItem(item: ReliefWebItem): RawDiscoveredArticle | null {
  const fields = item.fields;
  if (!item.id || !fields?.title || !fields.url || !fields.date?.created) {
    return null;
  }

  const country = fields.primary_country?.[0]?.name ?? "International";
  const sourceName = fields.source?.[0]?.name ?? "ReliefWeb";
  const themes = (fields.theme ?? []).map((theme) => theme.name).filter((name): name is string => Boolean(name));
  const topicContext = `${fields.title} ${themes.join(" ")}`;

  return {
    id: `reliefweb_${item.id}`,
    url: fields.url,
    title: cleanTitle(fields.title),
    domain: "reliefweb.int",
    language: "English",
    sourceCountry: country,
    seenAt: parseReliefWebDate(fields.date.created),
    imageUrl: null,
    topic: inferTopic(topicContext, "Humanitarian"),
    query: `reliefweb:${sourceName}`,
    excerpt: themes.length > 0 ? `Themes: ${themes.join(", ")}. Primary country: ${country}. Source: ${sourceName}.` : `Primary country: ${country}. Source: ${sourceName}.`
  };
}

function parseReliefWebDate(value: string): string {
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return new Date(0).toISOString();
  }
  return new Date(timestamp).toISOString();
}

function cleanTitle(title: string): string {
  return title.replace(/\s+/g, " ").trim();
}
