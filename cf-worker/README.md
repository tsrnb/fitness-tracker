# cuttracker-ai-proxy

A small Cloudflare Worker that stands between the Flutter web app and
OpenAI. The app used to call OpenAI directly with an embedded API key —
that key showed up in plaintext in the compiled `main.dart.js`, and since
the site is on public GitHub Pages, OpenAI's own leaked-key scanner found
and auto-revoked it (twice). This worker is the fix: the real
`OPENAI_API_KEY` lives only in Cloudflare, never in any file that gets
built into the app.

## One-time setup

From this directory (`cf-worker/`):

```bash
npx wrangler login
```

Opens a browser to authorize wrangler against your Cloudflare account (free
tier is enough — Workers' free plan covers this easily for 2 users).

```bash
npx wrangler secret put OPENAI_API_KEY
```

Paste your real OpenAI key when prompted (get/rotate one at
platform.openai.com/api-keys — make sure billing is set up there too).

```bash
npx wrangler secret put CLIENT_SHARED_SECRET
```

Paste any random string you make up (e.g. `openssl rand -hex 24`). This is
**not** an OpenAI key — it's just a shared password between the app and
this worker so a stranger who finds the worker URL can't spend your OpenAI
credits. It'll end up in the compiled app JS same as any client secret
would, but there's nothing here for OpenAI's scanner to find, since it's
meaningless outside this worker.

```bash
npx wrangler deploy
```

Prints the deployed URL, something like:

```
https://cuttracker-ai-proxy.<your-subdomain>.workers.dev
```

## Wiring it into the app

In `flutter_app/secrets.json` (git-ignored, see `secrets.example.json`):

```json
{
  "AI_PROXY_URL": "https://cuttracker-ai-proxy.<your-subdomain>.workers.dev",
  "AI_PROXY_CLIENT_KEY": "the same random string you gave wrangler secret put CLIENT_SHARED_SECRET"
}
```

Then build/deploy the Flutter app as usual
(`bash scripts/deploy-gh-pages.sh`) — it'll pick these up via
`--dart-define-from-file`.

## If the origin changes

`src/index.js` hardcodes `ALLOWED_ORIGIN` to
`https://tsrnb.github.io` for CORS. Update that constant (and redeploy with
`npx wrangler deploy`) if the app ever moves to a different URL.

## Redeploying after code changes

```bash
npx wrangler deploy
```

Secrets persist across deploys — only `wrangler secret put` again if a
secret itself needs to change.
