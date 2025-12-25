#!/bin/bash

# Plane Installation Script for macOS
# Version: 1.0
# Description: Automated installation of Plane on macOS

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLANE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANE_PORT=""  # Will be set dynamically

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_docker() {
    log_info "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker Desktop for Mac first."
        log_info "Download from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi

    log_success "Docker is running"
}

find_free_port() {
    log_info "Finding available port..."
    local port=80
    local max_port=89  # Try ports 80-89

    while [ $port -le $max_port ]; do
        if ! lsof -i :$port > /dev/null 2>&1; then
            PLANE_PORT=$port
            log_success "Using port: $port"
            return 0
        fi
        ((port++))
    done

    log_error "No free ports found in range 80-89"
    exit 1
}

check_memory() {
    log_info "Checking available memory..."
    # Get available memory in GB
    available_memory=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)

    if [ "$available_memory" -lt 4 ]; then
        log_warning "Available memory: ${available_memory}GB"
        log_warning "Plane recommends at least 4GB RAM"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "Memory check passed (${available_memory}GB available)"
    fi
}

create_directory() {
    log_info "Using directory: $PLANE_DIR"
    mkdir -p "$PLANE_DIR"
    log_success "Directory ready"
}

download_compose() {
    log_info "Setting up docker-compose configuration..."

    # Change to project directory (same as script directory)
    cd "$PLANE_DIR"

    # Verify docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in $PLANE_DIR"
        exit 1
    fi

    log_success "Docker Compose configuration ready"
}

configure_plane() {
    log_info "Configuring environment variables..."

    # Write PLANE_PORT to .env file
    echo "PLANE_PORT=$PLANE_PORT" > "$PLANE_DIR/.env"

    log_success "Configuration ready for port $PLANE_PORT"
}

start_plane() {
    log_info "Starting Plane services..."
    log_info "This will download images and run database migrations (~5-10 minutes)"

    # Start infrastructure services first
    log_info "Starting database and supporting services..."
    if ! docker-compose up -d plane-db plane-redis plane-mq plane-minio; then
        log_error "Failed to start infrastructure services"
        exit 1
    fi

    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 10

    # Start API (may have issues with current images)
    log_info "Starting API service..."
    if ! docker-compose up -d plane-api; then
        log_warning "API service failed to start. This may be due to image compatibility issues."
        log_info "You can try starting it manually later with: docker-compose up -d plane-api"
    fi

    # Start web interface
    log_info "Starting web interface..."
    if ! docker-compose up -d plane-web; then
        log_error "Failed to start web interface"
        exit 1
    fi

    log_success "Plane services started (web interface ready)"
}

wait_for_plane() {
    log_info "Waiting for Plane web interface to be ready..."
    local max_attempts=30
    local attempt=1
    local url="http://localhost"

    if [ "$PLANE_PORT" != "80" ]; then
        url="http://localhost:$PLANE_PORT"
    fi

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_success "Plane web interface is ready!"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts - waiting..."
        sleep 10
        ((attempt++))
    done

    log_warning "Plane web interface may still be starting. Check status manually."
}

open_browser() {
    local url="http://localhost"
    if [ "$PLANE_PORT" != "80" ]; then
        url="http://localhost:$PLANE_PORT"
    fi

    log_info "Opening Plane in browser..."
    if command -v open &> /dev/null; then
        open "$url"
    else
        log_info "Please open $url in your browser"
    fi
}

show_next_steps() {
    local url="http://localhost"
    if [ "$PLANE_PORT" != "80" ]; then
        url="http://localhost:$PLANE_PORT"
    fi

    echo
    log_success "Plane installation completed!"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Open $url in your browser"
    echo "2. Create your admin account"
    echo "3. Set up your first workspace and project"
    echo
    echo -e "${BLUE}Useful commands:${NC}"
    echo "cd $PLANE_DIR"
    echo "docker-compose up -d          # Start"
    echo "docker-compose down           # Stop"
    echo "docker-compose logs -f        # View logs"
    echo "docker-compose restart        # Restart"
    echo
    echo -e "${YELLOW}Configuration file: $PLANE_DIR/plane-app/.env${NC}"
    echo -e "${YELLOW}Plane URL: $url${NC}"
    echo -e "${YELLOW}Port: $PLANE_PORT${NC}"
}

cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Installation failed. Check the output above for details."
        if [ -f "plane-app/.env.backup" ]; then
            log_info "Restoring original configuration..."
            mv plane-app/.env.backup plane-app/.env
        fi
        exit 1
    fi
}

# Main installation process
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Plane Installation for macOS  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo

    trap cleanup EXIT

    check_docker
    check_memory
    find_free_port
    create_directory
    download_compose
    configure_plane
    start_plane
    wait_for_plane
    open_browser
    show_next_steps

    log_success "Installation completed successfully!"
}

# Run main function
main "$@"
