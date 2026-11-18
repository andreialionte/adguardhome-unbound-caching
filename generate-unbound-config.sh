#!/bin/sh
set -e

CONFIG_DIR="/config/unbound"
CONFIG_FILE="$CONFIG_DIR/unbound.conf"
CONFIG_D_DIR="$CONFIG_DIR/unbound.conf.d"

mkdir -p "$CONFIG_D_DIR"

echo "Generating Unbound configuration..."

# Function to append to config if var is set
add_config() {
  local var_name="$1"
  local config_key="$2"
  local default_value="$3"
  local value="${!var_name:-$default_value}"
  if [ -n "$value" ] && [ "$value" != " " ]; then
    echo "  $config_key: $value" >> "$CONFIG_FILE"
  fi
}

add_config_bool() {
  local var_name="$1"
  local config_key="$2"
  local default_value="$3"
  local value="${!var_name:-$default_value}"
  if [ "$value" = "yes" ] || [ "$value" = "true" ] || [ "$value" = "1" ]; then
    echo "  $config_key: yes" >> "$CONFIG_FILE"
  elif [ "$value" = "no" ] || [ "$value" = "false" ] || [ "$value" = "0" ]; then
    echo "  $config_key: no" >> "$CONFIG_FILE"
  fi
}

add_config_list() {
  local var_name="$1"
  local config_key="$2"
  local value="${!var_name:-}"
  if [ -n "$value" ]; then
    IFS=',' read -ra ADDR <<< "$value"
    for i in "${ADDR[@]}"; do
      echo "  $config_key: $i" >> "$CONFIG_FILE"
    done
  fi
}

# Start fresh config
cat > "$CONFIG_FILE" << 'EOF'
server:
EOF

# ========================================================================
# NETWORK SETTINGS
# ========================================================================
add_config_list "UNBOUND_INTERFACE" "interface"
add_config_list "UNBOUND_PORT" "port"
add_config "UNBOUND_IP_TRANSPARENT" "ip-transparent"
add_config "UNBOUND_IP_FREEBIND" "ip-freebind"
add_config_bool "UNBOUND_IP_DSCP" "ip-dscp"
add_config "UNBOUND_SO_RCVBUF" "so-rcvbuf"
add_config "UNBOUND_SO_SNDBUF" "so-sndbuf"
add_config "UNBOUND_SO_REUSEPORT" "so-reuseport"

# ========================================================================
# TLS/SSL SETTINGS
# ========================================================================
add_config "UNBOUND_TLS_CERT_BUNDLE" "tls-cert-bundle"
add_config "UNBOUND_TLS_CIPHERS" "tls-ciphers"
add_config "UNBOUND_TLS_CIPHERSUITES" "tls-ciphersuites"
add_config "UNBOUND_TLS_SESSION_TICKET_KEYS" "tls-session-ticket-keys"
add_config "UNBOUND_TLS_UPSTREAM" "tls-upstream"
add_config_bool "UNBOUND_TLS_ADDITIONAL_PORT" "tls-additional-port"

# ========================================================================
# THREADING & PERFORMANCE
# ========================================================================
add_config "UNBOUND_NUM_THREADS" "num-threads"
add_config "UNBOUND_THREADS_AFFINITY" "threads-affinity"
add_config "UNBOUND_OUTGOING_RANGE" "outgoing-range"
add_config "UNBOUND_NUM_QUERIES_PER_THREAD" "num-queries-per-thread"
add_config "UNBOUND_JOSTLE_TIMEOUT" "jostle-timeout"

# ========================================================================
# CACHE SETTINGS
# ========================================================================
add_config "UNBOUND_RRSET_CACHE_SIZE" "rrset-cache-size"
add_config "UNBOUND_MSG_CACHE_SIZE" "msg-cache-size"
add_config "UNBOUND_NEG_CACHE_SIZE" "neg-cache-size"
add_config "UNBOUND_CACHE_MIN_TTL" "cache-min-ttl"
add_config "UNBOUND_CACHE_MAX_TTL" "cache-max-ttl"
add_config "UNBOUND_CACHE_MAX_NEGATIVE_TTL" "cache-max-negative-ttl"
add_config_bool "UNBOUND_SERVE_EXPIRED" "serve-expired"
add_config "UNBOUND_SERVE_EXPIRED_TTL" "serve-expired-ttl"
add_config_bool "UNBOUND_SERVE_EXPIRED_CLIENT_TIMEOUT" "serve-expired-client-timeout"
add_config_bool "UNBOUND_SERVE_EXPIRED_REPLY_TTL" "serve-expired-reply-ttl"
add_config_bool "UNBOUND_PREFETCH" "prefetch"
add_config_bool "UNBOUND_PREFETCH_KEY" "prefetch-key"

# ========================================================================
# SLAB SETTINGS
# ========================================================================
add_config "UNBOUND_INFRA_CACHE_SLABS" "infra-cache-slabs"
add_config "UNBOUND_KEY_CACHE_SLABS" "key-cache-slabs"
add_config "UNBOUND_MSG_CACHE_SLABS" "msg-cache-slabs"
add_config "UNBOUND_RRSET_CACHE_SLABS" "rrset-cache-slabs"

# ========================================================================
# TIMEOUTS
# ========================================================================
add_config "UNBOUND_TIMEOUT" "timeout"
add_config "UNBOUND_EDNS_TIMEOUT" "edns-timeout"
add_config "UNBOUND_MIN_RESPONSE_TTL" "min-response-ttl"
add_config "UNBOUND_MAX_RESPONSE_TTL" "max-response-ttl"

# ========================================================================
# DNSSEC SETTINGS
# ========================================================================
add_config "UNBOUND_TRUST_ANCHOR_FILE" "trust-anchor-file"
add_config "UNBOUND_AUTO_TRUST_ANCHOR_FILE" "auto-trust-anchor-file"
add_config "UNBOUND_TRUST_ANCHOR" "trust-anchor"
add_config_bool "UNBOUND_DNSSEC" "dnssec"
add_config_bool "UNBOUND_HARDEN_DNSSEC_STRIPPED" "harden-dnssec-stripped"
add_config_bool "UNBOUND_HARDEN_BELOW_NXDOMAIN" "harden-below-nxdomain"
add_config_bool "UNBOUND_HARDEN_REFERRAL_PATH" "harden-referral-path"
add_config_bool "UNBOUND_HARDEN_ALGO_DOWNGRADE" "harden-algo-downgrade"
add_config_bool "UNBOUND_HARDEN_SHORT_BUFSIZE" "harden-short-bufsize"
add_config_bool "UNBOUND_HARDEN_LARGE_QUERIES" "harden-large-queries"
add_config_bool "UNBOUND_HARDEN_GLUE" "harden-glue"
add_config_bool "UNBOUND_VAL_CLEAN_ADDITIONAL" "val-clean-additional"
add_config_bool "UNBOUND_VAL_PERMISSIVE_MODE" "val-permissive-mode"
add_config "UNBOUND_VAL_BOGUS_TTL" "val-bogus-ttl"
add_config "UNBOUND_VAL_SIG_SKEW_MIN" "val-sig-skew-min"
add_config "UNBOUND_VAL_SIG_SKEW_MAX" "val-sig-skew-max"
add_config "UNBOUND_VAL_LOG_LEVEL" "val-log-level"

# ========================================================================
# AGGRESSIVE NSEC
# ========================================================================
add_config_bool "UNBOUND_AGGRESSIVE_NSEC" "aggressive-nsec"

# ========================================================================
# PRIVACY SETTINGS (DoH, DoQ, DoT)
# ========================================================================
add_config_bool "UNBOUND_TLS_UPSTREAM" "tls-upstream"
add_config "UNBOUND_TLS_CERT_BUNDLE" "tls-cert-bundle"
add_config "UNBOUND_TLS_CIPHERS" "tls-ciphers"
add_config "UNBOUND_TLS_CIPHERSUITES" "tls-ciphersuites"

# DoH settings
add_config "UNBOUND_DOH_UPSTREAM" "doh-upstream"
add_config "UNBOUND_DOH_PORT" "doh-port"
add_config "UNBOUND_DOH_ENDPOINT" "doh-endpoint"

# DoQ settings
add_config "UNBOUND_DOQ_UPSTREAM" "doq-upstream"
add_config "UNBOUND_DOQ_PORT" "doq-port"

# ========================================================================
# FORWARD ZONE (Upstream DNS)
# ========================================================================
# This is handled by forward-queries.conf file

# ========================================================================
# LOGGING
# ========================================================================
add_config "UNBOUND_VERBOSITY" "verbosity"
add_config "UNBOUND_LOG_QUERIES" "log-queries"
add_config "UNBOUND_LOG_REPLIES" "log-replies"
add_config "UNBOUND_LOG_LOCAL_ACTIONS" "log-local-actions"
add_config "UNBOUND_LOG_FILE" "logfile"
add_config "UNBOUND_LOG_TIME_ASCII" "log-time-ascii"
add_config "UNBOUND_LOG_TAG_QUERYREPLY" "log-tag-queryreply"
add_config "UNBOUND_USE_SYSLOG" "use-syslog"
add_config "UNBOUND_LOG_IDENTITY" "log-identity"

# ========================================================================
# ACCESS CONTROL
# ========================================================================
add_config_list "UNBOUND_ACCESS_CONTROL" "access-control"
add_config_list "UNBOUND_INTERFACE_AUTOMATIC" "interface-automatic"
add_config_bool "UNBOUND_CHROOT" "chroot"

# ========================================================================
# MODULE CONFIGURATION
# ========================================================================
add_config "UNBOUND_MODULE_CONFIG" "module-config"

# ========================================================================
# CACHEDB (Garnet/Redis)
# ========================================================================
# Handled by cache.conf

# ========================================================================
# REMOTE CONTROL
# ========================================================================
add_config_bool "UNBOUND_REMOTE_CONTROL" "remote-control"
add_config "UNBOUND_CONTROL_PORT" "control-port"
add_config "UNBOUND_CONTROL_INTERFACE" "control-interface"
add_config "UNBOUND_SERVER_KEY_FILE" "server-key-file"
add_config "UNBOUND_SERVER_CERT_FILE" "server-cert-file"
add_config "UNBOUND_CONTROL_KEY_FILE" "control-key-file"
add_config "UNBOUND_CONTROL_CERT_FILE" "control-cert-file"

# ========================================================================
# PYTHON MODULE
# ========================================================================
add_config "UNBOUND_PYTHON_SCRIPT" "python-script"

# ========================================================================
# RESPONSE POLICY (RPZ)
# ========================================================================
add_config_list "UNBOUND_RPZ" "rpz"

# ========================================================================
# INCLUDE DIRECTORIES
# ========================================================================
echo "  include: $CONFIG_D_DIR/*.conf" >> "$CONFIG_FILE"

echo "Unbound configuration generated at $CONFIG_FILE"