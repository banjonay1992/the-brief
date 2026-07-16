import { briefing, calmUpdates, depthTokenStatus, source, story, userPreferences } from "./mockData";
import { runHourlyNewsPipeline } from "./ingest/pipeline";
import { enhanceBriefingWithOpenAI } from "./ingest/openAISynthesizer";
import type { BriefingDocument, BriefingSection, BriefingStorySummary, StoryDetailDocument } from "./ingest/briefingBuilder";

type JSONValue = Record<string, unknown> | readonly unknown[];

const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "public, max-age=60",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "content-type, authorization"
};

type StoredUser = {
  id: string;
  email: string;
  name: string;
  passwordHash: string;
  createdAt: string;
};

type AuthUser = Pick<StoredUser, "id" | "email" | "name">;

type AuthSession = {
  token: string;
  user: AuthUser;
  expiresAt: string;
};

type StoredDepthTokenStatus = {
  allowedPerDay: number;
  remaining: number;
  resetAt: string;
};

type AppleTokenClaims = {
  iss?: string;
  aud?: string;
  exp?: number;
  sub?: string;
  email?: string;
  nonce?: string;
};

type AppleWebAuthState = {
  state: string;
  nonce: string;
  mode: string;
  clientID: string;
  redirectURI: string;
  createdAt: string;
  expiresAt: string;
};

type AppleWebAuthHandoff = {
  session: AuthSession;
  expiresAt: string;
};

type AppleWebUserProfile = {
  email?: string;
  name?: {
    firstName?: string;
    lastName?: string;
  };
};

type EditorialStoryPatch = {
  id: string;
  headline?: string;
  summary?: string;
  whyItMatters?: string;
  whatHappened?: string;
  whatWeKnow?: string[];
  whatIsUnclear?: string[];
  confidenceReason?: string;
  framingCheck?: StoryDetailDocument["framingCheck"];
  biasAuditNotes?: string[];
};

const handler = {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    void ctx;

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: jsonHeaders });
    }

    const url = new URL(request.url);

    try {
      if (request.method === "GET" && url.pathname === "/api/briefings/today") {
        return await fromR2OrMock(env, `briefings/${todayKey()}/global.json`, briefing);
      }

      if (request.method === "GET" && url.pathname === "/api/briefings/today/updates") {
        return await fromR2OrMock(env, updatesKey(todayKey()), calmUpdates);
      }

      if (request.method === "GET" && url.pathname === "/api/pipeline/latest") {
        return await fromR2OrMock(env, "pipeline/latest.json", {
          status: "not-run-yet",
          message: "The live news pipeline has not written a status snapshot yet."
        });
      }

      const datedBriefing = match(url.pathname, /^\/api\/briefings\/([0-9]{4}-[0-9]{2}-[0-9]{2})$/);
      if (request.method === "GET" && datedBriefing) {
        return await fromR2OrMock(env, `briefings/${datedBriefing[1]}/global.json`, briefing);
      }

      const datedUpdates = match(url.pathname, /^\/api\/briefings\/([0-9]{4}-[0-9]{2}-[0-9]{2})\/updates$/);
      if (request.method === "GET" && datedUpdates) {
        return await fromR2OrMock(env, updatesKey(datedUpdates[1]), calmUpdates);
      }

      const article = match(url.pathname, /^\/api\/articles\/([A-Za-z0-9_-]+)$/);
      if (request.method === "GET" && article) {
        return await fromR2OrMock(env, `articles/${article[1]}.json`, story);
      }

      const sourceMatch = match(url.pathname, /^\/api\/sources\/([A-Za-z0-9_-]+)$/);
      if (request.method === "GET" && sourceMatch) {
        return await fromR2OrMock(env, `sources/${sourceMatch[1]}.json`, source);
      }

      if (url.pathname === "/api/users/preferences") {
        if (request.method === "GET") {
          return json(await storedPreferences(env));
        }
        if (request.method === "POST") {
          const preferences = await readJSON(request);
          await env.SIGNAL_DAILY_R2.put(preferencesObjectKey(), JSON.stringify(preferences));
          return json(preferences);
        }
      }

      if (request.method === "POST" && url.pathname === "/api/auth/signup") {
        return await signUp(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/auth/signin") {
        return await signIn(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/auth/apple/web/start") {
        return await startAppleWebSignIn(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/auth/apple/web/callback") {
        return await completeAppleWebCallback(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/auth/apple/web/session") {
        return await redeemAppleWebHandoff(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/auth/apple") {
        return await signInWithApple(request, env);
      }

      if (request.method === "GET" && url.pathname === "/api/auth/session") {
        return await currentSession(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/auth/signout") {
        return await signOut(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/admin/pipeline/run") {
        return await runAdminPipeline(request, env);
      }

      if (request.method === "POST" && url.pathname === "/api/admin/pipeline/synthesize") {
        return await runAdminSynthesisSlice(request, env, url);
      }

      if (request.method === "GET" && url.pathname === "/api/admin/editorial/queue") {
        return await runAdminEditorialQueue(request, env, url);
      }

      if (request.method === "POST" && url.pathname === "/api/admin/editorial/apply") {
        return await runAdminEditorialApply(request, env);
      }

      if (request.method === "GET" && url.pathname === "/api/depth-tokens/today") {
        return json(await storedDepthTokenStatus(env));
      }

      if (request.method === "POST" && url.pathname === "/api/depth-tokens/use") {
        const status = await storedDepthTokenStatus(env);
        const updated = { ...status, remaining: Math.max(status.remaining - 1, 0) };
        await env.SIGNAL_DAILY_R2.put(depthTokenObjectKey(todayKey()), JSON.stringify(updated));
        return json(updated);
      }

      return json({ error: "Not found" }, 404);
    } catch (error) {
      console.error(JSON.stringify({ level: "error", path: url.pathname, message: errorMessage(error) }));
      return json({ error: "Unable to serve Signal Daily API response" }, 500);
    }
  },

  async scheduled(
    controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    void ctx;
    await runScheduledPipeline(env, new Date(controller.scheduledTime), controller.cron);
  }
} satisfies ExportedHandler<Env>;

export default handler;

async function runScheduledPipeline(env: Env, generatedAt: Date, cron: string): Promise<void> {
  try {
    const result = await runHourlyNewsPipeline(env, generatedAt);
    console.log(JSON.stringify({
      level: "info",
      event: "hourly-news-pipeline-complete",
      cron,
      ...result
    }));
  } catch (error) {
    console.error(JSON.stringify({
      level: "error",
      event: "hourly-news-pipeline-failed",
      cron,
      generatedAt: generatedAt.toISOString(),
      message: errorMessage(error)
    }));
  }
}

async function runAdminPipeline(request: Request, env: Env): Promise<Response> {
  const expectedToken = pipelineAdminToken(env);
  if (!expectedToken) {
    return json({ error: "Not found" }, 404);
  }
  if (!isPipelineAdminRequest(request, env)) {
    return authError("Admin pipeline token required.", 401);
  }

  const result = await runHourlyNewsPipeline(env, new Date());
  return json({ ok: true, ...result }, 200, authHeaders());
}

async function runAdminSynthesisSlice(request: Request, env: Env, url: URL): Promise<Response> {
  const expectedToken = pipelineAdminToken(env);
  if (!expectedToken) {
    return json({ error: "Not found" }, 404);
  }
  if (!isPipelineAdminRequest(request, env)) {
    return authError("Admin pipeline token required.", 401);
  }

  const date = url.searchParams.get("date") ?? todayKey();
  const requestedStoryIDs = synthesisStoryIDs(url);
  const offset = positiveInteger(url.searchParams.get("offset"), 0);
  const limit = Math.min(positiveInteger(url.searchParams.get("limit"), 2), 4);
  const briefingKeyValue = briefingKey(date);
  const storedBriefing = await readR2JSON<BriefingDocument>(env, briefingKeyValue);
  if (!storedBriefing) {
    return json({ error: "Briefing not found for synthesis.", date }, 404, authHeaders());
  }

  const stories = flatStories(storedBriefing);
  const requestedStoryIDSet = new Set(requestedStoryIDs);
  const selectedStories = requestedStoryIDs.length > 0
    ? stories.filter((story) => requestedStoryIDSet.has(story.id))
    : stories.slice(offset, offset + limit);
  if (selectedStories.length === 0) {
    return json({
      ok: true,
      date,
      requestedStoryIDs,
      offset,
      limit,
      processed: 0,
      total: stories.length,
      done: requestedStoryIDs.length > 0 || offset >= stories.length
    }, 200, authHeaders());
  }

  const details = (await Promise.all(
    selectedStories.map((selectedStory) => readR2JSON<StoryDetailDocument>(env, `articles/${selectedStory.id}.json`))
  )).filter((detail): detail is StoryDetailDocument => Boolean(detail));

  if (details.length === 0) {
    return json({ error: "No matching article details found for synthesis.", date, offset, limit }, 404, authHeaders());
  }

  const selectedIDs = new Set(details.map((detail) => detail.id));
  const partialBriefing = briefingSlice(storedBriefing, selectedIDs);
  const enhanced = await enhanceBriefingWithOpenAI({ briefing: partialBriefing, details }, {
    apiKey: openAIAPIKey(env),
    model: openAIModel(env),
    fetcher: workerFetch,
    batchSize: Math.min(details.length, 4),
    storyLimit: details.length,
    retryDelayMs: 60_000
  });

  const enhancedStories = new Map(flatStories(enhanced.briefing).map((enhancedStory) => [enhancedStory.id, enhancedStory]));
  const mergedBriefing = mergeBriefingStories(storedBriefing, enhancedStories);
  await Promise.all([
    putJSON(env, briefingKeyValue, mergedBriefing, "public, max-age=300"),
    putJSON(env, "pipeline/latest.json", {
      ...(await readR2JSON<Record<string, unknown>>(env, "pipeline/latest.json") ?? {}),
      synthesis: {
        date,
        requestedStoryIDs,
        offset,
        limit,
        processed: enhanced.details.length,
        total: stories.length,
        storyIDs: enhanced.details.map((detail) => detail.id),
        updatedAt: new Date().toISOString()
      }
    }, "public, max-age=60"),
    ...enhanced.details.map((detail) => putJSON(env, `articles/${detail.id}.json`, detail, "public, max-age=300"))
  ]);

  return json({
    ok: true,
    date,
    requestedStoryIDs,
    offset,
    limit,
    processed: enhanced.details.length,
    total: stories.length,
    done: requestedStoryIDs.length > 0 || offset + selectedStories.length >= stories.length,
    storyIDs: enhanced.details.map((detail) => detail.id)
  }, 200, authHeaders());
}

async function runAdminEditorialQueue(request: Request, env: Env, url: URL): Promise<Response> {
  const expectedToken = pipelineAdminToken(env);
  if (!expectedToken) {
    return json({ error: "Not found" }, 404);
  }
  if (!isPipelineAdminRequest(request, env)) {
    return authError("Admin pipeline token required.", 401);
  }

  const date = url.searchParams.get("date") ?? todayKey();
  const limit = Math.min(positiveInteger(url.searchParams.get("limit"), 12), 40);
  const requestedStoryIDs = queryStoryIDs(url, 40);
  const storedBriefing = await readR2JSON<BriefingDocument>(env, briefingKey(date));
  if (!storedBriefing) {
    return json({ error: "Briefing not found for editorial queue.", date }, 404, authHeaders());
  }

  const allStories = flatStories(storedBriefing);
  const requestedSet = new Set(requestedStoryIDs);
  const selectedStories = requestedStoryIDs.length > 0
    ? allStories.filter((storySummary) => requestedSet.has(storySummary.id))
    : allStories.slice(positiveInteger(url.searchParams.get("offset"), 0), positiveInteger(url.searchParams.get("offset"), 0) + limit);
  const details = await Promise.all(
    selectedStories.map((storySummary) => readR2JSON<StoryDetailDocument>(env, `articles/${storySummary.id}.json`))
  );

  return json({
    ok: true,
    mode: "codex-editorial",
    date,
    total: allStories.length,
    selected: selectedStories.length,
    instructions: [
      "Rewrite only the fields in this queue. Preserve every id, region, category, confidence rating, sourceCount, and emotionalLoad.",
      "Use calm, evidence-weighted language. Do not use loaded terms as neutral fact.",
      "Keep claims attributed, separate knowns from unclear items, and avoid app/briefing/card wording in user-facing copy.",
      "POST JSON to /api/admin/editorial/apply with { date, stories: [...] }."
    ],
    stories: selectedStories.map((storySummary, index) => ({
      index,
      summary: storySummary,
      detail: details[index],
      sourceEvidence: details[index]?.sourceEvidence ?? []
    }))
  }, 200, authHeaders());
}

async function runAdminEditorialApply(request: Request, env: Env): Promise<Response> {
  const expectedToken = pipelineAdminToken(env);
  if (!expectedToken) {
    return json({ error: "Not found" }, 404);
  }
  if (!isPipelineAdminRequest(request, env)) {
    return authError("Admin pipeline token required.", 401);
  }

  const body = await readObject(request);
  const date = stringValue(body.date) || todayKey();
  const patches = editorialPatchesFromBody(body);
  if (patches.length === 0) {
    return authError("No editorial story patches supplied.", 400);
  }

  const briefingKeyValue = briefingKey(date);
  const storedBriefing = await readR2JSON<BriefingDocument>(env, briefingKeyValue);
  if (!storedBriefing) {
    return json({ error: "Briefing not found for editorial apply.", date }, 404, authHeaders());
  }

  const patchByID = new Map(patches.map((patch) => [patch.id, patch]));
  const existingDetails = (await Promise.all(
    patches.map((patch) => readR2JSON<StoryDetailDocument>(env, `articles/${patch.id}.json`))
  )).filter((detail): detail is StoryDetailDocument => Boolean(detail));
  const knownIDs = new Set(flatStories(storedBriefing).map((storySummary) => storySummary.id));
  const patchedDetails = existingDetails
    .filter((detail) => knownIDs.has(detail.id))
    .map((detail) => applyEditorialPatchToDetail(detail, patchByID.get(detail.id)));
  const patchedStories = new Map(patches.map((patch) => [patch.id, patch]));
  const updatedBriefing = applyEditorialPatchesToBriefing(storedBriefing, patchedStories);

  await Promise.all([
    putJSON(env, briefingKeyValue, updatedBriefing, "public, max-age=300"),
    putJSON(env, "pipeline/latest.json", {
      ...(await readR2JSON<Record<string, unknown>>(env, "pipeline/latest.json") ?? {}),
      editorial: {
        mode: "codex",
        date,
        requested: patches.length,
        applied: patchedDetails.length,
        storyIDs: patchedDetails.map((detail) => detail.id),
        updatedAt: new Date().toISOString()
      }
    }, "public, max-age=60"),
    ...patchedDetails.map((detail) => putJSON(env, `articles/${detail.id}.json`, detail, "public, max-age=300"))
  ]);

  return json({
    ok: true,
    mode: "codex-editorial",
    date,
    requested: patches.length,
    applied: patchedDetails.length,
    storyIDs: patchedDetails.map((detail) => detail.id)
  }, 200, authHeaders());
}

async function fromR2OrMock(env: Env, key: string, fallback: JSONValue): Promise<Response> {
  const object = await env.SIGNAL_DAILY_R2.get(key);
  if (!object) {
    return json(fallback, 200, { "x-signal-source": "mock-fallback" });
  }

  const headers = new Headers(jsonHeaders);
  headers.set("cache-control", object.httpMetadata?.cacheControl ?? "public, max-age=300");
  headers.set("etag", object.httpEtag);
  headers.set("x-signal-source", "r2");
  return new Response(object.body, { headers });
}

async function signUp(request: Request, env: Env): Promise<Response> {
  const body = await readObject(request);
  const email = normalizedEmail(body.email);
  const password = stringValue(body.password);
  const name = stringValue(body.name).trim();
  const validationError = authValidationError(email, password, name);
  if (validationError) {
    return authError(validationError, 400);
  }

  const userKey = userObjectKey(email);
  const existingUser = await readR2JSON<StoredUser>(env, userKey);
  if (existingUser) {
    return authError("An account already exists for this email.", 409);
  }

  const now = new Date().toISOString();
  const user: StoredUser = {
    id: `user_${await sha256Hex(email).then((hash) => hash.slice(0, 16))}`,
    email,
    name,
    passwordHash: await passwordHash(email, password),
    createdAt: now
  };
  await env.SIGNAL_DAILY_R2.put(userKey, JSON.stringify(user));

  return json(await createSession(env, publicUser(user)), 201, authHeaders());
}

async function storedPreferences(env: Env): Promise<JSONValue> {
  return await readR2JSON<JSONValue>(env, preferencesObjectKey()) ?? userPreferences;
}

async function storedDepthTokenStatus(env: Env): Promise<StoredDepthTokenStatus> {
  const key = depthTokenObjectKey(todayKey());
  const stored = await readR2JSON<StoredDepthTokenStatus>(env, key);
  if (stored) {
    return stored;
  }
  const resetAt = new Date();
  resetAt.setUTCDate(resetAt.getUTCDate() + 1);
  resetAt.setUTCHours(0, 0, 0, 0);
  return {
    ...depthTokenStatus,
    remaining: depthTokenStatus.allowedPerDay,
    resetAt: resetAt.toISOString()
  };
}

async function signIn(request: Request, env: Env): Promise<Response> {
  const body = await readObject(request);
  const email = normalizedEmail(body.email);
  const password = stringValue(body.password);
  if (!email || password.length < 8) {
    return authError("Use a valid email and password.", 400);
  }

  const user = await readR2JSON<StoredUser>(env, userObjectKey(email));
  if (!user || user.passwordHash !== await passwordHash(email, password)) {
    return authError("We could not sign you in with those details.", 401);
  }

  return json(await createSession(env, publicUser(user)), 200, authHeaders());
}

async function startAppleWebSignIn(request: Request, env: Env): Promise<Response> {
  const body = await readObject(request);
  const clientID = appleWebClientID(env);
  const redirectURI = appleWebRedirectURI(request, env);
  if (!clientID || !redirectURI) {
    return authError("Apple browser sign-in is not configured yet.", 503);
  }

  const state = crypto.randomUUID();
  const nonce = crypto.randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 1000 * 60 * 10);
  const mode = stringValue(body.mode) || "signIn";
  const stateDocument: AppleWebAuthState = {
    state,
    nonce,
    mode,
    clientID,
    redirectURI,
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString()
  };
  await putJSON(env, appleWebStateObjectKey(state), stateDocument, "private, no-store");

  const authorizationURL = new URL("https://appleid.apple.com/auth/authorize");
  authorizationURL.searchParams.set("client_id", clientID);
  authorizationURL.searchParams.set("redirect_uri", redirectURI);
  authorizationURL.searchParams.set("response_type", "code id_token");
  authorizationURL.searchParams.set("response_mode", "form_post");
  authorizationURL.searchParams.set("scope", "name email");
  authorizationURL.searchParams.set("state", state);
  authorizationURL.searchParams.set("nonce", nonce);

  return json({ authorizationURL: authorizationURL.toString(), state }, 200, authHeaders());
}

async function completeAppleWebCallback(request: Request, env: Env): Promise<Response> {
  const form = await readFormObject(request);
  const state = stringValue(form.state);
  const error = stringValue(form.error);
  if (error) {
    return appleWebAppRedirect({ error });
  }

  const storedState = state ? await readR2JSON<AppleWebAuthState>(env, appleWebStateObjectKey(state)) : null;
  if (!storedState || Date.parse(storedState.expiresAt) < Date.now()) {
    return appleWebAppRedirect({ error: "expired_state" });
  }

  const identityToken = stringValue(form.id_token);
  const claims = parseAppleClaims(identityToken);
  if (!claims || claims.iss !== "https://appleid.apple.com" || claims.aud !== storedState.clientID || !claims.sub) {
    return appleWebAppRedirect({ error: "invalid_identity" });
  }
  if (claims.exp && claims.exp * 1000 < Date.now()) {
    return appleWebAppRedirect({ error: "expired_identity" });
  }
  if (claims.nonce && claims.nonce !== storedState.nonce) {
    return appleWebAppRedirect({ error: "invalid_nonce" });
  }

  const profile = parseAppleWebUserProfile(stringValue(form.user));
  const email = normalizedEmail(claims.email) || normalizedEmail(profile?.email) || `${claims.sub}@privaterelay.appleid.com`;
  const name = appleWebDisplayName(profile) || "Apple Reader";
  const result = await createAppleSession(env, claims.sub, email, name);
  const handoffToken = crypto.randomUUID();
  const handoff: AppleWebAuthHandoff = {
    session: result.session,
    expiresAt: new Date(Date.now() + 1000 * 60 * 5).toISOString()
  };

  await Promise.all([
    putJSON(env, appleWebHandoffObjectKey(handoffToken), handoff, "private, no-store"),
    env.SIGNAL_DAILY_R2.delete(appleWebStateObjectKey(state))
  ]);

  return appleWebAppRedirect({ handoff: handoffToken });
}

async function redeemAppleWebHandoff(request: Request, env: Env): Promise<Response> {
  const body = await readObject(request);
  const handoffToken = stringValue(body.handoffToken);
  const key = appleWebHandoffObjectKey(handoffToken);
  const handoff = handoffToken ? await readR2JSON<AppleWebAuthHandoff>(env, key) : null;
  if (!handoff || Date.parse(handoff.expiresAt) < Date.now()) {
    return authError("Apple sign-in expired before it returned to the app. Try again.", 401);
  }

  await env.SIGNAL_DAILY_R2.delete(key);
  return json(handoff.session, 200, authHeaders());
}

async function signInWithApple(request: Request, env: Env): Promise<Response> {
  const body = await readObject(request);
  const identityToken = stringValue(body.identityToken);
  const userIdentifier = stringValue(body.userIdentifier);
  const rawNonce = stringValue(body.rawNonce);
  const claims = parseAppleClaims(identityToken);

  if (!claims || claims.iss !== "https://appleid.apple.com" || claims.aud !== appleNativeClientID(env) || claims.sub !== userIdentifier) {
    return authError("Apple sign-in could not be verified.", 401);
  }
  if (claims.exp && claims.exp * 1000 < Date.now()) {
    return authError("Apple sign-in expired. Try again.", 401);
  }
  if (rawNonce && claims.nonce !== await sha256Hex(rawNonce)) {
    return authError("Apple sign-in nonce could not be verified.", 401);
  }

  const email = normalizedEmail(body.email) || normalizedEmail(claims.email) || `${userIdentifier}@privaterelay.appleid.com`;
  const name = stringValue(body.name).trim() || "Apple Reader";
  const result = await createAppleSession(env, userIdentifier, email, name);
  return json(result.session, result.status, authHeaders());
}

async function createAppleSession(
  env: Env,
  userIdentifier: string,
  email: string,
  name: string
): Promise<{ session: AuthSession; status: number }> {
  const userKey = appleUserObjectKey(userIdentifier);
  const emailUserKey = userObjectKey(email);
  const existingUser = await readR2JSON<StoredUser>(env, userKey);
  const existingEmailUser = existingUser ? null : await readR2JSON<StoredUser>(env, emailUserKey);
  const user: StoredUser = existingUser ?? existingEmailUser ?? {
    id: `apple_${await sha256Hex(userIdentifier).then((hash) => hash.slice(0, 16))}`,
    email,
    name,
    passwordHash: "apple",
    createdAt: new Date().toISOString()
  };

  const refreshedUser = {
    ...user,
    passwordHash: "apple",
    email: user.email || email,
    name: user.name === "Apple Reader" ? name : user.name
  };
  await env.SIGNAL_DAILY_R2.put(userKey, JSON.stringify(refreshedUser));
  if (existingEmailUser) {
    await env.SIGNAL_DAILY_R2.delete(emailUserKey);
  }

  return {
    session: await createSession(env, publicUser(refreshedUser)),
    status: existingUser ? 200 : 201
  };
}

async function currentSession(request: Request, env: Env): Promise<Response> {
  const token = bearerToken(request);
  if (!token) {
    return authError("Missing session token.", 401);
  }

  const session = await readR2JSON<AuthSession>(env, sessionObjectKey(token));
  if (!session || Date.parse(session.expiresAt) < Date.now()) {
    return authError("Session expired.", 401);
  }

  return json(session, 200, authHeaders());
}

async function signOut(request: Request, env: Env): Promise<Response> {
  const token = bearerToken(request);
  if (token) {
    await env.SIGNAL_DAILY_R2.delete(sessionObjectKey(token));
  }
  return json({ ok: true }, 200, authHeaders());
}

async function createSession(env: Env, user: AuthUser): Promise<AuthSession> {
  const token = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30).toISOString();
  const session: AuthSession = { token, user, expiresAt };
  await env.SIGNAL_DAILY_R2.put(sessionObjectKey(token), JSON.stringify(session));
  return session;
}

function publicUser(user: StoredUser): AuthUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name
  };
}

async function readR2JSON<T>(env: Env, key: string): Promise<T | null> {
  const object = await env.SIGNAL_DAILY_R2.get(key);
  if (!object) {
    return null;
  }
  return await object.json<T>();
}

async function readObject(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    return {};
  }
  const parsed = await request.json();
  return parsed && typeof parsed === "object" && !Array.isArray(parsed)
    ? parsed as Record<string, unknown>
    : {};
}

async function readFormObject(request: Request): Promise<Record<string, string>> {
  if (!request.headers.get("content-type")?.includes("application/x-www-form-urlencoded")) {
    return {};
  }
  const params = new URLSearchParams(await request.text());
  return Object.fromEntries(params.entries());
}

async function readJSON(request: Request): Promise<JSONValue> {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    return userPreferences;
  }

  const parsed = await request.json();
  if (parsed && typeof parsed === "object") {
    return parsed as JSONValue;
  }
  return userPreferences;
}

function json(body: JSONValue, status = 200, extraHeaders?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...extraHeaders }
  });
}

function authError(message: string, status: number): Response {
  return json({ error: message }, status, authHeaders());
}

function authHeaders(): Record<string, string> {
  return { "cache-control": "private, no-store" };
}

function match(pathname: string, pattern: RegExp): RegExpMatchArray | null {
  return pathname.match(pattern);
}

function updatesKey(date: string): string {
  return `briefings/${date}/updates.json`;
}

function briefingKey(date: string): string {
  return `briefings/${date}/global.json`;
}

function todayKey(date: Date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

function authValidationError(email: string, password: string, name: string): string | null {
  if (!email.includes("@") || !email.includes(".")) {
    return "Enter a valid email address.";
  }
  if (password.length < 8) {
    return "Use at least 8 characters for your password.";
  }
  if (!name) {
    return "Enter your name.";
  }
  return null;
}

function normalizedEmail(value: unknown): string {
  return stringValue(value).trim().toLowerCase();
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function bearerToken(request: Request): string | null {
  const value = request.headers.get("authorization") ?? "";
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

function pipelineAdminToken(env: Env): string | undefined {
  return (env as Env & { PIPELINE_ADMIN_TOKEN?: string }).PIPELINE_ADMIN_TOKEN;
}

function isPipelineAdminRequest(request: Request, env: Env): boolean {
  const token = bearerToken(request);
  return Boolean(token && token === pipelineAdminToken(env));
}

function openAIAPIKey(env: Env): string | undefined {
  return (env as Env & { OPENAI_API_KEY?: string }).OPENAI_API_KEY;
}

function openAIModel(env: Env): string | undefined {
  return (env as Env & { OPENAI_MODEL?: string }).OPENAI_MODEL ?? "gpt-5.4-nano";
}

function appleWebClientID(env: Env): string | undefined {
  return (env as Env & { APPLE_WEB_CLIENT_ID?: string }).APPLE_WEB_CLIENT_ID;
}

function appleNativeClientID(env: Env): string {
  return (env as Env & { APPLE_NATIVE_CLIENT_ID?: string }).APPLE_NATIVE_CLIENT_ID ?? "com.signaldaily.app";
}

function appleWebRedirectURI(request: Request, env: Env): string {
  const configuredURI = (env as Env & { APPLE_WEB_REDIRECT_URI?: string }).APPLE_WEB_REDIRECT_URI;
  if (configuredURI) {
    return configuredURI;
  }
  return `${new URL(request.url).origin}/api/auth/apple/web/callback`;
}

function appleWebAppRedirect(params: Record<string, string>): Response {
  const callbackURL = new URL("thebrief://apple-auth");
  Object.entries(params).forEach(([key, value]) => callbackURL.searchParams.set(key, value));
  const location = callbackURL.toString();
  return new Response(appleWebReturnHTML(location), {
    status: 303,
    headers: {
      ...authHeaders(),
      "content-type": "text/html; charset=utf-8",
      location
    }
  });
}

function appleWebReturnHTML(callbackURL: string): string {
  const encodedCallback = JSON.stringify(callbackURL);
  return `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Return to The Brief</title></head><body><p>Returning to The Brief...</p><p><a href="${escapeHTML(callbackURL)}">Open The Brief</a></p><script>location.replace(${encodedCallback});</script></body></html>`;
}

function parseAppleWebUserProfile(value: string): AppleWebUserProfile | null {
  if (!value) {
    return null;
  }
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed as AppleWebUserProfile : null;
  } catch {
    return null;
  }
}

function appleWebDisplayName(profile: AppleWebUserProfile | null): string {
  const firstName = profile?.name?.firstName?.trim() ?? "";
  const lastName = profile?.name?.lastName?.trim() ?? "";
  return [firstName, lastName].filter(Boolean).join(" ");
}

function escapeHTML(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function positiveInteger(value: string | null, fallback: number): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
}

function synthesisStoryIDs(url: URL): string[] {
  return queryStoryIDs(url, 4);
}

function queryStoryIDs(url: URL, maxCount: number): string[] {
  const values = [
    ...url.searchParams.getAll("storyId"),
    ...url.searchParams.getAll("storyIds").flatMap((value) => value.split(","))
  ];
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))].slice(0, maxCount);
}

function flatStories(document: BriefingDocument): BriefingStorySummary[] {
  return document.sections.flatMap((section) => section.stories);
}

function briefingSlice(document: BriefingDocument, storyIDs: Set<string>): BriefingDocument {
  const sections = document.sections
    .map((section): BriefingSection => ({
      ...section,
      stories: section.stories.filter((storySummary) => storyIDs.has(storySummary.id))
    }))
    .filter((section) => section.stories.length > 0);
  return {
    ...document,
    storyCount: sections.reduce((count, section) => count + section.stories.length, 0),
    sections
  };
}

function mergeBriefingStories(
  document: BriefingDocument,
  enhancedStories: Map<string, BriefingStorySummary>
): BriefingDocument {
  return {
    ...document,
    sections: document.sections.map((section) => ({
      ...section,
      stories: section.stories.map((storySummary) => enhancedStories.get(storySummary.id) ?? storySummary)
    }))
  };
}

function editorialPatchesFromBody(body: Record<string, unknown>): EditorialStoryPatch[] {
  const stories = Array.isArray(body.stories) ? body.stories : [];
  return stories.flatMap((value): EditorialStoryPatch[] => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return [];
    }
    const record = value as Record<string, unknown>;
    const id = stringValue(record.id);
    if (!id) {
      return [];
    }
    return [{
      id,
      headline: optionalCleanString(record.headline),
      summary: optionalCleanString(record.summary),
      whyItMatters: optionalCleanString(record.whyItMatters),
      whatHappened: optionalCleanString(record.whatHappened),
      whatWeKnow: optionalCleanStringArray(record.whatWeKnow),
      whatIsUnclear: optionalCleanStringArray(record.whatIsUnclear),
      confidenceReason: optionalCleanString(record.confidenceReason),
      framingCheck: editorialFramingCheck(record.framingCheck),
      biasAuditNotes: optionalCleanStringArray(record.biasAuditNotes)
    }];
  });
}

function applyEditorialPatchesToBriefing(
  document: BriefingDocument,
  patches: Map<string, EditorialStoryPatch>
): BriefingDocument {
  return {
    ...document,
    sections: document.sections.map((section) => ({
      ...section,
      stories: section.stories.map((storySummary) => {
        const patch = patches.get(storySummary.id);
        if (!patch) {
          return storySummary;
        }
        return {
          ...storySummary,
          headline: patch.headline ?? storySummary.headline,
          summary: patch.summary ?? storySummary.summary,
          whyItMatters: patch.whyItMatters ?? storySummary.whyItMatters
        };
      })
    }))
  };
}

function applyEditorialPatchToDetail(
  detail: StoryDetailDocument,
  patch: EditorialStoryPatch | undefined
): StoryDetailDocument {
  if (!patch) {
    return detail;
  }
  return {
    ...detail,
    headline: patch.headline ?? detail.headline,
    whatHappened: patch.whatHappened ?? detail.whatHappened,
    whyItMatters: patch.whyItMatters ?? detail.whyItMatters,
    whatWeKnow: patch.whatWeKnow ?? detail.whatWeKnow,
    whatIsUnclear: patch.whatIsUnclear ?? detail.whatIsUnclear,
    framingCheck: patch.framingCheck ?? detail.framingCheck,
    confidence: {
      ...detail.confidence,
      reason: patch.confidenceReason ?? detail.confidence.reason
    },
    biasAudit: {
      ...detail.biasAudit,
      notes: patch.biasAuditNotes ?? detail.biasAudit.notes
    },
    evidenceCheck: {
      ...detail.evidenceCheck,
      claim: patch.headline ?? detail.evidenceCheck.claim
    }
  };
}

function editorialFramingCheck(value: unknown): StoryDetailDocument["framingCheck"] | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }
  const record = value as Record<string, unknown>;
  const westernMainstream = optionalCleanString(record.westernMainstream);
  const localRegional = optionalCleanString(record.localRegional);
  const officialGovernment = optionalCleanString(record.officialGovernment);
  const affectedPopulation = optionalCleanString(record.affectedPopulation);
  const independentEvidence = optionalCleanString(record.independentEvidence);
  if (!westernMainstream || !localRegional || !officialGovernment || !affectedPopulation || !independentEvidence) {
    return undefined;
  }
  return {
    westernMainstream,
    localRegional,
    officialGovernment,
    affectedPopulation,
    independentEvidence,
    humanRightsNGO: optionalCleanString(record.humanRightsNGO) ?? null,
    opposingSide: optionalCleanString(record.opposingSide) ?? null
  };
}

function optionalCleanString(value: unknown): string | undefined {
  const cleaned = stringValue(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return cleaned ? cleaned : undefined;
}

function optionalCleanStringArray(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }
  const items = value.flatMap((item) => {
    const cleaned = optionalCleanString(item);
    return cleaned ? [cleaned] : [];
  });
  return items.length > 0 ? items.slice(0, 6) : undefined;
}

async function putJSON(env: Env, key: string, value: unknown, cacheControl: string): Promise<void> {
  await env.SIGNAL_DAILY_R2.put(key, JSON.stringify(value), {
    httpMetadata: {
      contentType: "application/json; charset=utf-8",
      cacheControl
    }
  });
}

const workerFetch: typeof fetch = (input, init) => fetch(input, init);

function userObjectKey(email: string): string {
  return `users/${encodeURIComponent(email)}.json`;
}

function sessionObjectKey(token: string): string {
  return `sessions/${encodeURIComponent(token)}.json`;
}

function preferencesObjectKey(): string {
  return "users/preferences/default.json";
}

function depthTokenObjectKey(date: string): string {
  return `users/depth-tokens/${date}.json`;
}

function appleUserObjectKey(userIdentifier: string): string {
  return `users/apple/${encodeURIComponent(userIdentifier)}.json`;
}

function appleWebStateObjectKey(state: string): string {
  return `auth/apple-web/states/${encodeURIComponent(state)}.json`;
}

function appleWebHandoffObjectKey(handoffToken: string): string {
  return `auth/apple-web/handoffs/${encodeURIComponent(handoffToken)}.json`;
}

function parseAppleClaims(identityToken: string): AppleTokenClaims | null {
  const parts = identityToken.split(".");
  if (parts.length < 2) {
    return null;
  }
  try {
    const decoded = JSON.parse(base64URLDecode(parts[1]));
    return decoded && typeof decoded === "object" ? decoded as AppleTokenClaims : null;
  } catch {
    return null;
  }
}

function base64URLDecode(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(normalized.length + (4 - normalized.length % 4) % 4, "=");
  const binary = atob(padded);
  return decodeURIComponent([...binary].map((character) => {
    return `%${character.charCodeAt(0).toString(16).padStart(2, "0")}`;
  }).join(""));
}

async function passwordHash(email: string, password: string): Promise<string> {
  return await sha256Hex(`${email}:${password}`);
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown error";
}
