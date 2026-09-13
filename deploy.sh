#!/bin/bash

# DevOps Automation - Deployment Script
# Usage: ./deploy.sh [environment] [action]
# Environments: dev, staging, production
# Actions: build, up, down, restart, logs, status, clean

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-dev}"
ACTION="${2:-up}"
DOCKER_COMPOSE_FILE="docker-compose.yml"
LOG_FILE="./logs/deployment-$(date +%Y%m%d_%H%M%S).log"

# Directories
mkdir -p logs

# Functions
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
  echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

# Validate environment
validate_environment() {
  case $ENVIRONMENT in
    dev|staging|production)
      log "Environment: $ENVIRONMENT"
      ;;
    *)
      log_error "Invalid environment: $ENVIRONMENT"
      echo "Supported environments: dev, staging, production"
      exit 1
      ;;
  esac
}

# Build Docker image
build() {
  log "Building Docker image..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache
  log_success "Docker image built successfully"
}

# Start services
up() {
  log "Starting services for $ENVIRONMENT environment..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
  log_success "Services started successfully"
  
  log "Waiting for services to be healthy..."
  sleep 5
  
  status
}

# Stop services
down() {
  log "Stopping services..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" down
  log_success "Services stopped successfully"
}

# Restart services
restart() {
  log "Restarting services..."
  down
  sleep 2
  up
}

# Show logs
show_logs() {
  log "Displaying logs..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f
}

# Show service status
status() {
  log "Service status:"
  docker-compose -f "$DOCKER_COMPOSE_FILE" ps
}

# Clean up
clean() {
  log "Cleaning up containers and volumes..."
  docker-compose -f "$DOCKER_COMPOSE_FILE" down -v
  log_warning "All containers and volumes have been removed"
}

# Health check
health_check() {
  log "Running health checks..."
  
  # Check app
  if curl -s http://localhost:3000/health > /dev/null; then
    log_success "App is healthy"
  else
    log_error "App health check failed"
  fi
  
  # Check postgres
  if docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
    log_success "PostgreSQL is healthy"
  else
    log_error "PostgreSQL health check failed"
  fi
  
  # Check redis
  if docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T redis redis-cli ping > /dev/null 2>&1; then
    log_success "Redis is healthy"
  else
    log_error "Redis health check failed"
  fi
}

# Main execution
main() {
  log "========================================"
  log "DevOps Automation - Deployment Script"
  log "========================================"
  
  validate_environment
  
  case $ACTION in
    build)
      build
      ;;
    up)
      up
      health_check
      ;;
    down)
      down
      ;;
    restart)
      restart
      health_check
      ;;
    logs)
      show_logs
      ;;
    status)
      status
      ;;
    clean)
      clean
      ;;
    health)
      health_check
      ;;
    *)
      log_error "Invalid action: $ACTION"
      echo "Supported actions: build, up, down, restart, logs, status, clean, health"
      exit 1
      ;;
  esac
  
  log "========================================"
  log_success "Deployment script completed"
  log "========================================"
}

main
