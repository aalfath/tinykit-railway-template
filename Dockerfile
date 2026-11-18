# Tinykit for Railway: builds the upstream source at a pinned commit.
# Upstream publishes no container image, so this follows its own
# deploy/docker/Dockerfile, with the base image, the source commit and the
# PocketBase binary all pinned and checked.

ARG NODE_IMAGE=node:22.23.5-alpine3.24@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a

FROM ${NODE_IMAGE} AS build
# Tinykit 0.1.1 ("v0.1.1 maintenance", merged 2026-11-08)
ARG TINYKIT_VERSION=0.1.1
ARG TINYKIT_COMMIT=b4aea2b575dbb149f2c4b9b01f8f0603d7c23da1
# PocketBase version pinned by Tinykit's scripts/download-pocketbase.js
ARG PB_VERSION=0.23.4
ARG PB_SHA256_AMD64=274173785fcaefcecc69a82057d7fa9c813d23dda6c7781374f952019232a366
ARG PB_SHA256_ARM64=0d3e45374f8abab2a0de83688ac9258995b07bced0de140e4aca8c6d0d88bd50
ARG TARGETARCH=amd64
RUN apk add --no-cache git unzip
WORKDIR /app
RUN git init -q . \
 && git fetch -q --depth 1 https://github.com/tinykit-studio/tinykit.git "${TINYKIT_COMMIT}" \
 && git checkout -q FETCH_HEAD \
 && test "$(git rev-parse HEAD)" = "${TINYKIT_COMMIT}" \
 && grep -q "\"version\": \"${TINYKIT_VERSION}\"" package.json \
 && rm -r .git
RUN case "${TARGETARCH}" in \
      amd64) sum="${PB_SHA256_AMD64}" ;; \
      arm64) sum="${PB_SHA256_ARM64}" ;; \
      *) echo "unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac \
 && wget -qO /tmp/pb.zip "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${TARGETARCH}.zip" \
 && echo "${sum}  /tmp/pb.zip" | sha256sum -c - \
 && unzip -q -o /tmp/pb.zip pocketbase -d pocketbase \
 && chmod 755 pocketbase/pocketbase \
 && rm /tmp/pb.zip
RUN npm ci --include=dev --no-audit --no-fund \
 && npm run build \
 && npm prune --omit=dev --no-audit --no-fund

FROM ${NODE_IMAGE}
RUN apk add --no-cache curl tini
WORKDIR /app
COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/build ./build
COPY --from=build /app/pocketbase/pocketbase ./pocketbase/pocketbase
COPY --from=build /app/pocketbase/pb_migrations ./pocketbase/pb_migrations
COPY start.sh /usr/local/bin/tinykit-start
RUN chmod 755 /usr/local/bin/tinykit-start && mkdir -p /app/pocketbase/pb_data
ENV NODE_ENV=production \
    PORT=3000 \
    BODY_SIZE_LIMIT=10M
VOLUME ["/app/pocketbase/pb_data"]
EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/tinykit-start"]
