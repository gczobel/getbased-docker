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

# dev-server.js binds 127.0.0.1 (loopback) by default so it stays off the
# LAN unless explicitly opted in — inside a container that means nothing
# outside the container could reach it, so this image opts in by default.
ENV HOST=0.0.0.0

EXPOSE 8000
CMD ["node", "dev-server.js", "8000"]
