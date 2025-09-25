# syntax=docker/dockerfile:1
ARG BUILD_FROM
FROM $BUILD_FROM

# copy local root filesystem overlay (optional)
COPY rootfs /

ARG BUILD_ARCH
ARG BEDROCK_URL

# install tools, detect arch token, download/extract bedrock server if BEDROCK_URL provided
RUN set -eux; \
    \
    # install minimal tools (alpine-based images use apk)
    if command -v apk > /dev/null 2>&1; then \
      apk add --no-cache curl unzip bash coreutils; \
    elif command -v apt-get > /dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends curl unzip bash coreutils && rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Unsupported base image package manager" >&2; \
    fi; \
    \
    # map build arch to a short token (you can adjust mapping if your binary naming differs)
    ARCH="amd64"; \
    if [ "${BUILD_ARCH}" = "aarch64" ]; then ARCH="arm64"; fi; \
    if [ "${BUILD_ARCH}" = "armv7" ] || [ "${BUILD_ARCH}" = "armhf" ]; then ARCH="arm"; fi; \
    if [ "${BUILD_ARCH}" = "i386" ]; then ARCH="386"; fi; \
    echo "BUILD_ARCH=${BUILD_ARCH} -> ARCH=${ARCH}"; \
    \
    # prepare location
    mkdir -p /opt/bedrock; \
    \
    # if a BEDROCK_URL was supplied, download and unzip it into /opt/bedrock
    if [ -n "${BEDROCK_URL:-}" ]; then \
      echo "Downloading Bedrock server from ${BEDROCK_URL}"; \
      curl -fsSL "${BEDROCK_URL}" -o /tmp/bedrock.zip; \
      unzip -q /tmp/bedrock.zip -d /opt/bedrock; \
      rm -f /tmp/bedrock.zip; \
    else \
      echo "No BEDROCK_URL provided; expecting bedrock server files to be provided via rootfs or a mounted volume."; \
    fi; \
    \
    # make executable and set permissions (if bedrock_server exists)
    if [ -f /opt/bedrock/bedrock_server ]; then chmod +x /opt/bedrock/bedrock_server; fi; \
    addgroup -S mcbedrock || true; adduser -S -G mcbedrock mcbedrock || true; \
    chown -R mcbedrock:mcbedrock /opt/bedrock || true

# runtime config
WORKDIR /opt/bedrock
USER mcbedrock

# expose Bedrock UDP port
EXPOSE 19132/udp

# default start: run bedrock_server (if present) otherwise sleep so container doesn't crash on start
CMD ["/bin/sh", "-c", "if [ -x ./bedrock_server ]; then ./bedrock_server; else echo 'No bedrock_server found in /opt/bedrock'; sleep infinity; fi"]
