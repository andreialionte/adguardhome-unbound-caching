#!/bin/sh
set -e

echo "Starting initialization script..."

# --- 1. Create necessary directories ---
mkdir -p /config/garnet /config/garnet/data /config/garnet/checkpoints /config/unbound /config/unbound/unbound.conf.d /config/AdGuardHome /config/userfilters /opt/adguardhome/work
chmod 755 /opt/adguardhome/work

# --- 2. Copy/Merge default configurations ---
if [ -z "$(ls -A /config/garnet 2>/dev/null)" ]; then
  echo "Initializing default Garnet configuration files..."
  mkdir -p /config/garnet
  cp /config_default/garnet/redis.conf /config/garnet/redis.conf
fi

if [ -z "$(ls -A /config/AdGuardHome 2>/dev/null)" ]; then
  echo "Initializing default AdGuardHome configuration files..."
  if [ -d "/config_default/AdGuardHome" ]; then
    cp -r /config_default/AdGuardHome/* /config/AdGuardHome/
  else
    echo "No default AdGuardHome config found - AdGuard will generate on first run"
  fi
fi

if [ ! -f "/config/unbound/unbound.conf" ]; then
  echo "Initializing default Unbound configuration (new user)..."
  cp -r /config_default/unbound/* /config/unbound/
else
  echo "Existing Unbound configuration found. Checking for upgrades..."
  NEW_FILES_STRING="dnssec.conf aggressive-nsec.conf privacy.conf doh.conf doq.conf"
  IFS=' '
  for file_name in $NEW_FILES_STRING; do
    src_file="/config_default/unbound/unbound.conf.d/$file_name"
    dest_file="/config/unbound/unbound.conf.d/$file_name"
    if [ -f "$src_file" ] && [ ! -f "$dest_file" ]; then
      echo "Adding new default config file: $file_name..."
      cp "$src_file" "$dest_file"
    fi
  done
  unset IFS
fi

# --- 3. Set Permissions ---
echo "Setting permissions on /config directory..."
chown -R root:root /config

# --- 4. Initialize DNSSEC Root Anchor ---
ROOT_KEY_FILE="/etc/unbound/var/root.key"
if [ ! -f "$ROOT_KEY_FILE" ]; then
  echo "Initializing DNSSEC root trust anchor file at $ROOT_KEY_FILE..."
  TEMP_RESOLV="/tmp/temp_resolv.conf"
  echo "nameserver 1.1.1.1" > "$TEMP_RESOLV"
  echo "nameserver 1.0.0.1" >> "$TEMP_RESOLV"
  MAX_ANCHOR_RETRIES=5
  RETRY_COUNT=0
  until /usr/sbin/unbound-anchor -a "$ROOT_KEY_FILE" -f "$TEMP_RESOLV" || [ $RETRY_COUNT -eq $MAX_ANCHOR_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo "unbound-anchor failed (network not ready?), retrying ($RETRY_COUNT/$MAX_ANCHOR_RETRIES) in 2s..."
    sleep 2
  done
  rm "$TEMP_RESOLV"
  if [ ! -f "$ROOT_KEY_FILE" ]; then
      echo "FATAL: Could not initialize DNSSEC root anchor after $MAX_ANCHOR_RETRIES retries. Exiting."
      exit 1
  fi
  echo "DNSSEC root trust anchor initialized."
else
  echo "DNSSEC root trust anchor already exists."
fi

# --- 5. Generate Unbound Config from Environment Variables ---
echo "Generating Unbound configuration from environment variables..."
/usr/local/bin/generate-unbound-config.sh

# --- 6. Start Services ---
echo "Starting Garnet (Redis-compatible cache) with Unix socket..."
GARNET_CMD="garnet \
  --config-import-path /config/garnet/redis.conf \
  --config-import-format RedisConf \
  --unixsocket /tmp/garnet.sock \
  --unixsocketperm 777 \
  --bind ${GARNET_BIND:-127.0.0.1} \
  --port ${GARNET_PORT:-6379}"

[ -n "${GARNET_CLUSTER_ANNOUNCE_IP:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-announce-ip ${GARNET_CLUSTER_ANNOUNCE_IP}"
[ -n "${GARNET_CLUSTER_ANNOUNCE_PORT:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-announce-port ${GARNET_CLUSTER_ANNOUNCE_PORT}"
[ -n "${GARNET_CLUSTER_ANNOUNCE_HOSTNAME:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-announce-hostname ${GARNET_CLUSTER_ANNOUNCE_HOSTNAME}"
[ -n "${GARNET_CLUSTER_ADDRESS:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-address ${GARNET_CLUSTER_ADDRESS}"
[ -n "${GARNET_CLUSTER_PORT:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-port ${GARNET_CLUSTER_PORT}"
[ -n "${GARNET_CLUSTER_PREFERRED_ENDPOINT_TYPE:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-preferred-endpoint-type ${GARNET_CLUSTER_PREFERRED_ENDPOINT_TYPE}"
[ -n "${GARNET_LOG_MEMORY_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --memory ${GARNET_LOG_MEMORY_SIZE}"
[ -n "${GARNET_PAGE_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --page ${GARNET_PAGE_SIZE}"
[ -n "${GARNET_PAGE_COUNT:-}" ] && GARNET_CMD="${GARNET_CMD} --pagecount ${GARNET_PAGE_COUNT}"
[ -n "${GARNET_SEGMENT_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --segment ${GARNET_SEGMENT_SIZE}"
[ -n "${GARNET_OBJECT_LOG_SEGMENT_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --object-log-segment ${GARNET_OBJECT_LOG_SEGMENT_SIZE}"
[ -n "${GARNET_INDEX_MEMORY_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --index ${GARNET_INDEX_MEMORY_SIZE}"
[ -n "${GARNET_INDEX_MAX_MEMORY_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --index-max-size ${GARNET_INDEX_MAX_MEMORY_SIZE}"
[ -n "${GARNET_MUTABLE_PERCENT:-}" ] && GARNET_CMD="${GARNET_CMD} --mutable-percent ${GARNET_MUTABLE_PERCENT}"
[ "${GARNET_USE_NATIVE_ALLOCATOR:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --use-native-allocator"
[ "${GARNET_USE_LEGACY_BUFFER_POOL:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --use-legacy-buffer-pool"
[ -n "${GARNET_BUFFER_POOL_MEMORY_BUDGET:-}" ] && GARNET_CMD="${GARNET_CMD} --buffer-pool-memory-budget ${GARNET_BUFFER_POOL_MEMORY_BUDGET}"
[ "${GARNET_ENABLE_READ_CACHE:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --readcache"
[ -n "${GARNET_READ_CACHE_MEMORY_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --readcache-memory ${GARNET_READ_CACHE_MEMORY_SIZE}"
[ -n "${GARNET_READ_CACHE_PAGE_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --readcache-page ${GARNET_READ_CACHE_PAGE_SIZE}"
[ -n "${GARNET_READ_CACHE_PAGE_COUNT:-}" ] && GARNET_CMD="${GARNET_CMD} --readcache-pagecount ${GARNET_READ_CACHE_PAGE_COUNT}"

if [ "${GARNET_STORAGE_TIER:-false}" = "true" ]; then
  echo "Enabling Garnet storage tier (disk-backed)..."
  GARNET_CMD="${GARNET_CMD} \
    --storage-tier \
    --logdir ${GARNET_LOG_DIR:-${GARNET_CHECKPOINT_DIR:-/config/garnet/checkpoints}} \
    --checkpointdir ${GARNET_CHECKPOINT_DIR:-/config/garnet/checkpoints} \
    --segment ${GARNET_SEGMENT_SIZE:-1g} \
    --compaction-max-segments ${GARNET_COMPACTION_MAX_SEGMENTS:-15} \
    --compaction-freq ${GARNET_COMPACTION_FREQ:-60} \
    --compaction-type ${GARNET_COMPACTION_TYPE:-Lookup} \
    --compaction-force-delete ${GARNET_COMPACTION_FORCE_DELETE:-true}"
  [ "${GARNET_COPY_READS_TO_TAIL:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --copy-reads-to-tail"
  [ "${GARNET_RECOVER:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --recover"
fi

[ "${GARNET_DISABLE_OBJECTS:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --no-obj"
[ -n "${GARNET_PUB_SUB_PAGE_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --pubsub-pagesize ${GARNET_PUB_SUB_PAGE_SIZE}"
[ "${GARNET_DISABLE_PUB_SUB:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --no-pubsub"
[ "${GARNET_ENABLE_AOF:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --aof"
[ -n "${GARNET_AOF_MEMORY_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-memory ${GARNET_AOF_MEMORY_SIZE}"
[ -n "${GARNET_AOF_PAGE_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-page-size ${GARNET_AOF_PAGE_SIZE}"
[ -n "${GARNET_AOF_SEGMENT_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-segment-size ${GARNET_AOF_SEGMENT_SIZE}"
[ -n "${GARNET_AOF_PHYSICAL_SUBLOG_COUNT:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-physical-sublog-count ${GARNET_AOF_PHYSICAL_SUBLOG_COUNT}"
[ -n "${GARNET_AOF_REPLAY_TASK_COUNT:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-replay-task-count ${GARNET_AOF_REPLAY_TASK_COUNT}"
[ -n "${GARNET_AOF_COMMIT_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-commit-freq ${GARNET_AOF_COMMIT_FREQ}"
[ "${GARNET_AOF_COMMIT_WAIT:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --aof-commit-wait"
[ -n "${GARNET_AOF_SIZE_LIMIT:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-size-limit ${GARNET_AOF_SIZE_LIMIT}"
[ -n "${GARNET_AOF_SIZE_LIMIT_ENFORCE_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --aof-size-limit-enforce-frequency ${GARNET_AOF_SIZE_LIMIT_ENFORCE_FREQ}"
[ -n "${GARNET_COMPACTION_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --compaction-freq ${GARNET_COMPACTION_FREQ}"
[ -n "${GARNET_COMPACTION_TYPE:-}" ] && GARNET_CMD="${GARNET_CMD} --compaction-type ${GARNET_COMPACTION_TYPE}"
[ -n "${GARNET_COMPACTION_FORCE_DELETE:-}" ] && GARNET_CMD="${GARNET_CMD} --compaction-force-delete ${GARNET_COMPACTION_FORCE_DELETE}"
[ -n "${GARNET_COMPACTION_MAX_SEGMENTS:-}" ] && GARNET_CMD="${GARNET_CMD} --compaction-max-segments ${GARNET_COMPACTION_MAX_SEGMENTS}"
[ "${GARNET_ENABLE_COMPACTION:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --compaction-freq ${GARNET_COMPACTION_FREQ:-60}"
[ -n "${GARNET_CHECKPOINT_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --checkpoint-freq ${GARNET_CHECKPOINT_FREQ}"
[ -n "${GARNET_EXPIRED_OBJECT_COLLECTION_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --expired-object-collection-freq ${GARNET_EXPIRED_OBJECT_COLLECTION_FREQ}"
[ "${GARNET_ENABLE_LUA:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --lua"
[ "${GARNET_LUA_TRANSACTION_MODE:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --lua-transaction-mode"
[ -n "${GARNET_LUA_MEMORY_MANAGEMENT_MODE:-}" ] && GARNET_CMD="${GARNET_CMD} --lua-memory-management-mode ${GARNET_LUA_MEMORY_MANAGEMENT_MODE}"
[ -n "${GARNET_LUA_SCRIPT_MEMORY_LIMIT:-}" ] && GARNET_CMD="${GARNET_CMD} --lua-script-memory-limit ${GARNET_LUA_SCRIPT_MEMORY_LIMIT}"
[ -n "${GARNET_LUA_SCRIPT_TIMEOUT:-}" ] && GARNET_CMD="${GARNET_CMD} --lua-script-timeout ${GARNET_LUA_SCRIPT_TIMEOUT}"
[ -n "${GARNET_LUA_LOGGING_MODE:-}" ] && GARNET_CMD="${GARNET_CMD} --lua-logging-mode ${GARNET_LUA_LOGGING_MODE}"
[ "${GARNET_ENABLE_CLUSTER:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --cluster"
[ "${GARNET_CLEAN_CLUSTER_CONFIG:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --clean-cluster-config"
[ -n "${GARNET_PARALLEL_MIGRATE_TASK_COUNT:-}" ] && GARNET_CMD="${GARNET_CMD} --parallel-migrate-task-count ${GARNET_PARALLEL_MIGRATE_TASK_COUNT}"
[ "${GARNET_USE_SCAN_AHEAD_MIGRATION:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --use-scan-ahead-migration"
[ -n "${GARNET_MIGRATION_PIPELINE_DEPTH:-}" ] && GARNET_CMD="${GARNET_CMD} --migrate-pipeline-depth ${GARNET_MIGRATION_PIPELINE_DEPTH}"
[ -n "${GARNET_MIGRATION_DELETE_BATCH_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --migrate-delete-batch-size ${GARNET_MIGRATION_DELETE_BATCH_SIZE}"
[ -n "${GARNET_GOSSIP_SAMPLE_PERCENT:-}" ] && GARNET_CMD="${GARNET_CMD} --gossip-sp ${GARNET_GOSSIP_SAMPLE_PERCENT}"
[ -n "${GARNET_GOSSIP_DELAY:-}" ] && GARNET_CMD="${GARNET_CMD} --gossip-delay ${GARNET_GOSSIP_DELAY}"
[ -n "${GARNET_CLUSTER_TIMEOUT:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-timeout ${GARNET_CLUSTER_TIMEOUT}"
[ -n "${GARNET_FAILOVER_RESET_PRIMARY_TIMEOUT:-}" ] && GARNET_CMD="${GARNET_CMD} --failover-reset-primary-timeout ${GARNET_FAILOVER_RESET_PRIMARY_TIMEOUT}"
[ -n "${GARNET_CLUSTER_CONFIG_FLUSH_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --cluster-config-flush-frequency ${GARNET_CLUSTER_CONFIG_FLUSH_FREQ}"
[ -n "${GARNET_AUTH_MODE:-}" ] && GARNET_CMD="${GARNET_CMD} --auth ${GARNET_AUTH_MODE}"
[ -n "${GARNET_PASSWORD:-}" ] && GARNET_CMD="${GARNET_CMD} --password ${GARNET_PASSWORD}"
[ "${GARNET_PROTECTED_MODE:-true}" = "true" ] && GARNET_CMD="${GARNET_CMD} --protected-mode"
[ -n "${GARNET_ACL_FILE:-}" ] && GARNET_CMD="${GARNET_CMD} --aclfile ${GARNET_ACL_FILE}"
[ -n "${GARNET_MAX_DATABASES:-}" ] && GARNET_CMD="${GARNET_CMD} --max-databases ${GARNET_MAX_DATABASES}"
[ "${GARNET_TLS_ENABLED:-false}" = "true" ] && GARNET_CMD="${GARNET_CMD} --tls"
[ -n "${GARNET_TLS_CERT_FILE:-}" ] && GARNET_CMD="${GARNET_CMD} --cert-file-name ${GARNET_TLS_CERT_FILE}"
[ -n "${GARNET_TLS_CERT_PASSWORD:-}" ] && GARNET_CMD="${GARNET_CMD} --cert-password ${GARNET_TLS_CERT_PASSWORD}"
[ -n "${GARNET_TLS_CERT_SUBJECT_NAME:-}" ] && GARNET_CMD="${GARNET_CMD} --cert-subject-name ${GARNET_TLS_CERT_SUBJECT_NAME}"
[ -n "${GARNET_TLS_CERT_REFRESH_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --cert-refresh-freq ${GARNET_TLS_CERT_REFRESH_FREQ}"
[ "${GARNET_TLS_CLIENT_CERT_REQUIRED:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --client-certificate-required"
[ "${GARNET_TLS_SERVER_CERT_REQUIRED:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --server-certificate-required"
[ -n "${GARNET_TLS_CERT_REVOCATION_MODE:-}" ] && GARNET_CMD="${GARNET_CMD} --certificate-revocation-check-mode ${GARNET_TLS_CERT_REVOCATION_MODE}"
[ -n "${GARNET_TLS_HANDSHAKE_TIMEOUT:-}" ] && GARNET_CMD="${GARNET_CMD} --tls-handshake-timeout ${GARNET_TLS_HANDSHAKE_TIMEOUT}"
[ -n "${GARNET_TLS_ISSUER_CERT_PATH:-}" ] && GARNET_CMD="${GARNET_CMD} --issuer-certificate-path ${GARNET_TLS_ISSUER_CERT_PATH}"
[ -n "${GARNET_LOG_LEVEL:-}" ] && GARNET_CMD="${GARNET_CMD} --logger-level ${GARNET_LOG_LEVEL}"
[ "${GARNET_QUIET_MODE:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --quiet"
[ "${GARNET_DISABLE_CONSOLE_LOGGER:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --disable-console-logger"
[ -n "${GARNET_FILE_LOGGER:-}" ] && GARNET_CMD="${GARNET_CMD} --file-logger ${GARNET_FILE_LOGGER}"
[ -n "${GARNET_LOGGING_FREQUENCY:-}" ] && GARNET_CMD="${GARNET_CMD} --logger-freq ${GARNET_LOGGING_FREQUENCY}"
[ -n "${GARNET_LATENCY_MONITOR:-}" ] && GARNET_CMD="${GARNET_CMD} --latency-monitor ${GARNET_LATENCY_MONITOR}"
[ -n "${GARNET_SLOWLOG_THRESHOLD:-}" ] && GARNET_CMD="${GARNET_CMD} --slowlog-log-slower-than ${GARNET_SLOWLOG_THRESHOLD}"
[ -n "${GARNET_SLOWLOG_MAX_ENTRIES:-}" ] && GARNET_CMD="${GARNET_CMD} --slowlog-max-len ${GARNET_SLOWLOG_MAX_ENTRIES}"
[ -n "${GARNET_THREAD_POOL_MIN_THREADS:-}" ] && GARNET_CMD="${GARNET_CMD} --minthreads ${GARNET_THREAD_POOL_MIN_THREADS}"
[ -n "${GARNET_THREAD_POOL_MAX_THREADS:-}" ] && GARNET_CMD="${GARNET_CMD} --maxthreads ${GARNET_THREAD_POOL_MAX_THREADS}"
[ -n "${GARNET_THREAD_POOL_MIN_IO_THREADS:-}" ] && GARNET_CMD="${GARNET_CMD} --miniothreads ${GARNET_THREAD_POOL_MIN_IO_THREADS}"
[ -n "${GARNET_THREAD_POOL_MAX_IO_THREADS:-}" ] && GARNET_CMD="${GARNET_CMD} --maxiothreads ${GARNET_THREAD_POOL_MAX_IO_THREADS}"
[ -n "${GARNET_NETWORK_CONNECTION_LIMIT:-}" ] && GARNET_CMD="${GARNET_CMD} --network-connection-limit ${GARNET_NETWORK_CONNECTION_LIMIT}"
[ -n "${GARNET_DEVICE_TYPE:-}" ] && GARNET_CMD="${GARNET_CMD} --device-type ${GARNET_DEVICE_TYPE}"
[ -n "${GARNET_DEVICE_IO_BACKEND:-}" ] && GARNET_CMD="${GARNET_CMD} --device-io-backend ${GARNET_DEVICE_IO_BACKEND}"
[ -n "${GARNET_DEVICE_COMPLETION_THREADS:-}" ] && GARNET_CMD="${GARNET_CMD} --device-completion-threads ${GARNET_DEVICE_COMPLETION_THREADS}"
[ -n "${GARNET_DEVICE_THROTTLE_LIMIT:-}" ] && GARNET_CMD="${GARNET_CMD} --device-throttle-limit ${GARNET_DEVICE_THROTTLE_LIMIT}"
[ -n "${GARNET_DEVICE_IO_CONTEXTS:-}" ] && GARNET_CMD="${GARNET_CMD} --device-io-contexts ${GARNET_DEVICE_IO_CONTEXTS}"
[ -n "${GARNET_DEVICE_QUEUE_DEPTH:-}" ] && GARNET_CMD="${GARNET_CMD} --device-queue-depth ${GARNET_DEVICE_QUEUE_DEPTH}"
[ "${GARNET_DEVICE_URING_SQPOLL:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --device-uring-sqpoll"
[ -n "${GARNET_DEVICE_URING_SQPOLL_IDLE_MS:-}" ] && GARNET_CMD="${GARNET_CMD} --device-uring-sqpoll-idle-ms ${GARNET_DEVICE_URING_SQPOLL_IDLE_MS}"
[ -n "${GARNET_DEVICE_AIO_MAX_DEVICES:-}" ] && GARNET_CMD="${GARNET_CMD} --device-aio-max-devices ${GARNET_DEVICE_AIO_MAX_DEVICES}"
[ "${GARNET_ENABLE_REVIVIFICATION:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --reviv"
[ -n "${GARNET_REVIV_BIN_RECORD_SIZES:-}" ] && GARNET_CMD="${GARNET_CMD} --reviv-bin-record-sizes ${GARNET_REVIV_BIN_RECORD_SIZES}"
[ -n "${GARNET_REVIV_BIN_RECORD_COUNTS:-}" ] && GARNET_CMD="${GARNET_CMD} --reviv-bin-record-counts ${GARNET_REVIV_BIN_RECORD_COUNTS}"
[ -n "${GARNET_REVIV_FRACTION:-}" ] && GARNET_CMD="${GARNET_CMD} --reviv-fraction ${GARNET_REVIV_FRACTION}"
[ -n "${GARNET_REVIV_SEARCH_NEXT_HIGHER_BINS:-}" ] && GARNET_CMD="${GARNET_CMD} --reviv-search-next-higher-bins ${GARNET_REVIV_SEARCH_NEXT_HIGHER_BINS}"
[ -n "${GARNET_REVIV_BIN_BEST_FIT_SCAN_LIMIT:-}" ] && GARNET_CMD="${GARNET_CMD} --reviv-bin-best-fit-scan-limit ${GARNET_REVIV_BIN_BEST_FIT_SCAN_LIMIT}"
[ "${GARNET_REVIV_IN_CHAIN_ONLY:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --reviv-in-chain-only"
[ "${GARNET_MAIN_MEMORY_REPLICATION:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --main-memory-replication"
[ "${GARNET_FAST_AOF_TRUNCATE:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --fast-aof-truncate"
[ "${GARNET_ON_DEMAND_CHECKPOINT:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --on-demand-checkpoint"
[ "${GARNET_REPL_DISKLESS_SYNC:-}" = "true" ] && GARNET_CMD="${GARNET_CMD} --repl-diskless-sync"
[ -n "${GARNET_REPL_DISK_BASED_SYNC_CHUNK_SIZE:-}" ] && GARNET_CMD="${GARNET_CMD} --repl-disk-based-sync-chunk-size ${GARNET_REPL_DISK_BASED_SYNC_CHUNK_SIZE}"
[ -n "${GARNET_METRICS_SAMPLING_FREQ:-}" ] && GARNET_CMD="${GARNET_CMD} --metrics-sampling-freq ${GARNET_METRICS_SAMPLING_FREQ}"
[ -n "${GARNET_CONFIG_IMPORT_PATH:-}" ] && GARNET_CMD="${GARNET_CMD} --config-import-path ${GARNET_CONFIG_IMPORT_PATH}"
[ -n "${GARNET_CONFIG_IMPORT_FORMAT:-}" ] && GARNET_CMD="${GARNET_CMD} --config-import-format ${GARNET_CONFIG_IMPORT_FORMAT}"
[ -n "${GARNET_CONFIG_EXPORT_PATH:-}" ] && GARNET_CMD="${GARNET_CMD} --config-export-path ${GARNET_CONFIG_EXPORT_PATH}"
[ -n "${GARNET_CONFIG_EXPORT_FORMAT:-}" ] && GARNET_CMD="${GARNET_CMD} --config-export-format ${GARNET_CONFIG_EXPORT_FORMAT}"
[ -n "${GARNET_MAX_DATABASES:-}" ] && GARNET_CMD="${GARNET_CMD} --max-databases ${GARNET_MAX_DATABASES}"

eval ${GARNET_CMD} &
GARNET_PID=$!

echo "Waiting for Garnet to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
until nc -z 127.0.0.1 6379 2>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
    echo "ERROR: Garnet failed to start after $MAX_RETRIES retries. Exiting."
    kill $GARNET_PID 2>/dev/null || true
    exit 1
  fi
  echo "Waiting for Garnet... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 1
done

echo "✓ Garnet is ready on Unix socket /tmp/garnet.sock and TCP 127.0.0.1:6379"

echo "Starting Unbound DNS server..."
unbound -d -c /config/unbound/unbound.conf &

echo "Starting AdGuardHome..."
exec /opt/AdGuardHome/AdGuardHome -c /config/AdGuardHome/AdGuardHome.yaml -w /configfreq ${GARNET_METRICS_SAMPLING_FREQ}"

# Config import/export
[ -n "${GARNET_CONFIG_IMPORT_PATH:-}" ] && GARNET_CMD="${GARNET_CMD} --config-import-path ${GARNET_CONFIG_IMPORT_PATH}"
[ -n "${GARNET_CONFIG_IMPORT_FORMAT:-}" ] && GARNET_CMD="${GARNET_CMD} --config-import-format ${GARNET_CONFIG_IMPORT_FORMAT}"
[ -n "${GARNET_CONFIG_EXPORT_PATH:-}" ] && GARNET_CMD="${GARNET_CMD} --config-export-path ${GARNET_CONFIG_EXPORT_PATH}"
[ -n "${GARNET_CONFIG_EXPORT_FORMAT:-}" ] && GARNET_CMD="${GARNET_CMD} --config-export-format ${GARNET_CONFIG_EXPORT_FORMAT}"

# Max databases
[ -n "${GARNET_MAX_DATABASES:-}" ] && GARNET_CMD="${GARNET_CMD} --max-databases ${GARNET_MAX_DATABASES}"

# Execute
eval ${GARNET_CMD} &
GARNET_PID=$!

# Wait for Garnet to be ready (check both Unix socket and TCP)
echo "Waiting for Garnet to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
until nc -z 127.0.0.1 6379 2>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
    echo "ERROR: Garnet failed to start after $MAX_RETRIES retries. Exiting."
    kill $GARNET_PID 2>/dev/null || true
    exit 1
  fi
  echo "Waiting for Garnet... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 1
done

echo "✓ Garnet is ready on Unix socket /tmp/garnet.sock and TCP 127.0.0.1:6379"

echo "Starting Unbound DNS server..."
unbound -d -c /config/unbound/unbound.conf &

echo "Starting AdGuardHome..."
exec /opt/AdGuardHome/AdGuardHome -c /config/AdGuardHome/AdGuardHome.yaml -w /config