# Local patches

Fixes applied to the cloned upstream source at image build time, on top of
whatever `GETBASED_REF` points to. Not sent upstream — these exist because
this image needs to work now, independent of upstream's own release cycle.

Applied best-effort (see `Dockerfile`): if upstream's `main` has since changed
the lines a patch targets, the patch is skipped with a build-log warning
instead of failing the build.

## 0001-openrouter-none-reasoning-effort.patch

`callOpenRouterAPI` (`js/api-openrouter.js`) only clears the caller-side
`reasoningEffort: 'none'` sentinel when the selected model happens to be
flagged mandatory-reasoning. For every other model, `'none'` survives as a
literal string and gets sent as `reasoning: { effort: 'none' }`. Combined
with `provider.require_parameters: true` (already set whenever `jsonMode` is
on), this excludes every OpenRouter endpoint that doesn't declare
`reasoning`/`reasoning_effort` support — most non-reasoning models — so
structured requests (PDF import, the Test AI Models benchmark) 404 with
"No endpoints found that can handle the requested parameters" regardless of
which model is selected.

Verified against OpenRouter's live `/api/v1/models/{id}/endpoints` for both
`anthropic/claude-sonnet-5` and `openai/gpt-4o-mini`: neither declares
support for a `'none'` reasoning effort tier.

A second, independent bug lives in the same function and the same patch:
models with always-on extended thinking (mandatory reasoning, e.g.
`anthropic/claude-sonnet-5`) don't expose a tunable `temperature` at all —
their OpenRouter endpoints never declare `temperature` in
`supported_parameters`. `pdf-import.js` sends a hardcoded `temperature: 0`
unconditionally (for deterministic extraction), which alone is enough to
zero out every endpoint once `require_parameters: true` is set, independent
of the reasoning-effort bug above. Verified live against the real API:
`jsonMode` + `temperature: 0` + no reasoning field still 404s for
`anthropic/claude-sonnet-5`; dropping `temperature` (or dropping
`require_parameters`) succeeds. The patch drops `temperature` specifically
for models flagged mandatory-reasoning, where it was never honored anyway.

## 0002-self-service-port.patch

`_getSelfBaseUrl` (`js/sync-relay-health.js`) only swapped to the relay's
self-service port (`SELF_PORT`, default 4003) when the relay's hostname was
literally `localhost` or `127.0.0.1`. Any self-hosted `getbased-relay`
reached by LAN IP or a real hostname — this stack's own relay included —
kept the WS-only relay port (`RELAY_PORT`, default 4000) for every
`/self/*` call (Reduce storage, Push now, owner-storage refresh). That port
has no plain-HTTP handler, so the request just hangs until timeout instead
of reaching the relay's actual self-service server.

The patch swaps on "the wss:// URL has an explicit port" instead of a
hostname allowlist — every self-hosted relay following the documented
`RELAY_PORT`/`SELF_PORT` convention carries an explicit port; the public
default relay (and any deployment path-routing `/self/*` behind the same
reverse proxy on 443) does not, and is left untouched. Merged into
`gczobel/get-based` as
[#1](https://github.com/gczobel/get-based/pull/1) and
[#2](https://github.com/gczobel/get-based/pull/2); not yet in
`elkimek/get-based` upstream.

## 0003-manual-body-readings-sync.patch

Manual weight, blood pressure and pulse readings (with tags and notes) live in
a per-browser store that never synced, so a second device joined to the same
Sync identity started with an empty history. This adds a synced
`manualBodyReadings` map, one row per `<field>.<date>` (the same key shape as
the existing deletion markers). Logging and deleting update it explicitly;
after a pull, or when a profile is opened, the entries are written back into
the local store; a one-time add-only backfill pushes pre-existing history. The
inbound half lives in a new lazily loaded module, `wearables-manual-sync.js`.

Merged into `gczobel/get-based` as
[#4](https://github.com/gczobel/get-based/pull/4) (closes its issue #3);
design record in ADR 0001 on that fork's
`docs/context-manual-body-readings` branch. Not in upstream. The fork's tests,
budgets, `MODULE_MAP.md` and `ARCHITECTURE.md` changes are deliberately not
part of this patch; only runtime files are.

## Why no patch touches `version.js`

Upstream bumps `version.js` on every release, so a patch on it stops applying
and is skipped along with everything else in that patch. The service worker's
cache is keyed by that version though, so browsers would keep serving stale
code after a patched image update. The Dockerfile therefore appends
`+gb<hash of the applied patches>` to `APP_VERSION` at build time (for example
`1.22.0+gbac2fa2cd`), which changes whenever upstream releases or a patch
changes.
