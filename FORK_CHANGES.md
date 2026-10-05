# Changes in the fork

The image builds from [gczobel/get-based](https://github.com/gczobel/get-based),
which is `elkimek/get-based` plus the changes below. A weekly workflow in the
fork merges upstream `main` and opens a PR, so the fork stays current without
patch files that can silently stop applying.

None of these are accepted upstream yet, except where noted. If upstream takes
one, it disappears from the fork's diff on the next sync and needs no change here.

## OpenRouter reasoning effort and temperature

`callOpenRouterAPI` (`js/api-openrouter.ts`) only cleared the caller-side
`reasoningEffort: 'none'` sentinel for mandatory-reasoning models. For every
other model it was sent as `reasoning: { effort: 'none' }`. Together with
`provider.require_parameters: true` (set whenever `jsonMode` is on), that
excluded every OpenRouter endpoint without `reasoning` support, so PDF import
and the Test AI Models benchmark returned 404 "No endpoints found".

A second bug in the same function: mandatory-reasoning models don't expose
`temperature`, and `pdf-import.ts` always sends `temperature: 0`. The fork drops
`temperature` for those models. Upstream PR:
[elkimek/get-based#1654](https://github.com/elkimek/get-based/pull/1654).

## Self-service relay port

`_getSelfBaseUrl` (`js/sync-relay-health.ts`) only switched to the self-service
port (default 4003) when the relay host was `localhost` or `127.0.0.1`. A
self-hosted relay reached by LAN IP kept the WS-only port 4000 for `/self/*`
calls, which hangs. The fork switches whenever the `wss://` URL has an explicit
port. Fork PRs #1 and #2.

## Manual body readings sync

Manual weight, blood pressure and pulse readings lived in a per-browser store,
so a second device on the same Sync identity started empty. The fork adds a
synced `manualBodyReadings` map, one row per `<field>.<date>`, with a lazy
module `js/wearables-manual-sync.ts` for the inbound side and a one-time
add-only backfill. Fork PR #4, ADR 0001 on the fork's
`docs/context-manual-body-readings` branch.

## Budgets

The fork raises the cold-load, production-build and app-shell size ceilings by
the measured overshoot of these changes, with reference entries in each budget
file.
