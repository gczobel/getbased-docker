# getbased-docker

A ready-to-run Docker image for [`elkimek/get-based`](https://github.com/elkimek/get-based) — the open-source [getbased](https://getbased.health) health dashboard (labs, DNA/SNPs, wearables, light exposure, Biology Scores, optional AI).

This repo doesn't fork or modify the upstream project. It just packages it as a container image and keeps that image rebuilt on a schedule, so the underlying Node/OS base image and upstream's code both stay current without manual bumping.

## Why a separate repo, and why this shape

get-based is a static, local-first PWA with no real backend of its own — the maintainer has said as much directly ([issue #899](https://github.com/elkimek/get-based/issues/899)): *"getbased has no back-end so it's not made for server usage in the classical sense... you could self-host just fine and serve it over Tailscale."* There's no upstream Dockerfile or published image for the app itself (the two Dockerfiles in that repo are for its separate, optional wearable-OAuth-relay and profile-share services, not the dashboard).

Upstream's own [self-hosting guide](https://docs.getbased.health/guides/self-hosting) documents a no-build path: clone the repo and run `node dev-server.js` — it loads native ES modules directly, no `npm install` needed unless you want the desktop AI-agent Companion feature. This image does exactly that.

**All your health data stays in the browser** (localStorage/IndexedDB), not in this container — there's no data volume to mount. This container only serves the app's static files over HTTP.

## Image

Published to `ghcr.io/gczobel/getbased-docker:latest` on every push to `main`, on a weekly schedule (Mondays), and via manual dispatch. Each rebuild re-clones `elkimek/get-based`'s `main` branch fresh on top of a freshly-pulled `node:24-slim`, so both upstream code changes and base-image security patches land automatically.

Given how actively upstream moves (issue churn is high for a young project — see the [due-diligence notes](#a-note-on-upstream) below), you may prefer pinning to a tagged release instead of tracking `main`. Do that at build time:

```bash
docker build --build-arg GETBASED_REF=v1.21.0-biology-scores -t getbased-docker .
```

## Configuration

| Variable | Required | Default (baked in) | Description |
|---|---|---|---|
| `HOST` | No | `0.0.0.0` | Bind address. dev-server.js defaults to `127.0.0.1` (loopback-only) upstream; baked in here so the container is reachable without extra config. |
| `PORT` | No | `8000` | Set via the CLI arg in `CMD`, not an env var — override with `docker run ... node dev-server.js <port>` if you need a different port. |

Wearable OAuth (WHOOP, Google Health, Oura, etc.), cross-device sync, and other network features need their own setup per [upstream's self-hosting guide](https://docs.getbased.health/guides/self-hosting) — bundled OAuth credentials only work on `*.getbased.health`. None of that is wired into this image; it just serves the app.

## Example (Portainer / docker-compose)

```yaml
services:
  getbased:
    image: ghcr.io/gczobel/getbased-docker:latest
    restart: unless-stopped
    ports:
      - "8000:8000"
```

Put a reverse proxy with TLS in front of it (or a Tailscale/VPN overlay) rather than exposing it directly — this app handles blood work and raw DNA, and dev-server.js is a dev-grade HTTP server, not a hardened production one.

## Auto-merge and security posture

- **Dependabot** watches the `docker` (base image) and `github-actions` ecosystems weekly. Node major/minor bumps are excluded from auto-updates (get-based's `package.json` pins `engines.node` to `24.x`; a floated major version isn't safe to take blindly).
- **`dependabot-auto-merge.yml`** enables auto-merge on Dependabot PRs that aren't major-version bumps, as soon as they're opened.
- **`dependabot-backlog-sweep.yml`** runs daily (and after every push to `main`) to catch any Dependabot PR the event-triggered workflow missed — a `pull_request`-triggered workflow doesn't retroactively attach to PRs that were already open when it was added.
- A branch protection **ruleset** on `main` requires the `build` check (the image actually builds) to pass before anything merges, including auto-merged Dependabot PRs — so a base-image bump that breaks the build gets held for review instead of merging blind.
- **Secret scanning + push protection** and **Dependabot security updates** are enabled at the repo level.

## A note on upstream

Before building this, I did a due-diligence pass on `elkimek/get-based`: AGPL-3.0, actively maintained, thoughtful encryption design (device-bound AES-256-GCM, E2E-encrypted sync, a vendored verify-only `elliptic` fork to sidestep known signing CVEs), but effectively a solo-maintainer project only ~7 months old with fast-moving, AI-agent-assisted development and real issue churn (unit-conversion bugs, an encryption regression, etc. among recently closed issues). No third-party security audit exists yet. Worth knowing before pointing it at data you care about — pin to a tagged release (see above) if you want stability over freshness.
