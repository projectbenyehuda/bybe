# Accessing the Local Dev Server

## The dev server is reachable — do NOT prematurely conclude it is down

The project's puma dev server typically runs on `http://localhost:3000` (often
already running in another terminal). The Bash sandbox does **NOT** block
localhost access — a sandboxed `curl http://localhost:3000/` returns a normal
HTTP response.

## CRITICAL: Use a generous timeout when probing

Rails in development mode can be **slow to respond**, especially on the first
request after a while (eager class loading, on-demand asset compilation). A
short curl timeout will abort before the server responds.

- ❌ **WRONG**: `curl --max-time 3 ...` → times out, returns `000`, and you
  wrongly conclude "no server running."
- ✅ **RIGHT**: `curl --max-time 15 ...` (10–15s) to allow for slow dev-mode
  first responses.

**A curl timeout (`http_code=000`) or a slow response does NOT mean the server
is down.** Do not add `|| echo "no-server"` style fallbacks that mask a timeout
as an absence of server.

## Before concluding the server is unavailable, verify it directly

```bash
ss -ltnp 2>/dev/null | grep ':3000'      # is anything listening on :3000?
ps aux | grep -iE 'puma|rails s' | grep -v grep   # is puma running?
```

Only if BOTH show nothing is the server actually not running.

## Historical context

This rule was added after a `curl --max-time 3` probe timed out and was
misreported as "no server running," when in fact puma was up on :3000 the whole
time and the sandbox permitted the connection. The failure was a too-short
timeout plus a misleading fallback, not an access restriction.

## Note: HTML vs. rendered screenshots

`curl` gives HTML/CSS only. To verify **visual/pixel** layout (e.g. CSS
alignment), a headless browser (the Chrome/Selenium stack used by `js: true`
system specs) is required — plain `curl` is not enough.
