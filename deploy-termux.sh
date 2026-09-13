#!/bin/bash

# DevOps Automation - Termux Deployment Script
# Usage: ./deploy-termux.sh [action]\n# Actions: install, start, stop, logs, status, clean

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ACTION="${1:-start}"
APP_PORT=3000
APP_PID_FILE="./app.pid"
LOG_FILE="./logs/termux-$(date +%Y%m%d_%H%M%S).log"

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

# Check if Node.js is installed
check_nodejs() {
  if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed"
    log "Install with: pkg install nodejs"
    exit 1
  fi
  log_success "Node.js $(node -v) found"
}

# Install dependencies
install_deps() {
  log "Installing Node.js dependencies..."
  
  # Check if package.json exists
  if [ ! -f "package.json" ]; then
    log_warning "package.json not found. Creating minimal setup..."
    cat > package.json << 'EOF'
{
  "name": "devops-automation",
  "version": "1.0.0",
  "description": "DevOps Automation App",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "sqlite3": "^5.1.6"
  }
}
EOF
    log_success "package.json created"
  fi
  
  # Create minimal server.js if not exists
  if [ ! -f "server.js" ]; then
    log_warning "server.js not found. Creating minimal Express app..."
    cat > server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date() });
});

app.get('/', (req, res) => {
  res.json({ message: 'DevOps Automation API', version: '1.0.0' });
});

app.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Server running on http://localhost:${PORT}`);
});
EOF
    log_success "server.js created"
  fi
  
  npm install
  log_success "Dependencies installed"
}

# Start application
start_app() {
  log "Starting application..."
  
  # Check if already running
  if [ -f "$APP_PID_FILE" ]; then
    local OLD_PID=$(cat "$APP_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
      log_warning "App already running with PID $OLD_PID"
      return
    fi
  fi
  
  # Start app in background
  nohup npm start > logs/app.log 2>&1 &
  local NEW_PID=$!
  echo $NEW_PID > "$APP_PID_FILE"
  
  log_success "App started with PID $NEW_PID"
  log "App running on http://localhost:$APP_PORT"
  
  sleep 2
  health_check
}

# Stop application
stop_app() {
  log "Stopping application..."
  
  if [ -f "$APP_PID_FILE" ]; then
    local PID=$(cat "$APP_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill $PID
      rm -f "$APP_PID_FILE"
      log_success "App stopped"
    else
      log_warning "Process not running, cleaning up PID file"
      rm -f "$APP_PID_FILE"
    fi
  else
    log_warning "No PID file found, app may not be running"
  fi
}

# Show logs
show_logs() {
  log "Displaying application logs..."
  tail -f logs/app.log
}

# Show status
show_status() {
  log "Application status:"
  
  if [ -f "$APP_PID_FILE" ]; then
    local PID=$(cat "$APP_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      log_success "App is running (PID: $PID)"
      ps -p $PID
    else
      log_error "App is not running (stale PID file)"
    fi
  else
    log_error "App is not running"
  fi
}

# Health check
health_check() {
  log "Running health check..."
  
  for i in {1..10}; do
    if curl -s http://localhost:$APP_PORT/health > /dev/null 2>&1; then
      log_success "App is healthy"
      curl -s http://localhost:$APP_PORT/health | head -c 100
      echo
      return 0
    fi
    if [ $i -lt 10 ]; then
      sleep 1
    fi
  done
  
  log_error "App health check failed"
  return 1
}

# Clean up
clean() {
  log "Cleaning up..."
  stop_app
  rm -rf node_modules
  rm -f package-lock.json
  log_success "Cleanup completed"
}

# Main execution
main() {
  log "========================================"
  log "DevOps Automation - Termux Deployment"
  log "========================================"
  
  check_nodejs
  
  case $ACTION in
    install)
      install_deps
      ;;
    start)
      start_app
      ;;
    stop)
      stop_app
      ;;
    restart)
      stop_app
      sleep 1
      start_app
      ;;
    logs)
      show_logs
      ;;
    status)
      show_status
      ;;
    health)
      health_check
      ;;
    clean)
      clean
      ;;
    *)
      log_error "Invalid action: $ACTION"
      echo "Supported actions: install, start, stop, restart, logs, status, health, clean"
      exit 1
      ;;
  esac
  
  log "========================================"
  log_success "Done"
  log "========================================"
}

main
