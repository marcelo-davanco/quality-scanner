#!/bin/bash
set -e

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SonarQube Analysis - NestJS Project   ${NC}"
echo -e "${BLUE}========================================${NC}"

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-nestjs-project}"

# Check if SonarQube is running
echo -e "\n${YELLOW}[1/4] Checking if SonarQube is running...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0
until curl -s "${SONAR_HOST_URL}/api/system/status" | grep -q '"status":"UP"'; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo -e "${RED}✗ SonarQube is not responding. Run: docker compose up -d${NC}"
    exit 1
  fi
  echo -e "  Waiting for SonarQube to start... (${RETRY_COUNT}/${MAX_RETRIES})"
  sleep 5
done
echo -e "${GREEN}✓ SonarQube is running!${NC}"

# Install dependencies if needed
echo -e "\n${YELLOW}[2/4] Checking dependencies...${NC}"
if [ ! -d "node_modules" ]; then
  echo -e "  Installing dependencies..."
  npm install
fi

# Check if sonar-scanner is installed
if ! command -v sonar-scanner &> /dev/null && ! npx sonar-scanner --version &> /dev/null 2>&1; then
  echo -e "  Installing sonar-scanner..."
  npm install -D sonar-scanner
fi
echo -e "${GREEN}✓ Dependencies OK!${NC}"

# Run tests with coverage
echo -e "\n${YELLOW}[3/4] Running tests with coverage...${NC}"
npm run test:cov || {
  echo -e "${RED}✗ Tests failed! Check the errors above.${NC}"
  echo -e "${YELLOW}  Continuing analysis despite test failures...${NC}"
}
echo -e "${GREEN}✓ Tests executed!${NC}"

# Run SonarQube analysis
echo -e "\n${YELLOW}[4/4] Running SonarQube analysis...${NC}"

SONAR_ARGS="-Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.projectKey=${SONAR_PROJECT_KEY}"

if [ -n "${SONAR_TOKEN}" ]; then
  SONAR_ARGS="${SONAR_ARGS} -Dsonar.token=${SONAR_TOKEN}"
else
  echo -e "${YELLOW}  ⚠ SONAR_TOKEN not set. Using default login (admin/admin).${NC}"
  SONAR_ARGS="${SONAR_ARGS} -Dsonar.login=admin -Dsonar.password=admin"
fi

npx sonar-scanner ${SONAR_ARGS}

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Analysis completed successfully!    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${BLUE}Dashboard: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}${NC}\n"
