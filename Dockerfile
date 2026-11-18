# syntax=docker/dockerfile:1.7

#############################################
# Stage 1: Builder (Compiles Unbound on Ubuntu for glibc compatibility)
#############################################
FROM ubuntu:24.04 AS unbound_builder

ARG UNBOUND_URL="https://nlnetlabs.nl/downloads/unbound/unbound-latest.tar.gz"
ARG TARGETARCH

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    libssl-dev \
    libexpat1-dev \
    libhiredis-dev \
    libevent-dev \
    libcap-dev \
    perl \
    linux-headers-generic \
    wget \
    && rm -rf /var/lib/apt/lists/*

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
FROM ubuntu:24.04 AS agh_downloader

ARG AGH_VERSION=v0.107.73
ARG TARGETARCH

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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
# Stage 3: Runtime (Garnet Noble base + Unbound + AdGuard)
#############################################
FROM ghcr.io/microsoft/garnet-noble:latest AS runtime_base

ARG TARGETARCH

# Explicitly run as root for package management
USER root

# Install runtime dependencies (Ubuntu 24.04 noble)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libevent-2.1-7t64 \
    libhiredis1.1.0 \
    libexpat1 \
    libcap2 \
    openssl \
    tini \
    netcat-openbsd \
    libstdc++6 \
    libgcc-s1 \
    passwd \
    && rm -rf /var/lib/apt/lists/*

# Create tini symlink if needed
RUN ln -sf /usr/bin/tini /sbin/tini

# Create Unbound user and necessary directories
RUN groupadd --system unbound && useradd --system --gid unbound --no-create-home --shell /usr/sbin/nologin unbound \
    && mkdir -p /etc/unbound/var /config /config/garnet /config/garnet/data /config/garnet/checkpoints /config/unbound /config/unbound/unbound.conf.d /config/AdGuardHome /opt/adguardhome/work \
    && chown -R unbound:unbound /etc/unbound

# Copy Garnet from Garnet Noble image (includes all dependencies in /app)
RUN cp -r /app /usr/local/garnet && chmod +x /usr/local/garnet/GarnetServer

# Create garnet symlink for compatibility
RUN ln -sf /usr/local/garnet/GarnetServer /usr/local/bin/garnet

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
