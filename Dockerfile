# syntax=docker/dockerfile:1.7

#############################################
# Stage 1: Builder (Compiles Unbound)
#############################################
FROM alpine:3.23 AS unbound_builder

ARG UNBOUND_URL="https://nlnetlabs.nl/downloads/unbound/unbound-latest.tar.gz"
ARG TARGETARCH

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    curl \
    openssl-dev \
    expat-dev \
    hiredis-dev \
    libevent-dev \
    libcap-dev \
    perl \
    linux-headers \
    wget

# Compile Unbound from source with hiredis (cachedb) support
RUN set -eux; \
    wget "${UNBOUND_URL}" -O unbound.tar.gz; \
    mkdir src; \
    tar -xzf unbound.tar.gz --strip-components=1 -C src; \
    cd src; \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --with-libhiredis \
        --with-libexpat=/usr \
        --with-libevent \
        --enable-cachedb \
        --disable-flto \
        --disable-shared \
        --with-pthreads; \
    make -j$(nproc); \
    make install DESTDIR=/build/install

#############################################
# Stage 2: Download AdGuard Home
#############################################
FROM alpine:3.23 AS agh_downloader

ARG AGH_VERSION=${AGH_VERSION:-v0.107.73}
ARG TARGETARCH

WORKDIR /build

# Ensure /build is writable and has proper permissions
RUN mkdir -p /build && chmod 777 /build

RUN apk add --no-cache wget

RUN set -eux; \
    VERSION="${AGH_VERSION}"; \
    ARCH="${TARGETARCH}"; \
    echo "Downloading AdGuard Home version: ${VERSION} for ${ARCH}"; \
    URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${VERSION}/AdGuardHome_linux_${ARCH}.tar.gz"; \
    echo "URL: ${URL}"; \
    wget --timeout=30 -O /build/AdGuardHome.tar.gz "${URL}" || { echo "Download failed"; exit 1; }; \
    mkdir -p /build/agh && \
    tar -xzf /build/AdGuardHome.tar.gz -C /build/agh && \
    ls -la /build/agh

#############################################
# Stage 3: Runtime (Pre-built Garnet + Unbound + AdGuard)
#############################################
FROM ghcr.io/microsoft/garnet-alpine:latest

ARG TARGETARCH

# Update APK cache and install runtime dependencies
RUN apk update && apk add --no-cache \
    ca-certificates \
    libevent \
    hiredis \
    expat \
    libcap \
    openssl

# Create Unbound user and necessary directories
RUN addgroup -S unbound && adduser -S unbound -G unbound \
    && mkdir -p /etc/unbound/var /config /config/garnet /config/unbound /config/AdGuardHome /opt/adguardhome/work \
    && chown -R unbound:unbound /etc/unbound

# Copy compiled Unbound from builder
COPY --from=unbound_builder /build/install/usr/sbin/unbound /usr/sbin/unbound
COPY --from=unbound_builder /build/install/usr/sbin/unbound-anchor /usr/sbin/unbound-anchor
COPY --from=unbound_builder /build/install/usr/sbin/unbound-checkconf /usr/sbin/unbound-checkconf
COPY --from=unbound_builder /build/install/usr/sbin/unbound-control /usr/sbin/unbound-control
COPY --from=unbound_builder /build/install/usr/lib/libunbound.so* /usr/lib/

# Copy AdGuard Home binary
COPY --from=agh_downloader /build/agh/AdGuardHome/AdGuardHome /opt/AdGuardHome/AdGuardHome

# Copy configuration files and entrypoint
COPY config/ /config_default
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose required ports
EXPOSE 53/tcp 53/udp 67/udp 68/udp 80/tcp 443/tcp 443/udp \
       853/tcp 853/udp 3000/tcp 3000/udp 5443/tcp 5443/udp \
       6060/tcp 5053 784/udp 3002/tcp

# Set configuration environment variable
ENV XDG_CONFIG_HOME=/config

# Use tini as init process for proper signal handling
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
