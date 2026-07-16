import { describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { runHourlyNewsPipeline } from "../src/ingest/pipeline";
import { fetchHourlyGDELTArticles, HOURLY_DISCOVERY_QUERIES, inferTopic, parseGDELTDate } from "../src/ingest/gdeltClient";
import { fetchReliefWebReports } from "../src/ingest/reliefWebClient";
import { CURATED_RSS_FEEDS, fetchCuratedRSSArticles } from "../src/ingest/rssClient";
import { sourceMixForArticles, sourceQualityForDomain, sourceTypeForDomain } from "../src/ingest/sourceRegistry";
import { buildBriefingDocument, buildStoryDetailsFromArticles } from "../src/ingest/briefingBuilder";
import { enhanceBriefingWithOpenAI } from "../src/ingest/openAISynthesizer";
import { buildUpdatesDocument } from "../src/ingest/updateBuilder";
import { briefing, calmUpdates, story, userPreferences } from "../src/mockData";

class MemoryR2Bucket implements R2Bucket {
  constructor(private readonly objects: Map<string, string> = new Map()) {}

  async head(_key: string): Promise<R2Object | null> {
    return null;
  }

  get(key: string, options: R2GetOptions & { onlyIf: R2Conditional | Headers }): Promise<R2ObjectBody | R2Object | null>;
  get(key: string, options?: R2GetOptions): Promise<R2ObjectBody | null>;
  async get(key: string): Promise<R2ObjectBody | null> {
    const value = this.objects.get(key);
    if (!value) {
      return null;
    }

    const response = new Response(value, {
      headers: { etag: `"${key}"` }
    });
    return {
      body: response.body,
      bodyUsed: false,
      arrayBuffer: () => response.arrayBuffer(),
      bytes: () => response.bytes(),
      text: () => response.text(),
      json: () => response.json(),
      blob: () => response.blob(),
      key,
      version: "test-version",
      size: value.length,
      etag: key,
      httpEtag: `"${key}"`,
      uploaded: new Date("2026-05-17T00:00:00Z"),
      httpMetadata: {},
      customMetadata: {},
      range: undefined,
      checksums: {},
      writeHttpMetadata(headers: Headers) {
        headers.set("etag", `"${key}"`);
      }
    } as R2ObjectBody;
  }

  put(
    key: string,
    value: ReadableStream | ArrayBuffer | ArrayBufferView | string | null | Blob,
    options?: R2PutOptions & { onlyIf: R2Conditional | Headers }
  ): Promise<R2Object | null>;
  put(
    key: string,
    value: ReadableStream | ArrayBuffer | ArrayBufferView | string | null | Blob,
    options?: R2PutOptions
  ): Promise<R2Object>;
  async put(
    key: string,
    value: ReadableStream | ArrayBuffer | ArrayBufferView | string | null | Blob,
    _options?: R2PutOptions
  ): Promise<R2Object> {
    const stringValue = typeof value === "string" ? value : "";
    this.objects.set(key, stringValue);
    return {
      key,
      version: "test-version",
      size: stringValue.length,
      etag: key,
      httpEtag: `"${key}"`,
      uploaded: new Date("2026-05-17T00:00:00Z"),
      httpMetadata: {},
      customMetadata: {},
      range: undefined,
      checksums: {},
      writeHttpMetadata(headers: Headers) {
        headers.set("etag", `"${key}"`);
      }
    } as R2Object;
  }

  async createMultipartUpload(): Promise<R2MultipartUpload> {
    throw new Error("MemoryR2Bucket.createMultipartUpload is not implemented for these route tests.");
  }

  resumeMultipartUpload(): R2MultipartUpload {
    throw new Error("MemoryR2Bucket.resumeMultipartUpload is not implemented for these route tests.");
  }

  delete(keys: string | string[]): Promise<void>;
  async delete(keys?: string | string[]): Promise<void> {
    if (typeof keys === "string") {
      this.objects.delete(keys);
      return;
    }
    keys?.forEach((key) => this.objects.delete(key));
  }

  async list(): Promise<R2Objects> {
    throw new Error("MemoryR2Bucket.list is not implemented for these route tests.");
  }
}

function executionContext(promises: Promise<unknown>[] = []): ExecutionContext {
  return {
  waitUntil(promise: Promise<unknown>) {
    promises.push(promise);
  },
  passThroughOnException() {}
  } as ExecutionContext;
}

function envWith(objects?: Map<string, string>, extraEnv: Record<string, string> = {}): Env {
  return {
    SIGNAL_DAILY_R2: new MemoryR2Bucket(objects),
    SIGNAL_ENV: "development",
    OPENAI_MODEL: "gpt-5.4-nano",
    MAX_DAILY_STORIES: "120",
    MIN_HOURLY_NEW_STORIES: "5",
    OPENAI_SYNTHESIS_ENABLED: "NO",
    OPENAI_SYNTHESIS_STORY_LIMIT: "120",
    OPENAI_SYNTHESIS_BATCH_SIZE: "4",
    APPLE_NATIVE_CLIENT_ID: "com.signaldaily.app",
    APPLE_WEB_CLIENT_ID: "com.signaldaily.web",
    APPLE_WEB_REDIRECT_URI: "https://signal-daily-api.nathancoleasi.workers.dev/api/auth/apple/web/callback",
    ...extraEnv
  } as Env;
}

function unsignedAppleToken(claims: Record<string, unknown>): string {
  return [
    base64URL(JSON.stringify({ alg: "none" })),
    base64URL(JSON.stringify(claims)),
    "signature"
  ].join(".");
}

function base64URL(value: string): string {
  return btoa(value).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

describe("Signal Daily Worker API", () => {
  it("serves today briefing from mock fallback when R2 is empty", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/briefings/today"),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("x-signal-source")).toBe("mock-fallback");
    await expect(response.json()).resolves.toMatchObject({ title: briefing.title });
  });

  it("streams R2 article JSON when present", async () => {
    const objects = new Map([["articles/story_001.json", JSON.stringify(story)]]);
    const response = await worker.fetch(
      new Request("http://local.test/api/articles/story_001"),
      envWith(objects),
      executionContext()
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("x-signal-source")).toBe("r2");
    await expect(response.json()).resolves.toMatchObject({ headline: story.headline });
  });

  it("persists posted user preferences in R2", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    const response = await worker.fetch(
      new Request("http://local.test/api/users/preferences", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(userPreferences)
      }),
      env,
      executionContext()
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ maxStories: 20 });

    const getResponse = await worker.fetch(
      new Request("http://local.test/api/users/preferences"),
      env,
      executionContext()
    );
    await expect(getResponse.json()).resolves.toMatchObject({ maxStories: 20 });
    expect(objects.get("users/preferences/default.json")).toBeDefined();
  });

  it("persists depth-token use for the current day", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);

    const firstUse = await worker.fetch(
      new Request("http://local.test/api/depth-tokens/use", { method: "POST" }),
      env,
      executionContext()
    );
    const secondUse = await worker.fetch(
      new Request("http://local.test/api/depth-tokens/use", { method: "POST" }),
      env,
      executionContext()
    );

    await expect(firstUse.json()).resolves.toMatchObject({ remaining: 2 });
    await expect(secondUse.json()).resolves.toMatchObject({ remaining: 1 });
  });

  it("returns depth token status after use", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/depth-tokens/use", { method: "POST" }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ allowedPerDay: 3, remaining: 2 });
  });

  it("hides the admin pipeline trigger when no token is configured", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/admin/pipeline/run", { method: "POST" }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(404);
  });

  it("rejects the admin pipeline trigger without the configured token", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/admin/pipeline/run", { method: "POST" }),
      envWith(undefined, { PIPELINE_ADMIN_TOKEN: "test-admin-token" }),
      executionContext()
    );

    expect(response.status).toBe(401);
  });

  it("runs the live pipeline from the protected admin trigger", async () => {
    const objects = new Map<string, string>();
    const today = new Date().toISOString().slice(0, 10);
    const gdeltDate = today.replace(/-/g, "");
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = String(input);
      if (url.includes("api.gdeltproject.org")) {
        return new Response(JSON.stringify({
          articles: [
            {
              url: "https://reuters.com/world/test-refresh",
              title: "Global leaders resume ceasefire talks after overnight strikes",
              seendate: `${gdeltDate}T123000Z`,
              socialimage: "",
              domain: "reuters.com",
              language: "English",
              sourcecountry: "United Kingdom"
            }
          ]
        }), {
          headers: { "content-type": "application/json" }
        });
      }
      return new Response("<rss><channel></channel></rss>", {
        headers: { "content-type": "application/rss+xml", "content-length": "30" }
      });
    });

    try {
      const response = await worker.fetch(
        new Request("http://local.test/api/admin/pipeline/run", {
          method: "POST",
          headers: { authorization: "Bearer test-admin-token" }
        }),
        envWith(objects, { PIPELINE_ADMIN_TOKEN: "test-admin-token" }),
        executionContext()
      );

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toMatchObject({ ok: true, articleCount: 1 });
      expect(objects.get("pipeline/latest.json")).toContain("gdelt-doc");
      expect(objects.get(`briefings/${today}/global.json`)).toContain("Global leaders resume ceasefire talks");
    } finally {
      fetchMock.mockRestore();
    }
  });

  it("synthesizes and writes one protected briefing slice at a time", async () => {
    const objects = new Map<string, string>();
    objects.set("pipeline/latest.json", JSON.stringify({
      date: "2026-05-18",
      generatedAt: "2026-05-18T12:00:00.000Z",
      articleCount: 2
    }));
    objects.set("briefings/2026-05-18/global.json", JSON.stringify({
      date: "2026-05-18",
      title: "Today's Global Briefing",
      readingTimeMinutes: 4,
      emotionalLoad: "Medium",
      storyCount: 2,
      sections: [{
        id: "health",
        title: "Health",
        stories: [
          {
            id: "story_slice_one",
            rank: 1,
            headline: "Draft outbreak headline",
            region: "Africa",
            category: "Health",
            summary: "Draft summary",
            whyItMatters: "Draft reason",
            confidence: "Medium",
            emotionalLoad: "Medium",
            sourceCount: 1,
            imageId: null
          },
          {
            id: "story_slice_two",
            rank: 2,
            headline: "Leave this story alone",
            region: "World",
            category: "World",
            summary: "Untouched summary",
            whyItMatters: "Untouched reason",
            confidence: "Low",
            emotionalLoad: "Low",
            sourceCount: 1,
            imageId: null
          }
        ]
      }]
    }));
    objects.set("articles/story_slice_one.json", JSON.stringify({
      id: "story_slice_one",
      headline: "Draft outbreak headline",
      category: "Health",
      region: "Africa",
      whatHappened: "Draft summary",
      whyItMatters: "Draft reason",
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Medium", reason: "One source." },
      emotionalLoad: "Medium",
      sources: [{
        id: "source_slice_one",
        name: "Example",
        type: "local/regional",
        region: "Africa",
        url: "https://example.org/outbreak",
        publishedAt: "2026-05-18T12:00:00Z",
        framing: "Local report."
      }],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: "Draft outbreak headline",
        classification: "Plausible but unconfirmed",
        why: "One detected source."
      }
    }));
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({
      output_text: JSON.stringify({
        stories: [{
          id: "story_slice_one",
          headline: "Health officials expand Ebola monitoring in DR Congo",
          summary: "Health officials expanded monitoring in DR Congo after reported Ebola risk, with figures still attributed to current sources.",
          whyItMatters: "The response may affect clinical capacity and public guidance for communities already under pressure.",
          whatHappened: "A local report described expanded monitoring in DR Congo. The briefing keeps case figures attributed until primary evidence confirms them.",
          whatWeKnow: ["Monitoring expanded.", "Current reporting points to DR Congo."],
          whatIsUnclear: ["Case figures remain attributed.", "Further primary evidence may change confidence."],
          confidenceReason: "The story is plausible but needs corroboration from primary or additional local sources.",
          framingCheck: {
            westernMainstream: "May foreground outbreak risk.",
            localRegional: "May foreground local health capacity.",
            officialGovernment: "Official claims should remain attributed.",
            affectedPopulation: "Affected people may focus on access to treatment.",
            independentEvidence: "Independent evidence remains limited.",
            humanRightsNGO: null,
            opposingSide: null
          },
          additionalSources: [],
          sortPriority: 1
        }]
      })
    }), {
      headers: { "content-type": "application/json" }
    }));

    try {
      const response = await worker.fetch(
        new Request("http://local.test/api/admin/pipeline/synthesize?date=2026-05-18&storyIds=story_slice_one&offset=1&limit=1", {
          method: "POST",
          headers: { authorization: "Bearer test-admin-token" }
        }),
        envWith(objects, { PIPELINE_ADMIN_TOKEN: "test-admin-token", OPENAI_API_KEY: "test-key" }),
        executionContext()
      );

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toMatchObject({
        ok: true,
        processed: 1,
        total: 2,
        done: true,
        requestedStoryIDs: ["story_slice_one"],
        storyIDs: ["story_slice_one"]
      });
      expect(fetchMock).toHaveBeenCalledOnce();
      expect(objects.get("briefings/2026-05-18/global.json")).toContain("Health officials expand Ebola monitoring in DR Congo");
      expect(objects.get("briefings/2026-05-18/global.json")).toContain("Leave this story alone");
      expect(objects.get("articles/story_slice_one.json")).toContain("case figures attributed");
      expect(objects.get("pipeline/latest.json")).toContain("\"processed\":1");
    } finally {
      fetchMock.mockRestore();
    }
  });

  it("serves a protected Codex editorial queue without calling OpenAI", async () => {
    const objects = new Map<string, string>();
    objects.set("briefings/2026-05-18/global.json", JSON.stringify({
      date: "2026-05-18",
      title: "Today's Global Briefing",
      readingTimeMinutes: 4,
      emotionalLoad: "Medium",
      storyCount: 1,
      sections: [{
        id: "health",
        title: "Health",
        stories: [{
          id: "story_codex_one",
          rank: 1,
          headline: "Draft outbreak headline",
          region: "Africa",
          category: "Health",
          summary: "Draft summary",
          whyItMatters: "Draft reason",
          confidence: "Medium",
          emotionalLoad: "Medium",
          sourceCount: 2,
          imageId: null
        }]
      }]
    }));
    objects.set("articles/story_codex_one.json", JSON.stringify({
      id: "story_codex_one",
      headline: "Draft outbreak headline",
      category: "Health",
      region: "Africa",
      whatHappened: "Draft summary",
      whyItMatters: "Draft reason",
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Medium", reason: "One source." },
      emotionalLoad: "Medium",
      sources: [],
      sourceEvidence: [{
        sourceName: "Local Health Desk",
        title: "Draft outbreak headline",
        url: "https://example.org/health",
        excerpt: "Clinics expanded monitoring after a reported outbreak risk.",
        sourceCountry: "DR Congo"
      }],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: "Draft outbreak headline",
        classification: "Plausible but unconfirmed",
        why: "One detected source."
      }
    }));
    const fetchMock = vi.spyOn(globalThis, "fetch");

    try {
      const response = await worker.fetch(
        new Request("http://local.test/api/admin/editorial/queue?date=2026-05-18&limit=1", {
          headers: { authorization: "Bearer test-admin-token" }
        }),
        envWith(objects, { PIPELINE_ADMIN_TOKEN: "test-admin-token", OPENAI_API_KEY: "test-key" }),
        executionContext()
      );

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toMatchObject({
        ok: true,
        mode: "codex-editorial",
        selected: 1,
        stories: [{
          summary: { id: "story_codex_one" },
          sourceEvidence: [{
            excerpt: "Clinics expanded monitoring after a reported outbreak risk."
          }]
        }]
      });
      expect(fetchMock).not.toHaveBeenCalled();
    } finally {
      fetchMock.mockRestore();
    }
  });

  it("applies protected Codex editorial patches to briefing and article detail", async () => {
    const objects = new Map<string, string>();
    objects.set("pipeline/latest.json", JSON.stringify({ date: "2026-05-18" }));
    objects.set("briefings/2026-05-18/global.json", JSON.stringify({
      date: "2026-05-18",
      title: "Today's Global Briefing",
      readingTimeMinutes: 4,
      emotionalLoad: "Medium",
      storyCount: 1,
      sections: [{
        id: "health",
        title: "Health",
        stories: [{
          id: "story_codex_one",
          rank: 1,
          headline: "Draft outbreak headline",
          region: "Africa",
          category: "Health",
          summary: "Draft summary",
          whyItMatters: "Draft reason",
          confidence: "Medium",
          emotionalLoad: "Medium",
          sourceCount: 2,
          imageId: null
        }]
      }]
    }));
    objects.set("articles/story_codex_one.json", JSON.stringify({
      id: "story_codex_one",
      headline: "Draft outbreak headline",
      category: "Health",
      region: "Africa",
      whatHappened: "Draft summary",
      whyItMatters: "Draft reason",
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Medium", reason: "One source." },
      emotionalLoad: "Medium",
      sources: [],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: "Draft outbreak headline",
        classification: "Plausible but unconfirmed",
        why: "One detected source."
      }
    }));

    const response = await worker.fetch(
      new Request("http://local.test/api/admin/editorial/apply", {
        method: "POST",
        headers: {
          authorization: "Bearer test-admin-token",
          "content-type": "application/json"
        },
        body: JSON.stringify({
          date: "2026-05-18",
          stories: [{
            id: "story_codex_one",
            headline: "Health teams expand Ebola monitoring",
            summary: "<p>Clinics expanded monitoring after reported Ebola risk.</p>",
            whyItMatters: "The response may affect health capacity and public guidance.",
            whatHappened: "Local reporting described expanded monitoring while case figures remained attributed.",
            whatWeKnow: ["Monitoring expanded.", "Current reporting points to DR Congo."],
            whatIsUnclear: ["Case figures remain attributed."],
            confidenceReason: "Two sources support the broad event, but figures remain attributed.",
            framingCheck: {
              westernMainstream: "May foreground outbreak risk.",
              localRegional: "May foreground local health capacity.",
              officialGovernment: "Official claims should remain attributed.",
              affectedPopulation: "Affected people may focus on access to treatment.",
              independentEvidence: "Independent evidence remains limited.",
              humanRightsNGO: null,
              opposingSide: null
            },
            biasAuditNotes: ["Claims are attributed."]
          }]
        })
      }),
      envWith(objects, { PIPELINE_ADMIN_TOKEN: "test-admin-token" }),
      executionContext()
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      ok: true,
      mode: "codex-editorial",
      applied: 1,
      storyIDs: ["story_codex_one"]
    });
    expect(objects.get("briefings/2026-05-18/global.json")).toContain("Health teams expand Ebola monitoring");
    expect(objects.get("briefings/2026-05-18/global.json")).toContain("Clinics expanded monitoring after reported Ebola risk.");
    expect(objects.get("briefings/2026-05-18/global.json")).not.toContain("<p>");
    expect(objects.get("articles/story_codex_one.json")).toContain("Local reporting described expanded monitoring");
    expect(objects.get("pipeline/latest.json")).toContain("\"mode\":\"codex\"");
  });

  it("creates an account and returns a no-store session", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/signup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name: "Maya",
          email: "Maya@example.com",
          password: "quiet-news"
        })
      }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(201);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    await expect(response.json()).resolves.toMatchObject({
      user: { email: "maya@example.com", name: "Maya" }
    });
  });

  it("signs in and resolves the bearer session", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    await worker.fetch(
      new Request("http://local.test/api/auth/signup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name: "Maya",
          email: "maya@example.com",
          password: "quiet-news"
        })
      }),
      env,
      executionContext()
    );

    const signInResponse = await worker.fetch(
      new Request("http://local.test/api/auth/signin", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email: "maya@example.com",
          password: "quiet-news"
        })
      }),
      env,
      executionContext()
    );

    expect(signInResponse.status).toBe(200);
    const session = await signInResponse.json() as { token: string; user: { email: string } };
    expect(session.user.email).toBe("maya@example.com");

    const sessionResponse = await worker.fetch(
      new Request("http://local.test/api/auth/session", {
        headers: { authorization: `Bearer ${session.token}` }
      }),
      env,
      executionContext()
    );

    expect(sessionResponse.status).toBe(200);
    await expect(sessionResponse.json()).resolves.toMatchObject({ user: { email: "maya@example.com" } });
  });

  it("rejects weak sign-up requests", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/signup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name: "Maya",
          email: "not-an-email",
          password: "short"
        })
      }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ error: "Enter a valid email address." });
  });

  it("creates a session from Apple identity claims", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          identityToken: unsignedAppleToken({
            iss: "https://appleid.apple.com",
            aud: "com.signaldaily.app",
            sub: "apple-user-123",
            email: "reader@privaterelay.appleid.com",
            exp: Math.floor(Date.now() / 1000) + 600
          }),
          userIdentifier: "apple-user-123",
          name: "Maya Apple",
          email: "reader@privaterelay.appleid.com"
        })
      }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(201);
    await expect(response.json()).resolves.toMatchObject({
      user: { email: "reader@privaterelay.appleid.com", name: "Maya Apple" }
    });
  });

  it("moves an existing email account onto the Apple account path", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);

    await worker.fetch(
      new Request("http://local.test/api/auth/signup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name: "Nathan",
          email: "banjonay@icloud.com",
          password: "quiet-news"
        })
      }),
      env,
      executionContext()
    );

    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          identityToken: unsignedAppleToken({
            iss: "https://appleid.apple.com",
            aud: "com.signaldaily.app",
            sub: "apple-user-123",
            email: "banjonay@icloud.com",
            exp: Math.floor(Date.now() / 1000) + 600
          }),
          userIdentifier: "apple-user-123",
          name: "Nathan Apple",
          email: "banjonay@icloud.com"
        })
      }),
      env,
      executionContext()
    );

    expect(response.status).toBe(201);
    await expect(response.json()).resolves.toMatchObject({
      user: { email: "banjonay@icloud.com", name: "Nathan" }
    });
    expect(objects.get("users/banjonay%40icloud.com.json")).toBeUndefined();
    expect(objects.get("users/apple/apple-user-123.json")).toContain("\"passwordHash\":\"apple\"");
  });

  it("rejects Apple identity claims that do not match the credential user", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          identityToken: unsignedAppleToken({
            iss: "https://appleid.apple.com",
            aud: "com.signaldaily.app",
            sub: "different-user",
            exp: Math.floor(Date.now() / 1000) + 600
          }),
          userIdentifier: "apple-user-123"
        })
      }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(401);
  });

  it("verifies native Apple identity tokens against the hashed nonce from the request", async () => {
    const rawNonce = "raw-nonce-from-apple-request";
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          identityToken: unsignedAppleToken({
            iss: "https://appleid.apple.com",
            aud: "com.signaldaily.app",
            sub: "apple-user-with-nonce",
            email: "nonce@privaterelay.appleid.com",
            nonce: await sha256Hex(rawNonce),
            exp: Math.floor(Date.now() / 1000) + 600
          }),
          userIdentifier: "apple-user-with-nonce",
          name: "Nonce Reader",
          email: "nonce@privaterelay.appleid.com",
          rawNonce
        })
      }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(201);
    await expect(response.json()).resolves.toMatchObject({
      user: { email: "nonce@privaterelay.appleid.com", name: "Nonce Reader" }
    });
  });

  it("rejects native Apple identity tokens with a mismatched nonce", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          identityToken: unsignedAppleToken({
            iss: "https://appleid.apple.com",
            aud: "com.signaldaily.app",
            sub: "apple-user-with-bad-nonce",
            email: "badnonce@privaterelay.appleid.com",
            nonce: await sha256Hex("different-raw-nonce"),
            exp: Math.floor(Date.now() / 1000) + 600
          }),
          userIdentifier: "apple-user-with-bad-nonce",
          rawNonce: "raw-nonce-from-apple-request"
        })
      }),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toMatchObject({
      error: "Apple sign-in nonce could not be verified."
    });
  });

  it("starts a browser-based Apple authorization request", async () => {
    const objects = new Map<string, string>();
    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple/web/start", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ mode: "signUp" })
      }),
      envWith(objects, {
        APPLE_WEB_CLIENT_ID: "com.signaldaily.web",
        APPLE_WEB_REDIRECT_URI: "https://auth.example.com/api/auth/apple/web/callback"
      }),
      executionContext()
    );

    expect(response.status).toBe(200);
    const payload = await response.json() as { authorizationURL: string; state: string };
    const authorizationURL = new URL(payload.authorizationURL);
    expect(authorizationURL.origin).toBe("https://appleid.apple.com");
    expect(authorizationURL.searchParams.get("client_id")).toBe("com.signaldaily.web");
    expect(authorizationURL.searchParams.get("redirect_uri")).toBe("https://auth.example.com/api/auth/apple/web/callback");
    expect(authorizationURL.searchParams.get("response_type")).toBe("code id_token");
    expect(authorizationURL.searchParams.get("response_mode")).toBe("form_post");
    expect(objects.get(`auth/apple-web/states/${payload.state}.json`)).toContain("\"nonce\"");
  });

  it("creates a one-time app handoff from an Apple browser callback", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects, {
      APPLE_WEB_CLIENT_ID: "com.signaldaily.web",
      APPLE_WEB_REDIRECT_URI: "https://auth.example.com/api/auth/apple/web/callback"
    });

    const startResponse = await worker.fetch(
      new Request("http://local.test/api/auth/apple/web/start", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ mode: "signUp" })
      }),
      env,
      executionContext()
    );
    const start = await startResponse.json() as { state: string };
    const stateDocument = JSON.parse(objects.get(`auth/apple-web/states/${start.state}.json`) ?? "{}") as { nonce: string };
    const callbackBody = new URLSearchParams({
      state: start.state,
      code: "single-use-code",
      id_token: unsignedAppleToken({
        iss: "https://appleid.apple.com",
        aud: "com.signaldaily.web",
        sub: "apple-browser-user-123",
        email: "browser@privaterelay.appleid.com",
        nonce: stateDocument.nonce,
        exp: Math.floor(Date.now() / 1000) + 600
      }),
      user: JSON.stringify({
        email: "browser@privaterelay.appleid.com",
        name: { firstName: "Maya", lastName: "Browser" }
      })
    });

    const callbackResponse = await worker.fetch(
      new Request("http://local.test/api/auth/apple/web/callback", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: callbackBody.toString()
      }),
      env,
      executionContext()
    );

    expect(callbackResponse.status).toBe(303);
    const location = new URL(callbackResponse.headers.get("location") ?? "");
    expect(location.protocol).toBe("thebrief:");
    const handoff = location.searchParams.get("handoff") ?? "";
    expect(handoff).not.toBe("");

    const sessionResponse = await worker.fetch(
      new Request("http://local.test/api/auth/apple/web/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ handoffToken: handoff })
      }),
      env,
      executionContext()
    );

    expect(sessionResponse.status).toBe(200);
    await expect(sessionResponse.json()).resolves.toMatchObject({
      user: { email: "browser@privaterelay.appleid.com", name: "Maya Browser" }
    });
    expect(objects.get(`auth/apple-web/handoffs/${handoff}.json`)).toBeUndefined();
  });

  it("rejects browser Apple callbacks with a mismatched nonce", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects, {
      APPLE_WEB_CLIENT_ID: "com.signaldaily.web",
      APPLE_WEB_REDIRECT_URI: "https://auth.example.com/api/auth/apple/web/callback"
    });

    const startResponse = await worker.fetch(
      new Request("http://local.test/api/auth/apple/web/start", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ mode: "signIn" })
      }),
      env,
      executionContext()
    );
    const start = await startResponse.json() as { state: string };
    const callbackBody = new URLSearchParams({
      state: start.state,
      code: "single-use-code",
      id_token: unsignedAppleToken({
        iss: "https://appleid.apple.com",
        aud: "com.signaldaily.web",
        sub: "apple-browser-user-123",
        nonce: "wrong-nonce",
        exp: Math.floor(Date.now() / 1000) + 600
      })
    });

    const response = await worker.fetch(
      new Request("http://local.test/api/auth/apple/web/callback", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: callbackBody.toString()
      }),
      env,
      executionContext()
    );

    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toContain("error=invalid_nonce");
  });

  it("serves today calm updates from mock fallback when R2 is empty", async () => {
    const response = await worker.fetch(
      new Request("http://local.test/api/briefings/today/updates"),
      envWith(),
      executionContext()
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("x-signal-source")).toBe("mock-fallback");
    await expect(response.json()).resolves.toMatchObject({ summary: calmUpdates.summary });
  });

  it("hourly pipeline writes raw discovery, updates, sources, and status to R2", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    const fetcher: typeof fetch = async () => new Response(JSON.stringify({
      articles: [
        {
          url: "https://example.org/conflict-report",
          title: "Ceasefire talks continue after revised statements",
          seendate: "20260518T123000Z",
          socialimage: "",
          domain: "example.org",
          language: "English",
          sourcecountry: "Lebanon"
        },
        {
          url: "https://reuters.com/world/climate-report",
          title: "Flood shelters expanded as water levels recede",
          seendate: "20260518T121500Z",
          socialimage: "",
          domain: "reuters.com",
          language: "English",
          sourcecountry: "Kenya"
        }
      ]
    }), {
      headers: { "content-type": "application/json" }
    });

    const result = await runHourlyNewsPipeline(env, new Date("2026-05-18T12:30:00Z"), fetcher);

    expect(result.articleCount).toBe(2);
    expect(result.updateCount).toBeGreaterThan(0);
    expect(objects.get("raw/2026-05-18/gdelt/12.json")).toBeDefined();
    expect(objects.get("briefings/2026-05-18/global.json")).toBeDefined();
    expect(objects.get("briefings/2026-05-18/updates.json")).toBeDefined();
    expect(objects.get("pipeline/latest.json")).toBeDefined();
    expect(objects.get("sources/source_reuters_com.json")).toBeDefined();
    expect([...objects.keys()].some((key) => key.startsWith("articles/story_"))).toBe(true);
    expect(objects.get("briefings/2026-05-18/updates.json")).toContain("\"sourceMix\"");
  });

  it("hourly pipeline falls back to curated RSS when GDELT is unavailable", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("api.gdeltproject.org")) {
        return new Response("discovery unavailable", { status: 418 });
      }
      return new Response(`
        <rss><channel>
          <item>
            <title><![CDATA[Flood shelters expanded as water levels recede]]></title>
            <link>https://feeds.example.org/flood-shelters</link>
            <pubDate>Mon, 18 May 2026 12:15:00 GMT</pubDate>
          </item>
        </channel></rss>
      `, {
        headers: { "content-type": "application/rss+xml", "content-length": "260" }
      });
    };

    const result = await runHourlyNewsPipeline(env, new Date("2026-05-18T12:30:00Z"), fetcher);

    expect(result.articleCount).toBeGreaterThan(0);
    expect(objects.get("raw/2026-05-18/gdelt/12.json")).toContain("curated-rss");
    expect(objects.get("briefings/2026-05-18/updates.json")).toContain("Flood shelters expanded");
  });

  it("hourly pipeline publishes only articles from the generated briefing date", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("api.gdeltproject.org")) {
        return new Response(JSON.stringify({
          articles: [
            {
              url: "https://reuters.com/world/today-story",
              title: "Kenya flood shelters expand after heavy rains",
              seendate: "20260518T121500Z",
              socialimage: "",
              domain: "reuters.com",
              language: "English",
              sourcecountry: "Kenya"
            },
            {
              url: "https://reuters.com/world/old-story",
              title: "Old summit item should not appear",
              seendate: "20260517T121500Z",
              socialimage: "",
              domain: "reuters.com",
              language: "English",
              sourcecountry: "United Kingdom"
            }
          ]
        }), {
          headers: { "content-type": "application/json" }
        });
      }
      return new Response("<rss><channel></channel></rss>", {
        headers: { "content-type": "application/rss+xml", "content-length": "30" }
      });
    };

    const result = await runHourlyNewsPipeline(env, new Date("2026-05-18T12:30:00Z"), fetcher);

    expect(result.articleCount).toBe(1);
    expect(objects.get("briefings/2026-05-18/global.json")).toContain("Kenya flood shelters");
    expect(objects.get("briefings/2026-05-18/global.json")).not.toContain("Old summit item");
  });

  it("hourly pipeline accumulates new same-day stories instead of replacing the feed", async () => {
    const objects = new Map<string, string>([[
      "briefings/2026-05-18/global.json",
      JSON.stringify({
        date: "2026-05-18",
        title: "Today's Global Briefing",
        readingTimeMinutes: 4,
        emotionalLoad: "Medium",
        storyCount: 1,
        sections: [{
          id: "world",
          title: "World",
          stories: [{
            id: "story_existing",
            rank: 1,
            publishedAt: "2026-05-18T08:00:00Z",
            expiresAt: "2026-05-21T08:00:00Z",
            headline: "Existing morning story remains available",
            region: "World",
            category: "World",
            summary: "Existing summary.",
            whyItMatters: "Existing context.",
            confidence: "Medium",
            emotionalLoad: "Low",
            sourceCount: 2,
            imageId: null
          }]
        }]
      })
    ]]);
    const env = envWith(objects);
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("api.gdeltproject.org")) {
        return new Response(JSON.stringify({
          articles: [
            "Kenya flood shelters expand after heavy rains",
            "Hospital capacity update draws local concern",
            "Central bank inflation decision affects household costs",
            "Battery research pilot expands grid storage",
            "Election monitors report calm regional turnout",
            "Humanitarian convoy access talks resume"
          ].map((title, index) => ({
            url: `https://example.org/hourly-story-${index}`,
            title,
            seendate: `20260518T12${index}000Z`,
            socialimage: "",
            domain: "example.org",
            language: "English",
            sourcecountry: "Kenya"
          }))
        }), {
          headers: { "content-type": "application/json" }
        });
      }
      return new Response("<rss><channel></channel></rss>", {
        headers: { "content-type": "application/rss+xml", "content-length": "30" }
      });
    };

    const result = await runHourlyNewsPipeline(env, new Date("2026-05-18T12:30:00Z"), fetcher);
    const briefingDocument = JSON.parse(objects.get("briefings/2026-05-18/global.json") ?? "{}");
    const latestStatus = JSON.parse(objects.get("pipeline/latest.json") ?? "{}");

    expect(result.newStoryCount).toBeGreaterThanOrEqual(5);
    expect(result.meetsMinimumNewStoriesTarget).toBe(true);
    expect(briefingDocument.storyCount).toBe(7);
    expect(objects.get("briefings/2026-05-18/global.json")).toContain("Existing morning story remains available");
    expect(latestStatus).toMatchObject({
      newStoryCount: 6,
      minimumNewStoriesTarget: 5,
      meetsMinimumNewStoriesTarget: true
    });
  });

  it("hourly pipeline keeps publishing when ReliefWeb is unavailable", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("reliefweb.int")) {
        return new Response("not acceptable", { status: 406 });
      }
      if (url.includes("api.gdeltproject.org")) {
        return new Response(JSON.stringify({
          articles: [
            {
              url: "https://africanews.com/test/story",
              title: "Kenya flood shelters expand as water recedes",
              seendate: "20260518T121500Z",
              socialimage: "",
              domain: "africanews.com",
              language: "English",
              sourcecountry: "Kenya"
            }
          ]
        }), {
          headers: { "content-type": "application/json" }
        });
      }
      return new Response("<rss><channel></channel></rss>", {
        headers: { "content-type": "application/rss+xml", "content-length": "30" }
      });
    };

    const result = await runHourlyNewsPipeline(env, new Date("2026-05-18T12:30:00Z"), fetcher);

    expect(result.articleCount).toBe(1);
    expect(objects.get("pipeline/latest.json")).toContain("gdelt-doc");
    expect(objects.get("briefings/2026-05-18/updates.json")).toContain("Kenya flood shelters");
  });

  it("scheduled cron runs the real hourly pipeline with mocked discovery fetch", async () => {
    const objects = new Map<string, string>();
    const env = envWith(objects);
    const pending: Promise<unknown>[] = [];
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => new Response(JSON.stringify({
      articles: [
        {
          url: "https://example.org/health-report",
          title: "Hospital capacity update draws local concern",
          seendate: "20260518T123000Z",
          socialimage: "",
          domain: "example.org",
          language: "English",
          sourcecountry: "Ireland"
        }
      ]
    }), {
      headers: { "content-type": "application/json" }
    });

    try {
      await worker.scheduled?.(
        {
          type: "scheduled",
          cron: "0 * * * *",
          scheduledTime: Date.parse("2026-05-18T12:30:00Z"),
          noRetry() {}
        } as ScheduledController,
        env,
        executionContext(pending)
      );
      await Promise.all(pending);
    } finally {
      globalThis.fetch = originalFetch;
    }

    expect(objects.get("briefings/2026-05-18/updates.json")).toBeDefined();
    expect(objects.get("pipeline/latest.json")).toContain("gdelt-doc");
  });

  it("normalizes GDELT dates and classifies known source types", () => {
    expect(parseGDELTDate("20260518T123000Z")).toBe("2026-05-18T12:30:00Z");
    expect(sourceTypeForDomain("reuters.com")).toBe("wire");
    expect(sourceTypeForDomain("news.un.org")).toBe("primary");
    expect(sourceTypeForDomain("reliefweb.int")).toBe("NGO");
    expect(sourceTypeForDomain("aljazeera.com")).toBe("local/regional");
    expect(sourceTypeForDomain("africanews.com")).toBe("local/regional");
    expect(sourceTypeForDomain("thehindu.com")).toBe("local/regional");
    expect(sourceTypeForDomain("scmp.com")).toBe("local/regional");
    expect(sourceTypeForDomain("middleeasteye.net")).toBe("local/regional");
    expect(sourceTypeForDomain("channelnewsasia.com")).toBe("local/regional");
    expect(sourceTypeForDomain("rfi.fr")).toBe("local/regional");
    expect(sourceTypeForDomain("example.org")).toBe("local/regional");
  });

  it("scores source quality by evidence value without treating alignment as credibility", () => {
    expect(sourceQualityForDomain("reuters.com")).toMatchObject({ score: 90, label: "High contribution" });
    expect(sourceQualityForDomain("who.int")).toMatchObject({ score: 88, label: "Primary evidence" });
    expect(sourceQualityForDomain("hrw.org")).toMatchObject({ score: 82, label: "Specialist context" });
    expect(sourceQualityForDomain("english.news.cn")).toMatchObject({ score: 58, label: "Context source" });
    expect(sourceQualityForDomain("example.org")).toMatchObject({ score: 50, label: "Early signal" });
  });

  it("keeps hourly discovery geographically broad instead of one global query", () => {
    expect(HOURLY_DISCOVERY_QUERIES.map((query) => query.topic)).toEqual([
      "World",
      "Middle East",
      "Africa",
      "Asia",
      "Latin America",
      "Europe",
      "Science & Tech"
    ]);
  });

  it("does not classify word fragments like awards as war coverage", () => {
    expect(inferTopic("Clare Wright wins book of the year at literary awards", "World")).toBe("World");
    expect(inferTopic("Ceasefire talks resume after overnight strikes", "World")).toBe("Conflict");
    expect(inferTopic("Renewed attacks kill civilians as death toll rises", "World")).toBe("Conflict");
    expect(inferTopic("John Swinney confident he has the votes to retain post as first minister", "Africa")).toBe("World");
  });

  it("pulls from multiple curated RSS regions without letting one feed dominate", async () => {
    const xmlFor = (host: string, title: string, dateTag = "pubDate") => `
      <rss><channel>
        <item>
          <title><![CDATA[${title}]]></title>
          <link>https://${host}/story-one</link>
          <${dateTag}>Mon, 18 May 2026 12:15:00 GMT</${dateTag}>
        </item>
      </channel></rss>
    `;
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("aljazeera.com")) {
        return new Response(`
          <rss><channel>
            <item>
              <title><![CDATA[Ceasefire talks resume after India&#039;s overnight strikes in U . S . talks]]></title>
              <link>https://aljazeera.com/story-one</link>
              <pubDate>Mon, 18 May 2026 12:15:00 GMT</pubDate>
              <description><![CDATA[Officials said negotiations resumed after overnight strikes, while local residents described disruption near the border.]]></description>
            </item>
          </channel></rss>
        `, {
          headers: { "content-type": "application/rss+xml", "content-length": "260" }
        });
      }
      if (url.includes("africanews.com")) {
        return new Response(xmlFor("africanews.com", "Kenya flood shelters expand as water recedes"), {
          headers: { "content-type": "application/rss+xml", "content-length": "260" }
        });
      }
      if (url.includes("scmp.com")) {
        return new Response(xmlFor("scmp.com", "Asia technology ministers discuss semiconductor supply"), {
          headers: { "content-type": "application/rss+xml", "content-length": "260" }
        });
      }
      if (url.includes("allafrica.com")) {
        return new Response(`
          <rss><channel>
            <item>
              <title><![CDATA[Sudan aid routes reopen after talks]]></title>
              <link>https://allafrica.com/story-two</link>
              <dc:date>2026-05-18T12:20:00Z</dc:date>
            </item>
          </channel></rss>
        `, {
          headers: { "content-type": "application/rss+xml", "content-length": "260" }
        });
      }
      return new Response("<rss><channel></channel></rss>", {
        headers: { "content-type": "application/rss+xml", "content-length": "30" }
      });
    };

    const articles = await fetchCuratedRSSArticles(fetcher);

    expect(articles.map((article) => article.domain)).toEqual([
      "aljazeera.com",
      "africanews.com",
      "allafrica.com",
      "scmp.com"
    ]);
    expect(articles.find((article) => article.domain === "aljazeera.com")?.title).toBe("Ceasefire talks resume after India's overnight strikes in U.S. talks");
    expect(articles.find((article) => article.domain === "aljazeera.com")?.excerpt).toContain("negotiations resumed");
    expect(articles.find((article) => article.domain === "allafrica.com")?.seenAt).toBe("2026-05-18T12:20:00.000Z");
    expect(new Set(articles.map((article) => article.sourceCountry))).toEqual(new Set(["Qatar", "Pan-African", "Hong Kong"]));
  });

  it("builds a source mix without treating any source category as automatically neutral", () => {
    const articles = [
      {
        id: "raw_reuters",
        url: "https://reuters.com/world/test",
        title: "Ceasefire talks continue after revised statements",
        domain: "reuters.com",
        language: "English",
        sourceCountry: "International",
        seenAt: "2026-05-18T12:30:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "test"
      },
      {
        id: "raw_reliefweb",
        url: "https://reliefweb.int/report/test",
        title: "Aid agencies report expanded shelters",
        domain: "reliefweb.int",
        language: "English",
        sourceCountry: "Kenya",
        seenAt: "2026-05-18T12:31:00Z",
        imageUrl: null,
        topic: "Humanitarian",
        query: "test"
      }
    ];

    const mix = sourceMixForArticles(articles);

    expect(mix.wire).toBe(1);
    expect(mix.ngo).toBe(1);
    expect(mix.labels).toEqual(["wire", "NGO"]);
  });

  it("infers event region from the headline before publisher country", () => {
    const document = buildUpdatesDocument([
      {
        id: "raw_test",
        url: "https://bbc.co.uk/news/health-test",
        title: "WHO declares Ebola outbreak in DR Congo an international emergency",
        domain: "bbc.co.uk",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:30:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:test"
      }
    ], new Date("2026-05-18T12:30:00Z"));

    expect(document.updates[0].region).toBe("Africa");
    expect(document.updates[0].whyItMatters).toContain("Reporting sources currently include United Kingdom");
    expect(document.updates[0].sourceMix.labels).toEqual(["local/regional"]);
  });

  it("builds a finite daily briefing from live discovery articles", () => {
    const articles = [
      {
        id: "rss_one",
        url: "https://bbc.co.uk/news/world-1",
        title: "Trump warns clock is ticking for Iran as talks stall",
        domain: "bbc.co.uk",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:test"
      },
      {
        id: "rss_two",
        url: "https://news.un.org/story/health-1",
        title: "Health teams expand Ebola monitoring in DR Congo",
        domain: "news.un.org",
        language: "English",
        sourceCountry: "International",
        seenAt: "2026-05-18T12:05:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:test"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);

    expect(briefingDocument.date).toBe("2026-05-18");
    expect(briefingDocument.storyCount).toBe(2);
    expect(briefingDocument.sections.map((section) => section.title)).toContain("Middle East");
    expect(briefingDocument.sections.map((section) => section.title)).toContain("Health");
    expect(briefingDocument.sections.flatMap((section) => section.stories)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: "story_one",
          publishedAt: "2026-05-18T12:00:00Z",
          expiresAt: "2026-05-21T12:00:00.000Z",
          confidence: "Low",
          sourceCount: 1
        })
      ])
    );
  });

  it("builds cautious story detail documents from one-source discovery items", () => {
    const details = buildStoryDetailsFromArticles([
      {
        id: "rss_one",
        url: "https://news.un.org/story/health-1",
        title: "Health teams expand Ebola monitoring in DR Congo",
        domain: "news.un.org",
        language: "English",
        sourceCountry: "International",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:test"
      }
    ], 36, new Date("2026-05-18T13:00:00Z"));

    expect(details[0]).toMatchObject({
      id: "story_one",
      confidence: {
        rating: "Medium"
      },
      evidenceCheck: {
        classification: "Plausible but unconfirmed"
      },
      biasAudit: {
        passed: true
      }
    });
    expect(details[0].whatIsUnclear.join(" ")).toContain("plausible but still needs independent corroboration");
    expect(details[0].sources[0].name).toBe("UN News");
  });

  it("clusters same-subject reports into one briefing card with multiple sources", () => {
    const relatedArticles = [
      {
        id: "rss_bbc",
        url: "https://bbc.co.uk/news/world-middle-east-1",
        title: "Israel-Lebanon ceasefire talks resume after overnight strikes",
        domain: "bbc.co.uk",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:bbc",
        excerpt: "Diplomats resumed ceasefire talks after overnight strikes near the Lebanon border, with both sides giving different accounts of the intended targets."
      },
      {
        id: "rss_aljazeera",
        url: "https://aljazeera.com/news/ceasefire-talks-1",
        title: "Ceasefire talks resume after overnight Israel-Lebanon strikes",
        domain: "aljazeera.com",
        language: "English",
        sourceCountry: "Qatar",
        seenAt: "2026-05-18T12:10:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:aljazeera"
      },
      {
        id: "rss_mee",
        url: "https://middleeasteye.net/news/lebanon-ceasefire-talks",
        title: "Lebanon ceasefire talks continue after overnight strikes",
        domain: "middleeasteye.net",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:20:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:mee"
      }
    ];

    const briefingDocument = buildBriefingDocument(relatedArticles, new Date("2026-05-18T13:00:00Z"), 20);
    const story = briefingDocument.sections.flatMap((section) => section.stories)[0];
    const details = buildStoryDetailsFromArticles(relatedArticles, 20, new Date("2026-05-18T13:00:00Z"));

    expect(briefingDocument.storyCount).toBe(1);
    expect(story).toMatchObject({
      id: "story_mee",
      sourceCount: 3,
      confidence: "Medium-high"
    });
    expect(new Set(details[0].sources.map((source) => source.name))).toEqual(new Set(["BBC", "Al Jazeera", "Middle East Eye"]));
    expect(details[0].whatHappened).toContain("3 sources, including");
    expect(details[0].confidence.reason).toContain("3 distinct sources");
    expect(details[0].whatIsUnclear.join(" ")).toContain("event itself is treated as corroborated reporting");
    expect(details[0].whatIsUnclear.join(" ")).not.toContain("not yet independently verified");
    expect(details[0].evidenceCheck.why).toContain("app treats the event as corroborated reporting");
    expect(details[0].countries).toEqual(["Israel", "Lebanon"]);
    expect(details[0].sourceCountries).toEqual(["United Kingdom", "Qatar"]);
    expect(details[0].verification?.checks.join(" ")).toContain("3 distinct sources");
  });

  it("does not let weak duplicate-quality sources inflate confidence by count alone", () => {
    const articles = [
      {
        id: "rss_one",
        url: "https://example-one.org/story",
        title: "City flood shelters expand after heavy rains",
        domain: "example-one.org",
        language: "English",
        sourceCountry: "Unknown",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:test"
      },
      {
        id: "rss_two",
        url: "https://example-two.org/story",
        title: "City flood shelters expand as heavy rains continue",
        domain: "example-two.org",
        language: "English",
        sourceCountry: "Unknown",
        seenAt: "2026-05-18T12:05:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:test"
      },
      {
        id: "rss_three",
        url: "https://example-three.org/story",
        title: "City flood shelters expand after heavy rain disruption",
        domain: "example-three.org",
        language: "English",
        sourceCountry: "Unknown",
        seenAt: "2026-05-18T12:10:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:test"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const story = briefingDocument.sections.flatMap((section) => section.stories)[0];
    const details = buildStoryDetailsFromArticles(articles, 20, new Date("2026-05-18T13:00:00Z"));

    expect(story.sourceCount).toBe(3);
    expect(story.confidence).toBe("Low");
    expect(details[0].sources.every((source) => source.qualityLabel === "Early signal")).toBe(true);
  });

  it("keeps the curated RSS source set regionally balanced as it grows", () => {
    expect(CURATED_RSS_FEEDS.length).toBeGreaterThanOrEqual(40);
    expect(CURATED_RSS_FEEDS.some((feed) => feed.sourceCountry === "Mexico")).toBe(true);
    expect(CURATED_RSS_FEEDS.some((feed) => feed.sourceCountry === "Turkey")).toBe(true);
    expect(CURATED_RSS_FEEDS.some((feed) => feed.sourceCountry === "China")).toBe(true);
    expect(CURATED_RSS_FEEDS.some((feed) => feed.sourceCountry === "Nigeria")).toBe(true);
    expect(CURATED_RSS_FEEDS.some((feed) => feed.sourceCountry === "Israel")).toBe(true);
  });

  it("creates story-specific glance and importance copy instead of generic category filler", () => {
    const articles = [
      {
        id: "rss_un",
        url: "https://news.un.org/story/ebola-drc",
        title: "Ebola outbreak follows hunger and displacement crisis in DR Congo",
        domain: "news.un.org",
        language: "English",
        sourceCountry: "International",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:un"
      },
      {
        id: "rss_bbc",
        url: "https://bbc.co.uk/news/ebola-drc",
        title: "DR Congo Ebola response strained by displacement and hunger",
        domain: "bbc.co.uk",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:05:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:bbc"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const story = briefingDocument.sections.flatMap((section) => section.stories)[0];
    const details = buildStoryDetailsFromArticles(articles, 20, new Date("2026-05-18T13:00:00Z"));

    expect(story.summary).toContain("DR Congo");
    expect(story.summary).not.toContain("reported related developments");
    expect(details[0].whatHappened).toContain("DR Congo");
    expect(details[0].whyItMatters).toContain("displacement");
    expect(details[0].whyItMatters).not.toBe("Health developments can affect public guidance, medical capacity, and vulnerable groups.");
  });

  it("uses source excerpts to fill low-intensity business cards instead of vague context copy", () => {
    const articles = [
      {
        id: "rss_nikkei",
        url: "https://asia.nikkei.com/Markets/Indexes/nikkei-asia300-aluminum-corp-china",
        title: "Nikkei Asia300 index to add Aluminum Corp. of China",
        domain: "asia.nikkei.com",
        language: "English",
        sourceCountry: "Japan",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Economy",
        query: "feed:nikkei",
        excerpt: "The Asia300 index will add Aluminum Corp. of China after its latest review, changing the benchmark followed by investors tracking major Asian companies."
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const story = briefingDocument.sections.flatMap((section) => section.stories)[0];
    const details = buildStoryDetailsFromArticles(articles, 20, new Date("2026-05-18T13:00:00Z"));

    expect(story.summary).toContain("Asia300 index will add Aluminum Corp. of China");
    expect(story.summary).not.toContain("early signal");
    expect(details[0].whatHappened).toContain("benchmark followed by investors");
    expect(details[0].whyItMatters).toContain("investor exposure");
    expect(details[0].whyItMatters).not.toContain("today's wider context");
    expect(details[0].sourceEvidence?.[0].excerpt).toContain("latest review");
  });

  it("filters vague short feed headlines that cannot support a useful briefing card", () => {
    const articles = [
      {
        id: "rss_vague",
        url: "https://dailymaverick.co.za/powerless-to-learn",
        title: "Powerless To Learn",
        domain: "dailymaverick.co.za",
        language: "English",
        sourceCountry: "South Africa",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "World",
        query: "feed:dailymaverick"
      },
      {
        id: "rss_specific",
        url: "https://dailymaverick.co.za/south-africa-school-power-cuts",
        title: "South Africa schools face power cuts during exams",
        domain: "dailymaverick.co.za",
        language: "English",
        sourceCountry: "South Africa",
        seenAt: "2026-05-18T12:05:00Z",
        imageUrl: null,
        topic: "World",
        query: "feed:dailymaverick"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const headlines = briefingDocument.sections.flatMap((section) => section.stories.map((story) => story.headline));

    expect(headlines).not.toContain("Powerless To Learn");
    expect(headlines).toContain("South Africa schools face power cuts during exams");
  });

  it("ranks high-public-interest verified stories above low-value fresh items", () => {
    const articles = [
      {
        id: "rss_tickets",
        url: "https://example.org/world-cup-tickets",
        title: "How To Buy Tickets For The FIFA World Cup 2026",
        domain: "example.org",
        language: "English",
        sourceCountry: "United States",
        seenAt: "2026-05-18T12:59:00Z",
        imageUrl: null,
        topic: "World",
        query: "feed:example"
      },
      {
        id: "rss_reuters",
        url: "https://reuters.com/world/kenya-flood-shelters",
        title: "Kenya flood shelters expand after heavy rains",
        domain: "reuters.com",
        language: "English",
        sourceCountry: "Kenya",
        seenAt: "2026-05-18T12:40:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:reuters"
      },
      {
        id: "rss_africanews",
        url: "https://africanews.com/story/kenya-flood-shelters",
        title: "Kenya flood shelters expand as rains ease",
        domain: "africanews.com",
        language: "English",
        sourceCountry: "Pan-African",
        seenAt: "2026-05-18T12:35:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:africanews"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const stories = briefingDocument.sections.flatMap((section) => section.stories);

    expect(stories[0].headline).toContain("Kenya flood shelters");
    expect(stories[0].sourceCount).toBe(2);
    expect(stories.findIndex((story) => story.headline.includes("Tickets"))).toBeGreaterThan(0);
  });

  it("uses the clearest source headline as the cluster lead instead of weak gallery labels", () => {
    const articles = [
      {
        id: "rss_gallery",
        url: "https://example.org/photos-ebola",
        title: "Photos from Congo and Uganda as WHO declare health emergency over Ebola",
        domain: "example.org",
        language: "English",
        sourceCountry: "United States",
        seenAt: "2026-05-18T12:59:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:gallery"
      },
      {
        id: "rss_un",
        url: "https://news.un.org/ebola-emergency",
        title: "WHO declares Ebola outbreak a global health emergency",
        domain: "news.un.org",
        language: "English",
        sourceCountry: "International",
        seenAt: "2026-05-18T12:40:00Z",
        imageUrl: null,
        topic: "Health",
        query: "feed:un"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const story = briefingDocument.sections.flatMap((section) => section.stories)[0];

    expect(story.headline).toBe("WHO declares Ebola outbreak a global health emergency");
    expect(story.id).toBe("story_un");
  });

  it("keeps the opening briefing queue diverse instead of letting one category dominate", () => {
    const healthTitles = [
      "WHO expands Ebola outbreak monitoring in DR Congo",
      "Hospitals prepare for hantavirus cases in Colorado",
      "Vaccine teams widen measles campaign after school outbreaks",
      "Ports increase screening after regional disease alert",
      "Health ministry expands fever surveillance in border towns"
    ];
    const healthArticles = healthTitles.map((title, index) => ({
      id: `rss_health_${index}`,
      url: `https://news.un.org/health-${index}`,
      title,
      domain: "news.un.org",
      language: "English",
      sourceCountry: "International",
      seenAt: `2026-05-18T12:5${index}:00Z`,
      imageUrl: null,
      topic: "Health",
      query: "feed:un"
    }));
    const articles = [
      ...healthArticles,
      {
        id: "rss_conflict",
        url: "https://reuters.com/world/lebanon-strikes",
        title: "Death toll from Israeli strikes on Lebanon passes 3,000, officials say",
        domain: "reuters.com",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:40:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:reuters"
      },
      {
        id: "rss_economy",
        url: "https://reuters.com/markets/rates",
        title: "Central bank signals rate decision as inflation eases",
        domain: "reuters.com",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:35:00Z",
        imageUrl: null,
        topic: "Economy",
        query: "feed:reuters"
      }
    ];

    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 7);
    const rankedStories = briefingDocument.sections
      .flatMap((section) => section.stories)
      .sort((left, right) => (left.rank ?? 999) - (right.rank ?? 999));
    const openingSections = rankedStories.slice(0, 5).map((story) => story.category === "Conflict" ? "Middle East" : story.category);

    expect(rankedStories[0].rank).toBe(1);
    expect(openingSections).toEqual(expect.arrayContaining(["Health", "Middle East", "Economy"]));
    expect(openingSections.filter((section) => section === "Health").length).toBeLessThanOrEqual(3);
  });

  it("treats two matched local sources as medium confidence, not a one-source low signal", () => {
    const relatedArticles = [
      {
        id: "rss_one",
        url: "https://africanews.com/news/flood-shelters",
        title: "Kenya flood shelters expand after heavy rains",
        domain: "africanews.com",
        language: "English",
        sourceCountry: "Pan-African",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:africanews"
      },
      {
        id: "rss_two",
        url: "https://allafrica.com/stories/flood-shelters",
        title: "Kenya flood shelters expand as heavy rains ease",
        domain: "allafrica.com",
        language: "English",
        sourceCountry: "Pan-African",
        seenAt: "2026-05-18T12:10:00Z",
        imageUrl: null,
        topic: "Climate",
        query: "feed:allafrica"
      }
    ];

    const briefingDocument = buildBriefingDocument(relatedArticles, new Date("2026-05-18T13:00:00Z"), 20);
    const story = briefingDocument.sections.flatMap((section) => section.stories)[0];

    expect(story).toMatchObject({
      sourceCount: 2,
      confidence: "Medium"
    });
  });

  it("uses OpenAI synthesis and web search to rewrite card copy and add contextual sources", async () => {
    const articles = [
      {
        id: "rss_one",
        url: "https://bbc.co.uk/news/world-middle-east-1",
        title: "Ceasefire talks resume after overnight strikes near Lebanon border",
        domain: "bbc.co.uk",
        language: "English",
        sourceCountry: "United Kingdom",
        seenAt: "2026-05-18T12:00:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:bbc"
      },
      {
        id: "rss_two",
        url: "https://aljazeera.com/news/ceasefire-talks-1",
        title: "Lebanon border ceasefire talks resume after overnight strikes",
        domain: "aljazeera.com",
        language: "English",
        sourceCountry: "Qatar",
        seenAt: "2026-05-18T12:10:00Z",
        imageUrl: null,
        topic: "Conflict",
        query: "feed:aljazeera",
        excerpt: "Local officials said the strikes disrupted border communities while negotiators returned to talks later in the day."
      }
    ];
    const briefingDocument = buildBriefingDocument(articles, new Date("2026-05-18T13:00:00Z"), 20);
    const details = buildStoryDetailsFromArticles(articles, 20, new Date("2026-05-18T13:00:00Z"));
    const fetcher: typeof fetch = async (_input, init) => {
      expect(String(init?.headers)).not.toContain("test-key");
      const body = JSON.parse(String(init?.body));
      expect(body.tools).toEqual([{ type: "web_search" }]);
      expect(body.tool_choice).toBe("auto");
      expect(body.input[0].content[0].text).toContain("Use the provided articleEvidence first");
      const synthesisInput = JSON.parse(body.input[1].content[0].text);
      expect(synthesisInput.stories[0]).toHaveProperty("articleEvidence");
      expect(JSON.stringify(synthesisInput.stories[0].articleEvidence)).toContain("Local officials said the strikes disrupted border communities");
      return new Response(JSON.stringify({
        output_text: JSON.stringify({
          stories: [
            {
              id: "story_two",
              headline: "Ceasefire talks resume after reported Lebanon border strikes",
              summary: "Two sources reported renewed talks after strikes near the border, with details still attributed. ([UN News](https://news.un.org/en/story/context))",
              whyItMatters: "The talks could affect ceasefire stability and civilian safety.",
              whatHappened: "The card described two sources reporting related developments near the Lebanon border. The exact targets and casualty details remain attributed. ([UN News](https://news.un.org/en/story/context))",
              whatWeKnow: ["Talks resumed.", "Two sources reported related developments."],
              whatIsUnclear: ["The exact targets remain unclear.", "Casualty details remain disputed."],
              confidenceReason: "Confidence: Medium. Two distinct sources give limited corroboration, but actor claims still need independent evidence, [1]",
              framingCheck: {
                westernMainstream: "May foreground diplomatic risk.",
                localRegional: "May foreground civilian disruption.",
                officialGovernment: "Official claims should be attributed.",
                affectedPopulation: "Affected people may emphasize disruption and safety.",
                independentEvidence: "Independent evidence remains limited.",
                humanRightsNGO: "Rights groups may focus on civilian harm.",
                opposingSide: "Opposing claims should be held to the same standard."
              },
              additionalSources: [
                {
                  name: "UN News",
                  type: "primary",
                  region: "International",
                  url: "https://news.un.org/en/story/context",
                  framing: "UN source useful for diplomatic and humanitarian context."
                }
              ],
              sortPriority: 1
            }
          ]
        })
      }), {
        headers: { "content-type": "application/json" }
      });
    };

    const enhanced = await enhanceBriefingWithOpenAI({ briefing: briefingDocument, details }, {
      apiKey: "test-key",
      model: "gpt-5.4-nano",
      fetcher
    });
    const story = enhanced.briefing.sections.flatMap((section) => section.stories)[0];

    expect(story).toMatchObject({
      id: "story_two",
      headline: "Ceasefire talks resume after reported Lebanon border strikes",
      sourceCount: 3
    });
    expect(enhanced.details[0].whatHappened).toContain("two sources reporting");
    expect(enhanced.details[0].whatHappened).toContain("source item");
    expect(enhanced.details[0].whatHappened).not.toContain("The card");
    expect(story.summary).not.toContain("](");
    expect(enhanced.details[0].whatHappened).not.toContain("](");
    expect(enhanced.details[0].confidence.reason).not.toMatch(/^Confidence/i);
    expect(enhanced.details[0].confidence.reason).not.toContain("[1]");
    expect(enhanced.details[0].confidence.reason).not.toMatch(/[,;:]$/);
    expect(enhanced.details[0].evidenceCheck.why).toContain("event is treated as corroborated reporting");
    expect(enhanced.details[0].sources.map((source) => source.name)).toContain("UN News");
    expect(enhanced.details[0].sources).toHaveLength(3);
  });

  it("uses a bound default fetch for OpenAI synthesis when no fetcher is injected", async () => {
    const story = {
      id: "story_bound_fetch",
      headline: "Health teams expand monitoring",
      region: "Africa",
      category: "Health",
      summary: "Draft summary",
      whyItMatters: "Draft reason",
      confidence: "Medium" as const,
      emotionalLoad: "Medium" as const,
      sourceCount: 1,
      imageId: null
    };
    const detail = {
      id: story.id,
      headline: story.headline,
      category: story.category,
      region: story.region,
      whatHappened: story.summary,
      whyItMatters: story.whyItMatters,
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed.", "Further sources may change confidence."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Medium" as const, reason: "One source." },
      emotionalLoad: "Medium" as const,
      sources: [{
        id: "source_bound_fetch",
        name: "Example",
        type: "local/regional",
        region: "Africa",
        url: "https://example.org/health",
        publishedAt: "2026-05-18T12:00:00Z",
        framing: "Example framing."
      }],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: story.headline,
        classification: "Plausible but unconfirmed" as const,
        why: "One detected source."
      }
    };
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({
      output_text: JSON.stringify({
        stories: [{
          id: "story_bound_fetch",
          headline: "Health teams expand monitoring after reported outbreak risk",
          summary: "Local health teams expanded monitoring after reported outbreak risk, with details still attributed.",
          whyItMatters: "The response may affect testing capacity and public guidance in affected communities.",
          whatHappened: "A local source reported expanded monitoring. Further confirmation is still needed.",
          whatWeKnow: ["Monitoring expanded.", "Details remain attributed to current reporting."],
          whatIsUnclear: ["The full case count remains unclear.", "Further primary evidence may change confidence."],
          confidenceReason: "Current reporting is plausible but still needs corroboration.",
          framingCheck: {
            westernMainstream: "May foreground public-health risk.",
            localRegional: "May foreground local service pressure.",
            officialGovernment: "Official claims should remain attributed.",
            affectedPopulation: "Affected people may focus on access to care.",
            independentEvidence: "Independent evidence remains limited.",
            humanRightsNGO: null,
            opposingSide: null
          },
          additionalSources: [],
          sortPriority: 1
        }]
      })
    }), {
      headers: { "content-type": "application/json" }
    }));

    try {
      const enhanced = await enhanceBriefingWithOpenAI({
        briefing: {
          date: "2026-05-18",
          title: "Today's Global Briefing",
          readingTimeMinutes: 4,
          emotionalLoad: "Medium",
          storyCount: 1,
          sections: [{ id: "health", title: "Health", stories: [story] }]
        },
        details: [detail]
      }, {
        apiKey: "test-key",
        model: "gpt-5.4-nano",
        retryDelayMs: 1
      });

      expect(fetchMock).toHaveBeenCalledOnce();
      expect(enhanced.briefing.sections[0].stories[0].headline).toBe("Health teams expand monitoring after reported outbreak risk");
    } finally {
      fetchMock.mockRestore();
    }
  });

  it("batches OpenAI synthesis so large briefings are not one fragile request", async () => {
    const stories = Array.from({ length: 5 }, (_, index) => ({
      id: `story_${index}`,
      headline: `Story ${index}`,
      region: "World",
      category: "World",
      summary: `Draft summary ${index}`,
      whyItMatters: `Draft reason ${index}`,
      confidence: "Low" as const,
      emotionalLoad: "Low" as const,
      sourceCount: 1,
      imageId: null
    }));
    const details = stories.map((story) => ({
      id: story.id,
      headline: story.headline,
      category: story.category,
      region: story.region,
      whatHappened: story.summary,
      whyItMatters: story.whyItMatters,
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Low" as const, reason: "One source." },
      emotionalLoad: "Low" as const,
      sources: [
        {
          id: `source_${story.id}`,
          name: "Example",
          type: "local/regional",
          region: "World",
          url: "https://example.org",
          publishedAt: "2026-05-18T12:00:00Z",
          framing: "Example framing."
        }
      ],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: story.headline,
        classification: "Plausible but unconfirmed" as const,
        why: "One detected source."
      }
    }));
    let calls = 0;
    const fetcher: typeof fetch = async (_input, init) => {
      calls += 1;
      const body = JSON.parse(String(init?.body));
      const inputText = body.input[1].content[0].text;
      const ids = JSON.parse(inputText).stories.map((story: { id: string }) => story.id);
      return new Response(JSON.stringify({
        output_text: JSON.stringify({
          stories: ids.map((id: string, index: number) => ({
            id,
            headline: `Edited ${id}`,
            summary: `Edited summary ${id}`,
            whyItMatters: `Edited reason ${id}`,
            whatHappened: `Edited happening ${id}`,
            whatWeKnow: ["The item was detected.", "Further context was checked."],
            whatIsUnclear: ["Some details remain unclear.", "More sources may change confidence."],
            confidenceReason: "Still low until corroborated.",
            framingCheck: {
              westernMainstream: "Edited",
              localRegional: "Edited",
              officialGovernment: "Edited",
              affectedPopulation: "Edited",
              independentEvidence: "Edited",
              humanRightsNGO: null,
              opposingSide: null
            },
            additionalSources: [],
            sortPriority: index + 1
          }))
        })
      }), {
        headers: { "content-type": "application/json" }
      });
    };

    const enhanced = await enhanceBriefingWithOpenAI({
      briefing: {
        date: "2026-05-18",
        title: "Today's Global Briefing",
        readingTimeMinutes: 4,
        emotionalLoad: "Low",
        storyCount: stories.length,
        sections: [{ id: "world", title: "World", stories }]
      },
      details
    }, {
      apiKey: "test-key",
      model: "gpt-5.4-nano",
      fetcher,
      batchSize: 2
    });

    expect(calls).toBe(3);
    expect(enhanced.briefing.sections[0].stories[4].headline).toBe("Edited story_4");
  });

  it("keeps successful OpenAI batches when a later batch is rate limited", async () => {
    const stories = Array.from({ length: 3 }, (_, index) => ({
      id: `story_partial_${index}`,
      headline: `Story ${index}`,
      region: "World",
      category: "World",
      summary: `Draft summary ${index}`,
      whyItMatters: `Draft reason ${index}`,
      confidence: "Low" as const,
      emotionalLoad: "Low" as const,
      sourceCount: 1,
      imageId: null
    }));
    const details = stories.map((story) => ({
      id: story.id,
      headline: story.headline,
      category: story.category,
      region: story.region,
      whatHappened: story.summary,
      whyItMatters: story.whyItMatters,
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Low" as const, reason: "One source." },
      emotionalLoad: "Low" as const,
      sources: [{
        id: `source_${story.id}`,
        name: "Example",
        type: "local/regional",
        region: "World",
        url: "https://example.org",
        publishedAt: "2026-05-18T12:00:00Z",
        framing: "Example framing."
      }],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: story.headline,
        classification: "Plausible but unconfirmed" as const,
        why: "One detected source."
      }
    }));
    let calls = 0;
    const fetcher: typeof fetch = async (_input, init) => {
      calls += 1;
      const body = JSON.parse(String(init?.body));
      const ids = JSON.parse(body.input[1].content[0].text).stories.map((story: { id: string }) => story.id);
      if (ids.includes("story_partial_2")) {
        return new Response("rate limited", {
          status: 429,
          headers: { "retry-after": "0.001" }
        });
      }
      return new Response(JSON.stringify({
        output_text: JSON.stringify({
          stories: ids.map((id: string) => ({
            id,
            headline: `Edited ${id}`,
            summary: `Edited summary ${id}`,
            whyItMatters: `Edited reason ${id}`,
            whatHappened: `Edited happening ${id}`,
            whatWeKnow: ["The item was detected.", "Further context was checked."],
            whatIsUnclear: ["Some details remain unclear.", "More sources may change confidence."],
            confidenceReason: "Still low until corroborated.",
            framingCheck: {
              westernMainstream: "Edited",
              localRegional: "Edited",
              officialGovernment: "Edited",
              affectedPopulation: "Edited",
              independentEvidence: "Edited",
              humanRightsNGO: null,
              opposingSide: null
            },
            additionalSources: [],
            sortPriority: 1
          }))
        })
      }), {
        headers: { "content-type": "application/json" }
      });
    };

    const enhanced = await enhanceBriefingWithOpenAI({
      briefing: {
        date: "2026-05-18",
        title: "Today's Global Briefing",
        readingTimeMinutes: 4,
        emotionalLoad: "Low",
        storyCount: stories.length,
        sections: [{ id: "world", title: "World", stories }]
      },
      details
    }, {
      apiKey: "test-key",
      model: "gpt-5.4-nano",
      fetcher,
      batchSize: 2,
      retryDelayMs: 1
    });

    expect(calls).toBe(3);
    expect(enhanced.briefing.sections[0].stories[0].headline).toBe("Edited story_partial_0");
    expect(enhanced.briefing.sections[0].stories[2].headline).toBe("Story 2");
  });

  it("limits OpenAI synthesis to the newest slice to avoid hourly rate-limit spikes", async () => {
    const stories = Array.from({ length: 6 }, (_, index) => ({
      id: `story_limited_${index}`,
      headline: `Story ${index}`,
      region: "World",
      category: "World",
      summary: `Draft summary ${index}`,
      whyItMatters: `Draft reason ${index}`,
      confidence: "Low" as const,
      emotionalLoad: "Low" as const,
      sourceCount: 1,
      imageId: null
    }));
    const details = stories.map((story) => ({
      id: story.id,
      headline: story.headline,
      category: story.category,
      region: story.region,
      whatHappened: story.summary,
      whyItMatters: story.whyItMatters,
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Low" as const, reason: "One source." },
      emotionalLoad: "Low" as const,
      sources: [{
        id: `source_${story.id}`,
        name: "Example",
        type: "local/regional",
        region: "World",
        url: "https://example.org",
        publishedAt: "2026-05-18T12:00:00Z",
        framing: "Example framing."
      }],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: story.headline,
        classification: "Plausible but unconfirmed" as const,
        why: "One detected source."
      }
    }));
    const seenIDs: string[] = [];
    const fetcher: typeof fetch = async (_input, init) => {
      const body = JSON.parse(String(init?.body));
      const ids = JSON.parse(body.input[1].content[0].text).stories.map((story: { id: string }) => story.id);
      seenIDs.push(...ids);
      return new Response(JSON.stringify({
        output_text: JSON.stringify({
          stories: ids.map((id: string, index: number) => ({
            id,
            headline: `Edited ${id}`,
            summary: `Edited summary ${id}`,
            whyItMatters: `Edited reason ${id}`,
            whatHappened: `Edited happening ${id}`,
            whatWeKnow: ["The item was detected.", "Further context was checked."],
            whatIsUnclear: ["Some details remain unclear.", "More sources may change confidence."],
            confidenceReason: "Still low until corroborated.",
            framingCheck: {
              westernMainstream: "Edited",
              localRegional: "Edited",
              officialGovernment: "Edited",
              affectedPopulation: "Edited",
              independentEvidence: "Edited",
              humanRightsNGO: null,
              opposingSide: null
            },
            additionalSources: [],
            sortPriority: index + 1
          }))
        })
      }), {
        headers: { "content-type": "application/json" }
      });
    };

    const enhanced = await enhanceBriefingWithOpenAI({
      briefing: {
        date: "2026-05-18",
        title: "Today's Global Briefing",
        readingTimeMinutes: 4,
        emotionalLoad: "Low",
        storyCount: stories.length,
        sections: [{ id: "world", title: "World", stories }]
      },
      details
    }, {
      apiKey: "test-key",
      model: "gpt-5.4-nano",
      fetcher,
      batchSize: 2,
      storyLimit: 3
    });

    expect(seenIDs).toEqual(["story_limited_0", "story_limited_1", "story_limited_2"]);
    expect(enhanced.briefing.sections[0].stories[2].headline).toBe("Edited story_limited_2");
    expect(enhanced.briefing.sections[0].stories[3].headline).toBe("Story 3");
  });

  it("retries OpenAI synthesis once after a rate-limit response", async () => {
    const story = {
      id: "story_retry",
      headline: "Story",
      region: "World",
      category: "World",
      summary: "Draft summary",
      whyItMatters: "Draft reason",
      confidence: "Low" as const,
      emotionalLoad: "Low" as const,
      sourceCount: 1,
      imageId: null
    };
    const detail = {
      id: story.id,
      headline: story.headline,
      category: story.category,
      region: story.region,
      whatHappened: story.summary,
      whyItMatters: story.whyItMatters,
      whatWeKnow: ["One source reported this."],
      whatIsUnclear: ["More context is needed."],
      framingCheck: {
        westernMainstream: "Draft",
        localRegional: "Draft",
        officialGovernment: "Draft",
        affectedPopulation: "Draft",
        independentEvidence: "Draft",
        humanRightsNGO: null,
        opposingSide: null
      },
      confidence: { rating: "Low" as const, reason: "One source." },
      emotionalLoad: "Low" as const,
      sources: [{
        id: "source_retry",
        name: "Example",
        type: "local/regional",
        region: "World",
        url: "https://example.org",
        publishedAt: "2026-05-18T12:00:00Z",
        framing: "Example framing."
      }],
      biasAudit: { passed: true, notes: ["Draft"] },
      depthAnalysis: null,
      evidenceCheck: {
        claim: story.headline,
        classification: "Plausible but unconfirmed" as const,
        why: "One detected source."
      }
    };
    let calls = 0;
    const fetcher: typeof fetch = async () => {
      calls += 1;
      if (calls === 1) {
        return new Response("rate limited", {
          status: 429,
          headers: { "retry-after": "0.001" }
        });
      }
      return new Response(JSON.stringify({
        output_text: JSON.stringify({
          stories: [{
            id: "story_retry",
            headline: "Edited story_retry",
            summary: "Edited summary",
            whyItMatters: "Edited reason",
            whatHappened: "Edited happening",
            whatWeKnow: ["The item was detected.", "Further context was checked."],
            whatIsUnclear: ["Some details remain unclear.", "More sources may change confidence."],
            confidenceReason: "Still low until corroborated.",
            framingCheck: {
              westernMainstream: "Edited",
              localRegional: "Edited",
              officialGovernment: "Edited",
              affectedPopulation: "Edited",
              independentEvidence: "Edited",
              humanRightsNGO: null,
              opposingSide: null
            },
            additionalSources: [],
            sortPriority: 1
          }]
        })
      }), {
        headers: { "content-type": "application/json" }
      });
    };

    const enhanced = await enhanceBriefingWithOpenAI({
      briefing: {
        date: "2026-05-18",
        title: "Today's Global Briefing",
        readingTimeMinutes: 4,
        emotionalLoad: "Low",
        storyCount: 1,
        sections: [{ id: "world", title: "World", stories: [story] }]
      },
      details: [detail]
    }, {
      apiKey: "test-key",
      model: "gpt-5.4-nano",
      fetcher,
      retryDelayMs: 1
    });

    expect(calls).toBe(2);
    expect(enhanced.briefing.sections[0].stories[0].headline).toBe("Edited story_retry");
  });

  it("retries the hourly GDELT discovery request after a rate limit", async () => {
    let calls = 0;
    const fetcher: typeof fetch = async () => {
      calls += 1;
      if (calls === 1) {
        return new Response("rate limited", { status: 429 });
      }
      return new Response(JSON.stringify({
        articles: [
          {
            url: `https://example.org/report-${calls}`,
            title: "Public health teams expand local monitoring after officials say &#039;risk changed&#039; in U . S . ports and 3, 000 homes",
            seendate: "20260518T123000Z",
            socialimage: "",
            domain: "example.org",
            language: "English",
            sourcecountry: "Ireland"
          }
        ]
      }), {
        headers: { "content-type": "application/json" }
      });
    };

    const articles = await fetchHourlyGDELTArticles(fetcher);

    expect(articles.length).toBeGreaterThan(0);
    expect(articles[0].title).toBe("Public health teams expand local monitoring after officials say 'risk changed' in U.S. ports and 3,000 homes");
  });

  it("skips ReliefWeb when no approved app name is configured", async () => {
    const fetcher: typeof fetch = async () => {
      throw new Error("ReliefWeb should not be called without an app name.");
    };

    await expect(fetchReliefWebReports(undefined, fetcher)).resolves.toEqual([]);
  });

  it("treats an unapproved ReliefWeb app name as an unavailable source", async () => {
    const fetcher: typeof fetch = async () => new Response(JSON.stringify({
      error: "AccessDeniedHttpException"
    }), {
      status: 403,
      headers: { "content-type": "application/json" }
    });

    await expect(fetchReliefWebReports("signal-daily", fetcher)).resolves.toEqual([]);
  });

  it("normalizes approved ReliefWeb reports into humanitarian discovery articles", async () => {
    const fetcher: typeof fetch = async () => new Response(JSON.stringify({
      data: [
        {
          id: "12345",
          fields: {
            title: "Kenya: Flood response update from local aid partners",
            url: "https://reliefweb.int/report/kenya/flood-response-update",
            date: { created: "2026-05-18T12:25:00+00:00" },
            source: [{ name: "OCHA" }],
            primary_country: [{ name: "Kenya" }],
            theme: [{ name: "Flood" }, { name: "Humanitarian" }]
          }
        }
      ]
    }), {
      headers: { "content-type": "application/json" }
    });

    const articles = await fetchReliefWebReports("approved-app", fetcher);

    expect(articles).toHaveLength(1);
    expect(articles[0]).toMatchObject({
      id: "reliefweb_12345",
      domain: "reliefweb.int",
      sourceCountry: "Kenya",
      topic: "Climate",
      query: "reliefweb:OCHA"
    });
  });
});
