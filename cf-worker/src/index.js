// Keeps OPENAI_API_KEY server-side. The Flutter web app is compiled to a
// public JS bundle, so any key baked into it gets scraped and auto-revoked
// by OpenAI's own leaked-key scanning within hours of deploy — this worker
// is what the client calls instead, and it's the only thing that ever holds
// the real key (set via `wrangler secret put OPENAI_API_KEY`).
const ALLOWED_ORIGIN = "https://tsrnb.github.io";

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-Client-Key",
  };
}

function json(body, status, headers) {
  return new Response(JSON.stringify(body), { status, headers: { ...headers, "Content-Type": "application/json" } });
}

export default {
  async fetch(request, env) {
    const headers = corsHeaders();
    if (request.method === "OPTIONS") return new Response(null, { headers });

    const url = new URL(request.url);

    // A low-value shared secret, not an OpenAI key — its only job is to
    // stop randoms who stumble on this URL from spending your OpenAI
    // credits. It still ends up in the compiled client JS, same as before,
    // but there's nothing here for OpenAI's scanners to find and revoke.
    const clientKey = request.headers.get("X-Client-Key");
    if (!env.CLIENT_SHARED_SECRET || clientKey !== env.CLIENT_SHARED_SECRET) {
      return json({ error: { message: "unauthorized" } }, 401, headers);
    }

    if (url.pathname === "/health" && request.method === "GET") {
      let ok = false;
      try {
        const res = await fetch("https://api.openai.com/v1/models", {
          headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}` },
        });
        ok = res.status === 200;
      } catch (_) {
        ok = false;
      }
      return json({ ok }, 200, headers);
    }

    if (url.pathname === "/chat" && request.method === "POST") {
      const body = await request.text();
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body,
      });
      const text = await res.text();
      return new Response(text, { status: res.status, headers: { ...headers, "Content-Type": "application/json" } });
    }

    return json({ error: { message: "not found" } }, 404, headers);
  },
};
