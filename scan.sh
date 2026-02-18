#!/bin/bash
# ============================================================
# scan.sh — Runs the Quality Scanner against any project
#
# Usage:
#   ./scan.sh /path/to/your/project
#   ./scan.sh .                          (current directory)
#   ./scan.sh ~/projects/my-backend
#
# The container uses its own centralized configs (ESLint, Prettier, etc.)
# and ignores any local config files in the target project.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load variables from .env
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

PROJECT_PATH="${1:-.}"

# Resolve absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "Error: Directory '$1' not found."
  exit 1
}

# Check if it is a Node.js project
if [ ! -f "$PROJECT_PATH/package.json" ]; then
  echo "Error: package.json not found in $PROJECT_PATH"
  echo "Make sure you are pointing to the root of a Node.js/NestJS project."
  exit 1
fi

PROJECT_NAME=$(node -e "console.log(require('$PROJECT_PATH/package.json').name || 'unknown')" 2>/dev/null || echo "unknown")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Quality Scanner                                     ║"
echo "║  Project: $PROJECT_NAME"
echo "║  Path:    $PROJECT_PATH"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Variables with defaults from .env
SCANNER_IMG="${SCANNER_IMAGE:-quality-scanner:latest}"
SONAR_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_ADM_USER="${SONAR_ADMIN_USER:-admin}"
SONAR_ADM_PASS="${SONAR_ADMIN_PASSWORD:-admin}"
REPORTS="${REPORTS_DIR:-./reports}"
REPORTS="${REPORTS#./}"
DASH_PORT="${DASHBOARD_PORT:-3000}"

# Ensure SonarQube + Scanner images are built
echo "Checking containers..."
cd "$SCRIPT_DIR"

# Build scanner image if needed
if ! docker image inspect "${SCANNER_IMG}" &>/dev/null; then
  echo "Building scanner image (first time)..."
  docker build -t "${SCANNER_IMG}" ./scanner/
fi

# Start SonarQube if not running
if ! curl -s "${SONAR_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
  echo "Starting SonarQube..."
  docker compose up -d sonarqube db
  echo "Waiting for SonarQube to start..."
  for i in $(seq 1 60); do
    if curl -s "${SONAR_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
      echo "SonarQube is UP!"
      break
    fi
    if [ $i -eq 60 ]; then
      echo "Timeout: SonarQube did not start within 5 minutes."
      echo "Continuing without SonarQube..."
    fi
    sleep 5
  done
fi

# Generate token if not set
if [ -z "$SONAR_TOKEN" ]; then
  echo "Generating SonarQube token..."
  TOKEN_RESPONSE=$(curl -s -u "${SONAR_ADM_USER}:${SONAR_ADM_PASS}" -X POST "${SONAR_URL}/api/user_tokens/generate?name=scanner-$(date +%s)" 2>/dev/null || true)
  SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)
fi

# Create project in SonarQube if it does not exist
curl -s -u "${SONAR_ADM_USER}:${SONAR_ADM_PASS}" -X POST "${SONAR_URL}/api/projects/create?name=${PROJECT_NAME}&project=${PROJECT_NAME}" 2>/dev/null || true

# Create reports directory
mkdir -p "$SCRIPT_DIR/${REPORTS}"

# Run the scanner via docker compose
echo ""
echo "Starting analysis..."
echo ""

PROJECT_PATH="$PROJECT_PATH" \
SONAR_PROJECT_KEY="${PROJECT_NAME}" \
SONAR_TOKEN="${SONAR_TOKEN}" \
docker compose --profile scan run --rm scanner

# Find the most recent report
LATEST_REPORT=$(find "$SCRIPT_DIR/${REPORTS}" -name "summary.json" -type f 2>/dev/null | sort -r | head -1)

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  SonarQube:  ${SONAR_URL}/dashboard?id=${PROJECT_NAME}"
if [ -n "$LATEST_REPORT" ]; then
  REPORT_DIR=$(dirname "$LATEST_REPORT")
  echo "  Reports:    ${REPORT_DIR}"
  echo "  Dashboard:  http://localhost:${DASH_PORT}"
fi
echo "═══════════════════════════════════════════════════════"
echo ""
