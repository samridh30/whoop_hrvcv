import express from "express";
import dotenv from "dotenv";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const tokenStorePath = path.join(__dirname, "token_store.json");

const app = express();
app.use(express.json());

const {
  PORT = "8787",
  BACKEND_BASE_URL,
  WHOOP_CLIENT_ID,
  WHOOP_CLIENT_SECRET,
  WHOOP_REDIRECT_URI,
  WHOOP_SCOPE = "offline read:recovery"
} = process.env;

const WHOOP_AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth";
const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";
const WHOOP_RECOVERY_URL = "https://api.prod.whoop.com/developer/v2/recovery";
const authStateStore = new Map();

function normalizedWhoopScope(rawScope) {
  const parts = (rawScope || "")
    .split(/\s+/)
    .map((value) => value.trim())
    .filter(Boolean);

  if (!parts.includes("offline")) {
    parts.unshift("offline");
  }

  if (!parts.includes("read:recovery")) {
    parts.push("read:recovery");
  }

  return parts.join(" ");
}

const effectiveScope = normalizedWhoopScope(WHOOP_SCOPE);

function issueAuthState() {
  const state = randomBytes(24).toString("hex");
  const expiresAt = Date.now() + 10 * 60 * 1000;
  authStateStore.set(state, expiresAt);
  return state;
}

function consumeAuthState(state) {
  const expiresAt = authStateStore.get(state);
  authStateStore.delete(state);
  if (!expiresAt) return false;
  return Date.now() <= expiresAt;
}

function ensureConfig() {
  const missing = [];
  if (!BACKEND_BASE_URL) missing.push("BACKEND_BASE_URL");
  if (!WHOOP_CLIENT_ID) missing.push("WHOOP_CLIENT_ID");
  if (!WHOOP_CLIENT_SECRET) missing.push("WHOOP_CLIENT_SECRET");
  if (!WHOOP_REDIRECT_URI) missing.push("WHOOP_REDIRECT_URI");

  if (missing.length > 0) {
    throw new Error(`Missing required env vars: ${missing.join(", ")}`);
  }
}

async function readTokenStore() {
  try {
    const raw = await fs.readFile(tokenStorePath, "utf8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function writeTokenStore(value) {
  await fs.writeFile(tokenStorePath, JSON.stringify(value, null, 2), "utf8");
}

function tokenIsFresh(store) {
  if (!store?.access_token || !store?.expires_at) return false;
  const now = Math.floor(Date.now() / 1000);
  return store.expires_at - now > 120;
}

async function fetchWhoopToken(params) {
  const body = new URLSearchParams(params);
  const response = await fetch(WHOOP_TOKEN_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json"
    },
    body
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = payload?.error_description || payload?.error || JSON.stringify(payload);
    throw new Error(`WHOOP token request failed (${response.status}): ${detail}`);
  }

  return payload;
}

function applyTokenPayload(previous, payload) {
  const now = Math.floor(Date.now() / 1000);
  return {
    access_token: payload.access_token,
    refresh_token: payload.refresh_token || previous?.refresh_token,
    expires_at: now + (payload.expires_in || 0),
    token_type: payload.token_type,
    scope: payload.scope || previous?.scope || effectiveScope,
    updated_at: new Date().toISOString()
  };
}

async function ensureAccessToken() {
  const existing = await readTokenStore();
  if (!existing?.refresh_token) {
    const error = new Error("WHOOP account not connected");
    error.code = "NOT_CONNECTED";
    throw error;
  }

  if (tokenIsFresh(existing)) {
    return existing.access_token;
  }

  const refreshed = await fetchWhoopToken({
    grant_type: "refresh_token",
    refresh_token: existing.refresh_token,
    client_id: WHOOP_CLIENT_ID,
    client_secret: WHOOP_CLIENT_SECRET,
    scope: effectiveScope
  });

  const updated = applyTokenPayload(existing, refreshed);
  await writeTokenStore(updated);
  return updated.access_token;
}

async function fetchRecoveryPage(accessToken, { start, end, nextToken }) {
  const url = new URL(WHOOP_RECOVERY_URL);
  url.searchParams.set("start", start);
  url.searchParams.set("end", end);
  url.searchParams.set("limit", "25");
  if (nextToken) url.searchParams.set("nextToken", nextToken);

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json"
    }
  });

  if (response.status === 401) {
    const error = new Error("WHOOP token expired");
    error.code = "UNAUTHORIZED";
    throw error;
  }

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`WHOOP recovery failed (${response.status}): ${text}`);
  }

  return response.json();
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/", (_req, res) => {
  res
    .status(200)
    .send("WHOOP backend is running. Use /auth/start to login and /health to test service status.");
});

app.get("/auth/start", (_req, res) => {
  const state = issueAuthState();
  const url = new URL(WHOOP_AUTH_URL);
  url.searchParams.set("client_id", WHOOP_CLIENT_ID);
  url.searchParams.set("redirect_uri", WHOOP_REDIRECT_URI);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", effectiveScope);
  url.searchParams.set("state", state);
  res.redirect(url.toString());
});

app.get("/auth/callback", async (req, res) => {
  const code = req.query.code;
  const state = req.query.state;
  const oauthError = req.query.error;
  const oauthErrorDescription = req.query.error_description;

  if (oauthError) {
    res
      .status(400)
      .send(
        `WHOOP OAuth error: ${oauthError}${oauthErrorDescription ? ` - ${oauthErrorDescription}` : ""}`
      );
    return;
  }

  if (!code || typeof code !== "string") {
    res.status(400).send("Missing authorization code. Start from /auth/start and complete WHOOP login.");
    return;
  }

  if (!state || typeof state !== "string" || !consumeAuthState(state)) {
    res.status(400).send("Invalid OAuth state. Start login again from /auth/start.");
    return;
  }

  try {
    const tokenPayload = await fetchWhoopToken({
      grant_type: "authorization_code",
      code,
      client_id: WHOOP_CLIENT_ID,
      client_secret: WHOOP_CLIENT_SECRET,
      redirect_uri: WHOOP_REDIRECT_URI
    });

    const store = applyTokenPayload(null, tokenPayload);
    await writeTokenStore(store);

    res.send("WHOOP connected. Return to the app and refresh.");
  } catch (error) {
    res.status(500).send(`Failed to connect WHOOP: ${error.message}`);
  }
});

app.get("/auth/status", async (_req, res) => {
  const store = await readTokenStore();
  res.json({ connected: Boolean(store?.refresh_token) });
});

app.get("/hrv", async (req, res) => {
  const days = Number.parseInt(req.query.days || "7", 10);
  const durationDays = Number.isNaN(days) ? 7 : Math.max(1, Math.min(days, 30));

  const endDate = new Date();
  const startDate = new Date(endDate);
  startDate.setDate(endDate.getDate() - durationDays);

  let accessToken;
  try {
    accessToken = await ensureAccessToken();
  } catch (error) {
    if (error.code === "NOT_CONNECTED") {
      res.status(401).json({ error: "not_connected" });
      return;
    }
    res.status(500).json({ error: error.message || "token_error" });
    return;
  }

  const start = startDate.toISOString();
  const end = endDate.toISOString();

  try {
    const records = [];
    let nextToken = null;

    do {
      const page = await fetchRecoveryPage(accessToken, { start, end, nextToken });
      records.push(...(page.records || []));
      nextToken = page.next_token || null;
    } while (nextToken);

    const samples = records
      .filter((record) => record.score_state === "SCORED" && record.score?.hrv_rmssd_milli != null)
      .map((record) => ({
        cycle_id: record.cycle_id,
        date: record.created_at,
        hrv_rmssd_milli: record.score.hrv_rmssd_milli
      }))
      .sort((a, b) => new Date(a.date) - new Date(b.date));

    res.json({ samples });
  } catch (error) {
    if (error.code === "UNAUTHORIZED") {
      await fs.unlink(tokenStorePath).catch(() => {});
      res.status(401).json({ error: "not_connected" });
      return;
    }
    res.status(500).json({ error: error.message || "recovery_error" });
  }
});

try {
  ensureConfig();
  app.listen(Number(PORT), () => {
    console.log(`WHOOP backend listening on http://localhost:${PORT}`);
  });
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
