# 🚀 AdGuard Home + Unbound + Garnet

![Docker Pulls](https://img.shields.io/docker/pulls/imthai/adguardhome-unbound-garnet)
![Docker Stars](https://img.shields.io/docker/stars/imthai/adguardhome-unbound-garnet)
![Multi-Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-blue)

A Docker container combining [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome), [Unbound](https://unbound.docs.nlnetlabs.nl/en/latest/) with DNS prefetching, and [Garnet](https://microsoft.github.io/garnet/) (Microsoft's high-performance cache store) as an ultra-fast in-memory caching layer — built for speed, privacy, and enterprise-grade performance.

This image is **multi-architecture**, providing native support for both **amd64** (PCs, Unraid servers) and **arm64** (Raspberry Pi, Apple M-series, Kubernetes) platforms.

---

## 🔍 Why This Setup?

### ✅ Benefits of Unbound with Prefetching:
- **Faster DNS Resolution**: Frequently accessed DNS records are proactively resolved and cached
- **Lower Latency**: Reduces delays caused by DNS lookups, especially useful for latency-sensitive applications
- **Better Network Performance**: Prefetched responses are immediately available, reducing wait times

### 🧠 Benefits of Using Garnet (Not Redis):
- **Ultra-High Performance**: Sub-millisecond cache lookups via RESP protocol (faster than Redis for DNS workloads)
- **Memory Efficient**: Smart index sizing with revivification (K keys = K × 16 bytes) prevents cache bloat
- **Automatic Recovery**: Revivification engine automatically recovers freed space from expired entries
- **Optional Storage Tier**: Extend cache beyond RAM via optional disk-backed tiering
- **Enterprise-Grade**: Built by Microsoft for production workloads with extreme reliability

### 🛡️ Security: Docker Hardened Image (DHI)
This image is built upon **Docker Hardened Images (DHI)**, providing enterprise-grade security:
- **Minimal Surface Area**: Only essential packages included, significantly lowering attack surface
- **Zero Known Vulnerabilities**: Optimized to maintain 0-CVE status for critical/high-priority vulnerabilities
- **Supply Chain Security**: Digitally signed and verified base images with full SBOM support
- **Immutable & Locked**: Package manager locked after build to prevent unauthorized installations

---

## ⚡ Performance Characteristics

This container is pre-optimized for high-throughput, low-latency DNS resolution:

| Metric | Value | Note |
|--------|-------|------|
| **Cache Latency** | <1ms | From Garnet in-memory cache |
| **Index Lookup** | O(1) | Hash table with revivification |
| **Memory Efficiency** | 16 bytes/key | Formula: K keys = K × 16 bytes |
| **Default Memory** | 128MB | Configurable via GARNET_MEMORY_SIZE |
| **Unbound Slabs** | 4 | Matches num-threads to reduce lock contention |
| **Protocol** | RESP (Redis) | Native Garnet support over TCP |
| **Connection** | 127.0.0.1:6379 | Unbound → Garnet via localhost TCP |
| **Typical Latency** | 30-40ms | Average (includes recursive lookups) |

> [!TIP]
> **Understanding Latency**: Response times around 30-40ms are normal for recursive setups. This balances near-instant cache hits (<1ms) with initial recursive lookups to populate the cache.

---

## 🚀 Installation Methods (LOCAL)

Pick one of 4 ways to get running locally. **All work the same** - just different levels of automation.

---

### **Prerequisites**

All methods require:
- **Docker** (https://www.docker.com) - For running containers
- **Docker Compose** - For orchestrating multiple services

Check if installed:
```bash
docker --version
docker compose version
```

---

### **Option 0: Auto-Install Script (Fastest) ⚡**

For Linux/macOS users - **fully automated setup in 60 seconds:**

```bash
curl -fsSL https://raw.githubusercontent.com/andreialionte/adguardhome-unbound-caching/main/install.sh | sh
```

**What it does automatically:**
- ✅ Checks Docker & Docker Compose prerequisites
- ✅ Downloads all files from GitHub
- ✅ Creates folder structure at `~/adguard-unbound-caching`
- ✅ Generates `.env` with sensible defaults
- ✅ **Builds Docker image** (compiles Garnet + Unbound + AdGuard)
- ✅ **Starts all services** (Garnet, Unbound, AdGuard)
- ✅ Services are LIVE and READY immediately

**That's it! Everything is running:**

```
Access web UI:    http://localhost:3000
Default user:     admin
Default password: admin
DNS is live on:   localhost:53 (TCP/UDP)
```

**With custom directory & verbose output:**

```bash
curl -fsSL https://raw.githubusercontent.com/andreialionte/adguardhome-unbound-caching/main/install.sh | sh -s -- -d /opt/dns -v
```

**Available flags:**
- `-d DIR` - Custom installation directory (default: ~/adguard-unbound-caching)
- `-r` - Reinstall (stop containers, remove old, rebuild fresh)
- `-u` - Uninstall completely (remove all files and containers)
- `-v` - Verbose output (see detailed logs)
- `-h` - Show help message

**Timeline:**
- ~5 seconds: Prerequisites + download files
- ~30-60 seconds: Build Docker image
- ~10 seconds: Start containers
- **Total: 45-85 seconds to fully running**

---

---

### **Option 1: Clone & Compose (All Platforms) 🎛️**

For Windows, or users who prefer to review config before starting:

#### Quick Start (4 steps):

```bash
# 1. Clone and enter directory
git clone https://github.com/andreialionte/adguardhome-unbound-caching.git
cd adguardhome-unbound-caching

# 2. Copy environment template (optional)
cp .env.example .env

# 3. Build image + start all services
docker compose up -d

# 4. Done! Services are running at http://localhost:3000
```

#### Detailed Walkthrough:

**Step 1: Clone Repository**

```bash
git clone https://github.com/andreialionte/adguardhome-unbound-caching.git
cd adguardhome-unbound-caching
```

**Step 2: Review Configuration (Optional)**

```bash
# Copy the example config
cp .env.example .env

# Review defaults (no editing needed if defaults are OK):
cat .env
```

The `.env` file contains Garnet tuning parameters:
```bash
GARNET_MEMORY_SIZE=128m         # Total cache memory
GARNET_INDEX_SIZE=16m           # Starting index size
GARNET_INDEX_MAX_SIZE=64m       # Maximum index size
```

**Step 3: Customize (Optional)**

To adjust memory or ports:

```bash
# Edit environment variables:
nano .env

# Or edit docker-compose.yml directly for ports/volumes:
nano docker-compose.yml
```

**Common customizations:**
- Change `GARNET_MEMORY_SIZE` for different cache sizes (128m, 256m, 512m, 1g)
- Modify `ports:` section in docker-compose.yml to change DNS/Web UI ports
- Adjust `deploy.resources.limits` in docker-compose.yml for system resources

**Step 4: Build & Start Services**

```bash
# Build image locally + start all services
docker compose up -d

# Wait 30-60 seconds for build + startup...
```

**Expected output:**
```
[+] Running 1/1
 ✔ Container adguard-unbound-caching  Started
```

**Step 5: Monitor Startup (Optional)**

```bash
# View real-time logs
docker compose logs -f

# Exit logs with Ctrl+C
```

**Step 6: Access & Test**

Once startup completes (30-60 seconds):

1. **Open Web UI:** `http://localhost:3000`
   - Default username: `admin`
   - Default password: `admin`
   - ⚠️ **Change this immediately!**

2. **Test DNS:** 
   ```bash
   # From your machine:
   nslookup google.com localhost
   dig @localhost +short google.com
   ```

3. **Configure AdGuard:**
   - Add upstream DNS servers
   - Enable query logging
   - Add blocklists
   - Set safe search policies

**Step 7: Useful Commands**

```bash
# View current status
docker compose ps

# Check logs
docker compose logs -f

# Restart if needed
docker compose restart

# Stop everything
docker compose down

# Stop + remove all data (clean slate)
docker compose down -v

# Update and rebuild
git pull
docker compose up -d --build
```

**Why use docker-compose?**
- ✅ Works on Windows, Linux, macOS
- ✅ Full control over configuration before starting
- ✅ Easy to customize ports, memory, volumes
- ✅ Easy to troubleshoot with logs
- ✅ Simple to stop/restart/rebuild

---

### **Option 2: Manual Docker Commands (Full Control) 🔧**

```bash
# Build image manually
docker build -t adguard-unbound-garnet:latest .

# Create config directory
mkdir -p ~/adguard-config

# Run container with explicit options
docker run -d \
  --name adguard-dns \
  --restart unless-stopped \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 3000:3000/tcp \
  -v ~/adguard-config:/config \
  -e GARNET_MEMORY_SIZE=128m \
  -e GARNET_INDEX_SIZE=16m \
  -e GARNET_INDEX_MAX_SIZE=64m \
  adguard-unbound-garnet:latest

# View logs
docker logs -f adguard-dns

# Stop container
docker stop adguard-dns

# Start again
docker start adguard-dns
```

**Why this way?**
- Maximum control over every parameter
- Good for scripting / automation
- Most manual but most explicit

Access AdGuard Web UI at `http://localhost:3000`

---

## **Which Option Should I Use?**

| Your Situation | Use Option | Time | Platform |
|---|---|---|---|
| **One-liner, fully automated** | 0: Auto-Install Script | 45-85 sec | Linux/macOS |
| **Manual setup, full review** | 1: Clone & Compose (Quick or Detailed) | 60-90 sec | All platforms |
| **Expert / Scripting / CI/CD** | 2: Manual docker commands | 60-90 sec | All platforms |

**Quick Decision Guide:**

| OS | Recommendation |
|---|---|
| **Linux/macOS** | Option 0 (one command, fully automated) |
| **Windows** | Option 1 (git clone + docker compose) |
| **Want to customize before starting?** | Option 1 (has quick & detailed versions) |
| **CI/CD pipelines / scripting?** | Option 2 (manual docker commands) |

**All options install the same thing - just different convenience levels!**

---

## **Relationship: Dockerfile vs docker-compose.yml**

```
Dockerfile  ─→  How to BUILD image       (recipe)
     ↓
docker-compose.yml  ─→  How to RUN container  (configuration)
```

- **Dockerfile**: Instructions to compile image (one time)
- **docker-compose.yml**: Configuration to run container (every time)
- **Both work together** in all 3 options above

---

### Kubernetes Deployment (Advanced)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dns-config
data:
  GARNET_MEMORY_SIZE: "256m"
  GARNET_INDEX_SIZE: "32m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adguard-dns
spec:
  replicas: 2
  selector:
    matchLabels:
      app: adguard-dns
  template:
    metadata:
      labels:
        app: adguard-dns
    spec:
      containers:
      - name: adguard-dns
        image: andreialionte/adguardhome-unbound-caching:latest  # Replace 'andreialionte' with your registry
        imagePullPolicy: Always
        ports:
        - name: dns-tcp
          containerPort: 53
          protocol: TCP
        - name: dns-udp
          containerPort: 53
          protocol: UDP
        - name: web-ui
          containerPort: 3000
          protocol: TCP
        envFrom:
        - configMapRef:
            name: dns-config
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command: ["sh", "-c", "nc -z 127.0.0.1 53"]
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 5
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: adguard-config
---
apiVersion: v1
kind: Service
metadata:
  name: adguard-dns
spec:
  type: LoadBalancer
  selector:
    app: adguard-dns
  ports:
  - name: dns-tcp
    port: 53
    protocol: TCP
  - name: dns-udp
    port: 53
    protocol: UDP
  - name: web-ui
    port: 3000
    protocol: TCP
```

---

## ⚙️ Configuration

### 📂 Directory Structure

All configuration persists in the volume mapped to `/config`:

```
config/
├── AdGuardHome/              # AdGuard Home data & filters
│   ├── AdGuardHome.yaml      # Main configuration
│   ├── querylog.db           # Query log database
│   └── data/
├── unbound/                  # Unbound recursive resolver
│   ├── unbound.conf          # Main configuration
│   └── unbound.conf.d/
│       ├── cache.conf        # Garnet cachedb backend (AUTO-GENERATED)
│       ├── adguard.conf      # AdGuard Home integration
│       └── ...
└── garnet/                   # Garnet in-memory cache
    ├── redis.conf            # Garnet server configuration
    ├── data/                 # Checkpoint and data files
    └── (optional) cert.pfx   # TLS certificate
```

**First Run**: After starting, AdGuard Home will auto-generate `AdGuardHome.yaml` and create necessary directories.

### 🔧 Environment Variables

Control Garnet's behavior without editing config files:

| Variable | Default | Description |
|----------|---------|-------------|
| `GARNET_MEMORY_SIZE` | `128m` | Total memory for Garnet cache (e.g., `256m`, `1g`) |
| `GARNET_INDEX_SIZE` | `16m` | Initial hash table index size (grows to MAX_SIZE) |
| `GARNET_INDEX_MAX_SIZE` | `64m` | Maximum index size before key eviction (LRU) |
| `GARNET_PASSWORD` | *(unset)* | Optional AUTH password for client connections |
| `GARNET_TLS_ENABLED` | `false` | Enable TLS encryption (requires cert.pfx) |

**Set via .env file:**

```bash
# .env
GARNET_MEMORY_SIZE=256m
GARNET_INDEX_SIZE=32m
GARNET_INDEX_MAX_SIZE=128m
GARNET_PASSWORD=your-secure-password-here
GARNET_TLS_ENABLED=false
```

**Or via docker-compose.yml:**

```yaml
environment:
  GARNET_MEMORY_SIZE: "512m"
  GARNET_INDEX_SIZE: "64m"
  GARNET_INDEX_MAX_SIZE: "256m"
```

### 💾 Memory Sizing Guide

Estimate total memory needed for DNS caching:

```
Total Memory = Log Memory + Index Memory

Log Memory   = 128m (default, for actual cached DNS records)
Index Memory = K × 16 bytes (K = number of cached entries)

Example: 10 million cached DNS entries
Index = 10,000,000 × 16 bytes = 160MB
Total = 128m + 160m = 288MB
→ Recommend setting GARNET_MEMORY_SIZE=512m for safety margin
```

**Sizing for Different Scenarios:**

| Scenario | Keys | Index | Log | Total | GARNET_MEMORY_SIZE |
|----------|------|-------|-----|-------|-------------------|
| Small Home | 100K | 1.6m | 128m | 130m | 256m |
| Large Home | 1M | 16m | 128m | 144m | 512m |
| Small Business | 5M | 80m | 128m | 208m | 512m |
| Large Business | 10M | 160m | 128m | 288m | 1024m |
| Enterprise | 50M | 800m | 128m | 928m | 2g |

### 🔒 Security Configuration

#### Enable Garnet Authentication

```bash
# Generate a strong password (Linux/macOS)
openssl rand -base64 32

# Update .env
GARNET_PASSWORD="SomeSecurePassword_Here_MinimumLength"

# Verify in container logs
docker compose logs | grep "AUTH enabled"
```

#### Enable Garnet TLS

```bash
# Generate self-signed certificate (requires OpenSSL)
# For macOS/Linux:
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 365

# Convert to PKCS12 (.pfx format)
openssl pkcs12 -export -in cert.pem -inkey key.pem -out config/garnet/cert.pfx -name "garnet"

# Update .env
GARNET_TLS_ENABLED=true
```

#### Docker Network Isolation

Restrict Garnet to internal container access only (default behavior):

```yaml
# docker-compose.yml - Garnet port NOT exposed
ports:
  - "53:53/tcp"           # DNS (exposed)
  - "53:53/udp"           # DNS (exposed)
  - "3000:3000/tcp"       # Web UI (exposed)
  # 6379 is NOT exposed - only accessible within container
```

### 🏗️ Docker Compose Full Configuration

```yaml
version: "3.8"

services:
  adguard-dns:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: adguard-unbound-caching
    hostname: adguard-dns
    
    networks:
      - dns_network
    
    # Exposed ports
    ports:
      - "53:53/tcp"           # DNS TCP
      - "53:53/udp"           # DNS UDP
      - "67:67/udp"           # DHCP (optional)
      - "3000:3000/tcp"       # AdGuard Web UI
      - "853:853/tcp"         # DNS over TLS (optional)
    
    # Persistent volumes
    volumes:
      - ./config:/config
    
    # Environment configuration
    env_file:
      - .env
    environment:
      GARNET_MEMORY_SIZE: "${GARNET_MEMORY_SIZE:-128m}"
      GARNET_INDEX_SIZE: "${GARNET_INDEX_SIZE:-16m}"
      GARNET_INDEX_MAX_SIZE: "${GARNET_INDEX_MAX_SIZE:-64m}"
    
    # Resource limits (adjust for your system)
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '1'
          memory: 512M
    
    restart: unless-stopped
    
    # Health monitoring
    healthcheck:
      test: ["CMD", "sh", "-c", "nc -z 127.0.0.1 53 && curl -s http://127.0.0.1:3000 > /dev/null"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    
    # Logging
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  dns_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

---

## 🔍 Monitoring & Troubleshooting

### Health Checks

```bash
# Test DNS resolution
nslookup google.com localhost
dig @localhost +short google.com
dig @localhost google.com +trace  # See full resolution path

# Check AdGuard Web UI API
curl http://localhost:3000/api/status | jq .

# Check all services running
docker compose ps
```

### Verify Garnet Connection

```bash
# Test Garnet from inside container
docker exec adguard-unbound-caching redis-cli ping
# Should respond: PONG

# View Garnet stats
docker exec adguard-unbound-caching redis-cli INFO stats | head -20

# View memory usage
docker exec adguard-unbound-caching redis-cli INFO memory
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f adguard-dns

# With timestamps
docker compose logs -f --timestamps

# Last 100 lines
docker compose logs --tail=100
```

### Performance Monitoring

```bash
# Monitor DNS query latency
docker compose logs -f | grep "query_latency"

# Check Garnet cache hit ratio
docker exec adguard-unbound-caching redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"

# Memory usage trend (collect over time)
watch -n 5 'docker exec adguard-unbound-caching redis-cli INFO memory | grep used_memory'
```

### Common Issues & Solutions

#### ✗ DNS queries not resolving

```bash
# Check if Unbound can reach Garnet
docker exec adguard-unbound-caching unbound-checkconf

# Test DNS directly
docker exec adguard-unbound-caching nslookup -server 127.0.0.1 google.com
```

**Solution**: Verify Garnet is running and accessible on port 6379

#### ✗ High memory usage

```bash
# Check Garnet stats
docker exec adguard-unbound-caching redis-cli INFO memory

# Review cache size
docker exec adguard-unbound-caching redis-cli DBSIZE
```

**Solution**: Reduce `GARNET_MEMORY_SIZE` or enable read-write cache eviction policy

#### ✗ Garnet authentication fails

```bash
# Verify password set
grep GARNET_PASSWORD .env

# Test AUTH inside container
docker exec adguard-unbound-caching redis-cli AUTH your-password ping
```

**Solution**: Ensure `GARNET_PASSWORD` matches in all configs

#### ✗ TLS certificate errors

```bash
# Verify certificate exists
docker exec adguard-unbound-caching ls -la /config/garnet/cert.pfx

# Check certificate validity
openssl pkcs12 -in config/garnet/cert.pfx -nokeys -info
```

**Solution**: Regenerate certificate if expired

---

## 🎯 Unraid-Specific Setup

This container works optimally on Unraid systems:

### Container Configuration

1. **Image**: Use Docker Hub image or build locally
2. **Container Name**: `adguard-dns`
3. **Network Type**: Create and assign dedicated IP (e.g., `br0.100`)
4. **Host Port 53**: Leave empty if using dedicated IP
5. **Volume Mounts**:
   - Container: `/config` → Host: `/mnt/user/appdata/adguard-dns`

### First-Run Setup

After starting:

1. Access `http://<container-ip>:3000`
2. Login with default credentials: `admin`/`admin`
3. Change password in Settings → General
4. Configure upstream DNS servers in Settings
5. Add blocklists in Filters → Blocklists

### Performance Optimization for Unraid

```ini
# Recommended appdata share settings:
# Share: appdata
# Include: ✓
# High-water mark: 50%
# Disk preference: High speed cache (if available)
# Allocation method: fill-up
```

---

## 📈 Garnet Performance Tuning

### Memory Tiers (Advanced)

Garnet supports memory-only and hybrid (disk-backed) modes:

```bash
# Memory-only mode (default, fastest for DNS)
GARNET_MEMORY_SIZE=512m

# Hybrid mode (disk-backed, scales to billions of keys)
# Requires: --storage-tier true in entrypoint.sh
```

### Index Sizing (Advanced)

The index hash table grows dynamically:

```
Initial: GARNET_INDEX_SIZE (e.g., 16m)
    ↓ (as keys added and hash density increases)
Maximum: GARNET_INDEX_MAX_SIZE (e.g., 64m)
    ↓ (if exceeded, LRU eviction begins)
```

**Formula for DNS workload:**
```
Expected Max Keys = (max cache entries you want)
Required Index    = Expected Max Keys × 16 bytes

GARNET_INDEX_SIZE      = Required Index / 2  # Start at half
GARNET_INDEX_MAX_SIZE  = Required Index × 2  # Allow growth
```

### Revivification (Automatic Memory Recovery)

Garnet automatically recovers freed memory using power-of-2 bins. This is particularly effective for DNS workloads where entries expire uniformly.

No configuration needed—enabled by default.

---

## 🔄 Updates & Maintenance

### Update Container Image

```bash
# Pull latest image
docker compose pull

# Recreate container with new image
docker compose up -d

# Verify running version
docker exec adguard-unbound-caching AdGuardHome -v
```

### Backup Configuration

```bash
# Backup entire config directory
tar -czf adguard-backup-$(date +%Y%m%d).tar.gz config/

# Restore from backup
tar -xzf adguard-backup-20240101.tar.gz -C .
```

### Cleanup & Maintenance

```bash
# Clean up unused Docker images
docker image prune -a

# Clean up volumes (⚠️ WARNING: Deletes data)
docker volume prune

# Stop all services
docker compose down

# Remove all data (⚠️ WARNING: Deletes ALL)
docker compose down -v
```

---

## 📦 Pre-built Registry Images

We provide pre-built multi-arch images on:

- **Docker Hub**: `imthai/adguardhome-unbound-garnet:latest`
  - Platforms: `linux/amd64`, `linux/arm64`

> [!NOTE]
> **Building your own?** When you push to your registries, replace placeholders with your username or organization.

When you build and push your custom images:

- **GitHub Container Registry**: `ghcr.io/andreialionte/adguardhome-unbound-caching:latest` (replace `andreialionte` with your username)
- **Docker Hub**: `andreialionte/adguardhome-unbound-caching:latest` (replace `andreialionte` with your username)

---

## 🛠️ Building Locally

```bash
# Build single-arch (your current host's arch)
docker build -t adguardhome-unbound-caching:latest .

# Build multi-arch (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t andreialionte/adguardhome-unbound-caching:latest \
  --push .
```

Replace `andreialionte` with your Docker Hub username.

---

## 📝 Configuration Files Reference

### unbound.conf

Main Unbound settings:

- `num-threads`: 4 (matches slab settings)
- `prefetch`: yes (proactive caching)
- `prefetch-key`: yes (cache keys too)
- `cache-min-ttl`: 0 (respect authoritative TTL)
- `cache-max-ttl`: 86400 (max 1 day)

### cache.conf

Garnet caching backend (auto-generated):

```conf
cachedb:
    backend: redis
    redis-server-host: 127.0.0.1
    redis-server-port: 6379
    redis-timeout: 100
    cachedb-no-store: no
```

### redis.conf (Garnet Configuration)

Pre-tuned for DNS workload:

```conf
bind 127.0.0.1
port 6379
maxmemory 128mb
maxmemory-policy allkeys-lru
appendonly yes
loglevel notice
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. **Test locally**: `docker compose up -d && dig @localhost google.com`
2. **Verify stats**: `docker exec ... redis-cli INFO`
3. **Check logs**: `docker compose logs`
4. **Submit PR** with clear description and test results

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file

---

## 🙏 Credits

- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) - DNS filtering
- [Unbound](https://nlnetlabs.nl/projects/unbound/about/) - Recursive DNS
- [Garnet](https://github.com/microsoft/garnet) - Cache store by Microsoft
- [Docker Hardened Images](https://dhi.io/) - Base image security

---

**Last Updated**: January 2025  
**Multi-Arch**: ✅ amd64, ✅ arm64  
**Docker Min Version**: 20.10+  
**Docker Compose Version**: 2.0+  
