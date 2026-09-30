FROM node:24-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Builds from our fork, which is upstream plus a few fixes not yet accepted
# upstream (see FORK_CHANGES.md). The fork merges elkimek/get-based main
# weekly through its own sync workflow. Pin GETBASED_REF to a tag or commit
# for a stable deployment, or leave it on "main" to track the fork.
ARG GETBASED_REPO=https://github.com/gczobel/get-based.git
ARG GETBASED_REF=main
RUN git clone --branch "$GETBASED_REF" --depth 1 "$GETBASED_REPO" /app
WORKDIR /app

# The service worker cache is keyed by APP_VERSION, and the fork can change
# without an upstream version bump. Tag the version with the fork commit so
# browsers drop stale caches after an image update (for example 1.22.0+gb1a2b3c4).
RUN sha=$(git rev-parse --short=8 HEAD) && \
    sed -i "s/\(self\.APP_VERSION = '[^']*\)'/\1+gb${sha}'/" version.js && \
    grep APP_VERSION version.js

# dev-server.js is only free of a build step, not of node_modules. It
# transitively imports npm packages (e.g. undici, via lib/proxy-network.js)
# that upstream's own "no build step needed" self-hosting note glosses over.
RUN npm ci

# dev-server.js binds 127.0.0.1 (loopback) by default so it stays off the
# LAN unless explicitly opted in. Inside a container that means nothing
# outside the container could reach it, so this image opts in by default.
ENV HOST=0.0.0.0

EXPOSE 8000
CMD ["node", "dev-server.js", "8000"]
