FROM node:24-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Pin to a tag (e.g. v1.21.0-biology-scores) at build time for a stable
# deployment, or leave as "main" to always track upstream's latest commit.
ARG GETBASED_REF=main
RUN git clone --branch "$GETBASED_REF" --depth 1 \
    https://github.com/elkimek/get-based.git /app
WORKDIR /app

# Local-only patches, not sent upstream. Applied best-effort: if upstream's
# main has since diverged from the lines a patch targets, `git apply --check`
# fails and the patch is skipped with a warning rather than breaking the
# build — see patches/README.md for what each one fixes and why.
COPY patches/ /tmp/patches/
RUN for p in /tmp/patches/*.patch; do \
      [ -e "$p" ] || continue; \
      if git apply --check "$p" 2>/dev/null; then \
        git apply "$p" && echo "applied $(basename "$p")"; \
      else \
        echo "WARNING: skipping $(basename "$p") — no longer applies cleanly against $GETBASED_REF"; \
      fi; \
    done

# dev-server.js is only free of a build step, not of node_modules — it
# transitively imports npm packages (e.g. undici, via lib/proxy-network.js)
# that upstream's own "no build step needed" self-hosting note glosses over.
RUN npm ci

# dev-server.js binds 127.0.0.1 (loopback) by default so it stays off the
# LAN unless explicitly opted in — inside a container that means nothing
# outside the container could reach it, so this image opts in by default.
ENV HOST=0.0.0.0

EXPOSE 8000
CMD ["node", "dev-server.js", "8000"]
