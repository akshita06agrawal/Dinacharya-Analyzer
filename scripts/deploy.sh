#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Dinacharya Analyzer — Deployment Script
# Usage: ./scripts/deploy.sh [environment]
# Example: ./scripts/deploy.sh production
# ════════════════════════════════════════════════════════════════

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ── Config ────────────────────────────────────────────────────────
APP_NAME="dinacharya-analyzer"
ENVIRONMENT="${1:-production}"
DOCKER_IMAGE="your-dockerhub-username/${APP_NAME}"
VERSION=$(git rev-parse --short HEAD)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Helper functions ──────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────
preflight_checks() {
  log_info "Running pre-flight checks..."

  command -v docker >/dev/null 2>&1 || log_error "Docker not installed"
  command -v git    >/dev/null 2>&1 || log_error "Git not installed"

  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    log_error "ANTHROPIC_API_KEY environment variable not set"
  fi

  log_success "All pre-flight checks passed"
}

# ── Run Tests ─────────────────────────────────────────────────────
run_tests() {
  log_info "Running test suite..."
  npm test || log_error "Tests failed! Aborting deployment."
  log_success "All tests passed"
}

# ── Build Docker Image ────────────────────────────────────────────
build_image() {
  log_info "Building Docker image: ${DOCKER_IMAGE}:${VERSION}"
  docker build \
    --build-arg APP_VERSION="${VERSION}" \
    --build-arg BUILD_DATE="${TIMESTAMP}" \
    -t "${DOCKER_IMAGE}:${VERSION}" \
    -t "${DOCKER_IMAGE}:latest" \
    . || log_error "Docker build failed"
  log_success "Docker image built: ${DOCKER_IMAGE}:${VERSION}"
}

# ── Push to Registry ──────────────────────────────────────────────
push_image() {
  log_info "Pushing to Docker Hub..."
  docker push "${DOCKER_IMAGE}:${VERSION}"
  docker push "${DOCKER_IMAGE}:latest"
  log_success "Image pushed to registry"
}

# ── Deploy ────────────────────────────────────────────────────────
deploy() {
  log_info "Deploying to ${ENVIRONMENT}..."

  if [[ "${ENVIRONMENT}" == "production" ]]; then
    # Zero-downtime deployment with Docker Compose
    docker compose pull
    docker compose up -d --no-deps --build app
    log_success "Production deployment complete"

  elif [[ "${ENVIRONMENT}" == "staging" ]]; then
    docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
    log_success "Staging deployment complete"

  else
    log_error "Unknown environment: ${ENVIRONMENT}"
  fi
}

# ── Health Check ──────────────────────────────────────────────────
health_check() {
  log_info "Waiting for app to be healthy..."
  local max_attempts=30
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
      log_success "App is healthy!"
      return 0
    fi
    attempt=$((attempt + 1))
    log_info "Attempt ${attempt}/${max_attempts} — waiting..."
    sleep 2
  done

  log_error "App failed health check after ${max_attempts} attempts"
}

# ── Rollback ──────────────────────────────────────────────────────
rollback() {
  log_warn "Rolling back to previous version..."
  docker compose down
  docker pull "${DOCKER_IMAGE}:previous" && \
    docker tag "${DOCKER_IMAGE}:previous" "${DOCKER_IMAGE}:latest" && \
    docker compose up -d
  log_info "Rollback complete. Check logs: docker compose logs -f"
}

# ── Main ──────────────────────────────────────────────────────────
main() {
  echo ""
  echo "════════════════════════════════════════════"
  echo "  Dinacharya Analyzer — Deployment Script"
  echo "  Environment: ${ENVIRONMENT}"
  echo "  Version:     ${VERSION}"
  echo "  Time:        ${TIMESTAMP}"
  echo "════════════════════════════════════════════"
  echo ""

  preflight_checks
  run_tests
  build_image
  push_image
  deploy
  health_check

  echo ""
  echo "════════════════════════════════════════════"
  log_success "Deployment successful!"
  echo "  App URL: http://localhost:3000"
  echo "  Metrics: http://localhost:9090"
  echo "  Grafana: http://localhost:3001"
  echo "════════════════════════════════════════════"
  echo ""
}

# Handle --rollback flag
if [[ "${1:-}" == "--rollback" ]]; then
  rollback
else
  main
fi
