#!/bin/sh

# AdGuard Home + Unbound + Garnet - Installation Script
#
# This script installs the complete DNS + caching stack with Docker Compose.
# It follows the same patterns as the official AdGuard Home installer.
#
# Exit the script if a pipeline fails (-e), prevent accidental filename
# expansion (-f), and consider undefined variables as errors (-u).

set -e -f -u

# ============================================================================
# Script Configuration - Defaults
# ============================================================================

readonly REPO_URL='https://github.com/andreialionte/adguardhome-unbound-caching'
readonly REPO_RAW="${REPO_URL}/raw/main"
readonly SCRIPT_URL="${REPO_RAW}/install.sh"

# Default values
out_dir="${HOME}/adguard-unbound-caching"
verbose='0'
reinstall='0'
uninstall='0'

# ============================================================================
# Logging Functions
# ============================================================================

# Function log is an echo wrapper that writes to stderr if the caller
# requested verbosity level greater than 0. Otherwise, it does nothing.
log() {
	if [ "$verbose" -gt '0' ]; then
		echo "$1" 1>&2
	fi
}

# Function error_exit is an echo wrapper that writes to stderr and stops
# the script execution with code 1.
error_exit() {
	echo "$1" 1>&2
	exit 1
}

# ============================================================================
# Helper Functions
# ============================================================================

# Function is_command checks if the command exists on the machine.
is_command() {
	command -v "$1" >/dev/null 2>&1
}

# Function usage prints the note about how to use the script.
usage() {
	cat <<'USAGE' 1>&2
install.sh: AdGuard Home + Unbound + Garnet Installer (Plug & Play)

This script downloads, builds, and starts the complete DNS + caching stack.
By the time it finishes, everything is RUNNING and ready to use!

Usage:  install.sh [-d output_dir] [-r | -R] [-u | -U] [-v | -V] [-h]

Options:
  -d DIR        installation directory (default: ~/adguard-unbound-caching)
  -r            reinstall if already exists (opposite of -R)
  -R            do not reinstall if already exists (opposite of -r, default)
  -u            uninstall and remove all files (opposite of -U)
  -U            do not uninstall (opposite of -u, default)
  -v            verbose output (opposite of -V)
  -V            no verbose output (opposite of -v, default)
  -h            show this help message and exit

What it does:
  1. Downloads all files from GitHub
  2. Creates folder structure
  3. Builds the Docker image
  4. Starts all services (Garnet, Unbound, AdGuard)
  5. Services are immediately accessible

Examples:

  install.sh
    Install and start at ~/adguard-unbound-caching, then go to http://localhost:3000

  install.sh -d /opt/dns -v
    Install to /opt/dns with verbose output and start everything

  install.sh -r
    Reinstall (stop, remove old, build fresh, start again)

  install.sh -u
    Uninstall completely
USAGE
	exit 2
}

# ============================================================================
# Option Parsing
# ============================================================================

# Function parse_opts parses the options list and validates its combinations.
parse_opts() {
	while getopts "d:hRUrvV" opt "$@"; do
		case "$opt" in
		d)
			out_dir="$OPTARG"
			;;
		h)
			usage
			;;
		r)
			reinstall='1'
			;;
		R)
			reinstall='0'
			;;
		u)
			uninstall='1'
			;;
		U)
			uninstall='0'
			;;
		v)
			verbose='1'
			;;
		V)
			verbose='0'
			;;
		*)
			log "bad option $OPTARG"
			usage
			;;
		esac
	done

	# Validate mutually exclusive options
	if [ "$uninstall" -eq '1' ] && [ "$reinstall" -eq '1' ]; then
		error_exit 'the -r and -u options are mutually exclusive'
	fi

	# Log parsed options
	log "out_dir: $out_dir"
	log "reinstall: $reinstall"
	log "uninstall: $uninstall"
	log "verbose: $verbose"
}

# ============================================================================
# Prerequisite Checks
# ============================================================================

# Function check_required checks if the required software is available on
# the machine. Required: Docker and Docker Compose
check_required() {
	log 'checking required software'

	if ! is_command 'docker'; then
		error_exit 'Docker is required. Please install from https://www.docker.com'
	fi

	if ! is_command 'docker-compose' && ! docker compose version >/dev/null 2>&1; then
		error_exit 'Docker Compose is required. Please install it.'
	fi

	log "Docker version: $(docker --version)"
	log "Docker Compose version: $(docker compose version 2>/dev/null || docker-compose --version)"
}

# ============================================================================
# Directory Setup
# ============================================================================

# Function check_out_dir validates that output directory is set and can be created.
check_out_dir() {
	if [ -z "$out_dir" ]; then
		error_exit 'output directory must be specified'
	fi

	log "output directory: $out_dir"
}

# Function setup_directories creates the full directory structure.
setup_directories() {
	log 'setting up directory structure'

	mkdir -m 0700 -p "$out_dir"
	mkdir -m 0700 -p "$out_dir/config/AdGuardHome"
	mkdir -m 0700 -p "$out_dir/config/unbound/unbound.conf.d"
	mkdir -m 0700 -p "$out_dir/config/garnet/data"
	mkdir -m 0700 -p "$out_dir/config/garnet/checkpoints"
	mkdir -m 0700 -p "$out_dir/config/userfilters"

	log 'directory structure created successfully'
}

# ============================================================================
# Download Functions
# ============================================================================

# Function download_curl uses curl(1) to download a file.
download_curl() {
	if [ -z "${2:-}" ]; then
		curl -L -S -s "$1"
	else
		curl -L -S -o "$2" -s "$1"
	fi
}

# Function download_wget uses wget(1) to download a file.
download_wget() {
	local output_flag="${2:--}"
	wget --no-verbose -O "$output_flag" "$1"
}

# Function download_fetch uses fetch(1) to download a file (BSD).
download_fetch() {
	if [ -z "${2:-}" ]; then
		fetch -o '-' "$1"
	else
		fetch -o "$2" "$1"
	fi
}

# Function set_download_func sets the appropriate function for downloading files.
set_download_func() {
	if is_command 'curl'; then
		download_func='download_curl'
	elif is_command 'wget'; then
		download_func='download_wget'
	elif is_command 'fetch'; then
		download_func='download_fetch'
	else
		error_exit 'curl, wget, or fetch is required to download files'
	fi

	log "using $download_func for downloads"
}

# ============================================================================
# File Download & Setup
# ============================================================================

# Function download_files downloads all necessary files from GitHub.
download_files() {
	log 'downloading project files from GitHub'

	local files='
		Dockerfile
		docker-compose.yml
		entrypoint.sh
		README.md
		.gitignore
		.env.example
		config/AdGuardHome/AdGuardHome.yaml
		config/garnet/redis.conf
		config/unbound/unbound.conf
		config/unbound/unbound.conf.d/cache.conf
		config/unbound/unbound.conf.d/dnssec.conf
		config/unbound/unbound.conf.d/forward-queries.conf
	'

	for file in $files; do
		# Skip empty lines
		[ -z "$file" ] && continue

		local target="$out_dir/$file"
		local target_dir
		target_dir="$(dirname "$target")"

		# Create parent directories if needed
		if [ ! -d "$target_dir" ]; then
			mkdir -m 0700 -p "$target_dir"
		fi

		log "downloading: $file"

		if ! "$download_func" "${REPO_RAW}/${file}" "$target"; then
			error_exit "failed to download $file"
		fi
	done

	# Make entrypoint executable
	if [ -f "$out_dir/entrypoint.sh" ]; then
		chmod +x "$out_dir/entrypoint.sh"
		log 'set entrypoint.sh executable'
	fi

	log 'all files downloaded successfully'
}

# Function create_env_file creates the .env configuration if it doesn't exist.
create_env_file() {
	if [ -f "$out_dir/.env" ]; then
		log '.env already exists, skipping creation'
		return 0
	fi

	log 'creating .env configuration file'

	cat >"$out_dir/.env" <<'EOF'
# ============================================================================
# Garnet Cache Configuration
# ============================================================================
# Adjust these values based on your DNS cache requirements

# Total memory allocated to Garnet cache (128m, 256m, 512m, 1g, etc.)
GARNET_MEMORY_SIZE=128m

# Initial index hash table size (grows up to GARNET_INDEX_MAX_SIZE)
GARNET_INDEX_SIZE=16m

# Maximum index size before automatic LRU eviction
GARNET_INDEX_MAX_SIZE=64m

# ============================================================================
# Optional Security Settings
# ============================================================================

# Enable password authentication (uncomment to use)
# GARNET_PASSWORD=your-secure-password-here

# Enable TLS encryption (requires cert.pfx in config/garnet/)
# GARNET_TLS_ENABLED=false
EOF

	log '.env file created'
}

# ============================================================================
# Installation Management
# ============================================================================

# Function handle_existing detects existing installation and handles reinstall/uninstall.
handle_existing() {
	if [ ! -d "$out_dir" ]; then
		log 'no existing installation detected'

		if [ "$uninstall" -eq '1' ]; then
			log 'nothing to uninstall'
			exit 0
		fi

		return 0
	fi

	# Check if it looks like our installation
	if [ ! -f "$out_dir/docker-compose.yml" ]; then
		log "directory exists but doesn't appear to be our installation: $out_dir"
		return 0
	fi

	if [ "$uninstall" -eq '1' ]; then
		log 'uninstalling existing installation'
		log 'stopping Docker containers'

		if [ -f "$out_dir/docker-compose.yml" ]; then
			cd "$out_dir"
			docker compose down 2>/dev/null || log 'could not stop containers (may already be stopped)'
			cd - >/dev/null
		fi

		log 'removing installation directory'
		rm -rf "$out_dir"
		log 'uninstallation complete'
		exit 0
	fi

	if [ "$reinstall" -eq '0' ]; then
		error_exit "installation already exists at $out_dir. Use -r to reinstall or -d to specify a different directory"
	fi

	log 'reinstalling: removing existing installation'
	log 'stopping Docker containers'

	if [ -f "$out_dir/docker-compose.yml" ]; then
		cd "$out_dir"
		docker compose down 2>/dev/null || log 'could not stop containers'
		cd - >/dev/null
	fi

	rm -rf "$out_dir"
	log 'old installation removed'
}

# ============================================================================
# Build & Deploy
# ============================================================================

# Function build_image builds the Docker image.
build_image() {
	log 'building Docker image'
	
	cd "$out_dir"
	
	if ! docker build -t adguard-unbound-caching:latest . >/dev/null 2>&1; then
		error_exit 'failed to build Docker image'
	fi
	
	log 'Docker image built successfully'
	
	cd - >/dev/null
}

# Function start_services starts containers with docker compose.
start_services() {
	log 'starting Docker Compose services'
	
	cd "$out_dir"
	
	if ! docker compose up -d >/dev/null 2>&1; then
		error_exit 'failed to start services with docker compose'
	fi
	
	log 'services started'
	
	# Wait for services to be ready (30-60 seconds)
	log 'waiting for services to be ready (30-60 seconds)'
	sleep 5
	
	cd - >/dev/null
}

# ============================================================================
# Summary Output
# ============================================================================

show_summary() {
	cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Installation Complete and Running!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Installation directory: $out_dir

Services are now RUNNING:
  ✓ AdGuard Home      (Web UI + DNS)
  ✓ Unbound           (Recursive resolver)
  ✓ Garnet            (In-memory cache)

Access services immediately:

  Web UI:           http://localhost:3000
  Default user:     admin
  Default password: admin
    ⚠️  CHANGE PASSWORD IMMEDIATELY!

  DNS:              localhost:53 (TCP/UDP)

Test DNS resolution:
  nslookup google.com localhost
  dig @localhost google.com

Useful commands:

  View status:      docker compose -f $out_dir/docker-compose.yml ps
  View logs:        docker compose -f $out_dir/docker-compose.yml logs -f
  Stop services:    docker compose -f $out_dir/docker-compose.yml down
  Restart:          docker compose -f $out_dir/docker-compose.yml restart
  Remove all data:  docker compose -f $out_dir/docker-compose.yml down -v

Configuration files:

  • Environment:    $out_dir/.env          (edit for memory/auth settings)
  • Docker compose: $out_dir/docker-compose.yml
  • Dockerfile:     $out_dir/Dockerfile
  • README:         $out_dir/README.md

Documentation:

  • Project:     $REPO_URL
  • Garnet:      https://microsoft.github.io/garnet/
  • Unbound:     https://unbound.docs.nlnetlabs.nl/
  • AdGuard:     https://adguard.com/en/adguard-home/overview.html

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
}

# ============================================================================
# Main Entrypoint
# ============================================================================

main() {
	echo 'starting AdGuard Home + Unbound + Garnet installation'

	# Parse command-line arguments
	parse_opts "$@"

	# Check prerequisites
	check_required

	# Setup configuration
	set_download_func
	check_out_dir

	# Handle uninstall
	if [ "$uninstall" -eq '1' ]; then
		handle_existing
		echo 'uninstallation complete'
		exit 0
	fi

	# Handle existing installation
	handle_existing

	# Create directories
	setup_directories

	# Download files
	download_files

	# Create configuration
	create_env_file

	# Build Docker image
	build_image

	# Start services
	start_services

	# Show summary
	show_summary
}

# Run main entrypoint with all original arguments
main "$@"
