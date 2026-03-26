# 🚀 AdGuard Home + Unbound + Garnet

![Docker Pulls](https://img.shields.io/docker/pulls/imthai/adguardhome-unbound-garnet)
![Docker Stars](https://img.shields.io/docker/stars/imthai/adguardhome-unbound-garnet)

A Docker container combining [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome), [Unbound](https://unbound.docs.nlnetlabs.nl/en/latest/) (with DNS prefetching), and [Garnet](https://microsoft.github.io/garnet/) (Microsoft's high-performance cache store) as an in-memory caching layer — built for speed, privacy, and performance.

This image is multi-architecture and provides native support for both amd64 (PCs, Unraid servers) and arm64 (Raspberry Pi, Apple M-series, etc.) platforms.

---

## 🔍 Why This Setup?

### ✅ Benefits of Unbound with Prefetching:
- **Faster DNS Resolution**: Frequently accessed DNS records are proactively resolved and cached.
- **Lower Latency**: Reduces delays caused by DNS lookups, especially useful for latency-sensitive applications.
- **Better Network Performance**: Prefetched responses are immediately available, reducing wait times.

### 🧠 Benefits of Using Garnet:
- **High-Performance Cache**: Garnet caches DNS results in memory with ultra-low latency, offering faster-than-Redis retrieval.
- **Improved Throughput**: Offloads repetitive DNS requests from upstream servers with optimized memory efficiency.
- **Reduced Load**: Minimizes the number of external DNS queries with configurable memory tiers and storage tier support.
- **Enterprise-Grade Storage**: Supports larger-than-memory datasets with optional tiering to disk. Built by Microsoft for production workloads.

### 🛡️ Security: Docker Hardened Image (DHI)
This image is built upon **Docker Hardened Images (DHI)**, providing a higher level of security compared to standard base images:
- **Minimal Surface Area**: Only essential packages are included, significantly lowering the potential attack surface.
- **Zero Known Vulnerabilities**: Optimized to maintain a 0-CVE status for critical and high-priority vulnerabilities.
- **Supply Chain Security**: Digitally signed and verified base images with full SBOM (Software Bill of Materials) support.
- **Immutable & Locked**: The package manager and external repositories are locked after build to prevent unauthorized software installation at runtime.

---

## ⚡ Performance Tuning

This container is pre-optimized for high-throughput and low-latency DNS resolution:

- **Unbound Slabs**: Aligned to `4` to match the `num-threads` setting, significantly reducing internal lock contention.
- **Garnet RAM Optimization**: Configured to `128MB` with revivification enabled for efficient memory reuse and recovery of freed space; auto-resizable index for scalability.
- **TCP Communication**: Communication between Unbound and Garnet occurs via localhost TCP (`127.0.0.1:6379`), leveraging Garnet's native RESP protocol support.

> [!TIP]
> **Understanding Latency**: Average response times around 30-40ms are normal for a recursive/forwarding setup. This average balances near-instant cache hits (<1ms) and the initial recursive lookups required to populate the cache [Inference].

---

## 🚀 Quick Start (docker-compose)

Here is a sample `docker-compose.yml` to get you started.

```yaml
version: "3.8"
services:
  adguard-dns:
    image: imthai/adguardhome-unbound-garnet:latest
    container_name: adguard-dns
    # It's recommended to use a dedicated IP (macvlan/ipvlan)
    # or, if in bridge mode, map the necessary ports:
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "3000:3000/tcp" # AdGuard Web UI port
    volumes:
      # /config is the main volume for all config and data
      - ./config:/config
    environment:
      # Optional Garnet configuration via environment variables
      GARNET_MEMORY_SIZE: "128m"
      GARNET_INDEX_SIZE: "16m"
      GARNET_INDEX_MAX_SIZE: "64m"
      # GARNET_PASSWORD: "your-secure-password"  # Uncomment to enable AUTH
      # GARNET_TLS_ENABLED: "false"              # Set to true for TLS
    restart: unless-stopped
```
---

## ⚙️ Configuration and Paths

### 🔷 Note for Unraid Users
This container is tailored to work well with Unraid:
1. When adding the container, map the **Container Path** `/config` to your desired **Host Path** in `appdata`, e.g., `/mnt/user/appdata/adguard-unbound-redis/`.
2. It is highly recommended to assign a **dedicated IP** (e.g., `br0.100`) to the container, as port `53` is often occupied by Unraid/Docker.

### 📂 File Structure

All configuration is persisted in the volume you map to `/config`. After the first run, this folder will be populated with:

| Directory in your volume | Description |
| :--- | :--- |
| `./AdGuardHome/` | `AdGuardHome.yaml` config and working data. |
| `./unbound/` | Configuration files for Unbound. |
| `./garnet/` | Configuration and data files for Garnet (checkpoints, data, redis.conf). |
| `./userfilters/` | **Place your custom filter files here**. |

**Default Settings:**
- **AdGuard Home Web UI**: `http://<your-ip>:3000`
- **Default credentials**: `admin` / `admin`

---

## 🌐 DNS & Cache Configuration

By default, Unbound is set to forward all DNS requests to **public resolvers** and cache results in **Garnet**. Currently, **Cloudflare DNS** is used.

- You can modify this behavior in the `./unbound/forward-queries.conf` file.
- Other DNS providers are pre-defined and can be customized or added.
- To enable **full recursive resolution** (where Unbound queries root servers directly), simply **delete** the `forward-queries.conf` file and restart.

---

### 📂 Custom User Filters

You can add your own filter blocklist files to the container by placing them in the `/config/userfilters/` folder.

**Important:** To enable AdGuard Home to read your custom filter files, you must ensure that your configuration file (`AdGuardHome.yaml`) contains:

```yaml
safe_fs_patterns:
  - /config/userfilters/*
```
---

### 📂 Custom User Filters

You can now add your own filter blocklist files to the container by placing them in the `/config/userfilters/` folder.

**Important:**  
To enable AdGuard Home to read your custom filter files, you must ensure that your configuration file (`AdGuardHome.yaml`) contains:

```
safe_fs_patterns:
   - /config/userfilters/*
```

You have two options:

- **Option 1: Manual update**
  Edit `AdGuardHome.yaml` and add or update the `safe_fs_patterns` section as shown above. Then restart the container.

- **Option 2: Auto-generate fresh config**
  Delete (or move) your existing `AdGuardHome.yaml` config file and restart the container.
  The container will create a new config file with the correct `safe_fs_patterns` entry by default.
  ⚠️ *Warning: This resets all your AdGuard Home settings!* 

**Afterwards:**
Add your local blocklist(s) in AdGuard Home’s web UI (Filters → DNS blocklists) by specifying the file path, for example: `/config/userfilters/myblocklist.txt`.

---

## 🚫 Blocklists Enabled by Default

- [AdGuard DNS Filter](https://github.com/AdguardTeam/AdguardSDNSFilter) 
- [HaGeZi's Threat Intelligence Feeds](https://github.com/hagezi/dns-blocklists?tab=readme-ov-file#tif) 
- [HaGeZi's Multi PRO Blocklist](https://github.com/hagezi/dns-blocklists?tab=readme-ov-file#pro) 

---

Enjoy faster, smarter, and more private DNS with this all-in-one Docker solution! 🛡️⚡
