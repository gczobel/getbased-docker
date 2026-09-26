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
