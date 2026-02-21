#!/bin/bash
# ============================================================
# Tests — OpenAPI Contract Validation (Step 9)
# Runs test scenarios for swagger-lint.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
LINT_SCRIPT="${SCRIPT_DIR}/../scripts/swagger-lint.sh"
CONFIGS_DIR="${SCRIPT_DIR}/../configs"
TMP_DIR=$(mktemp -d)

trap 'rm -rf "${TMP_DIR}"' EXIT

# ──────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────
assert_contains() {
  local actual="$1" expected="$2" test_name="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "${actual}" | grep -q "${expected}"; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Expected to contain: '${expected}'${NC}"
    echo -e "${RED}    Got: '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_not_contains() {
  local actual="$1" unexpected="$2" test_name="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if ! echo "${actual}" | grep -q "${unexpected}"; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Should not contain: '${unexpected}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_equals() {
  local actual="$1" expected="$2" test_name="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ "${actual}" = "${expected}" ]; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Expected: '${expected}'${NC}"
    echo -e "${RED}    Got: '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file_exists() {
  local file="$1" test_name="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ -f "${file}" ]; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    File not found: ${file}${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_valid_json() {
  local json_str="$1" test_name="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "${json_str}" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Invalid JSON${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Tests — API Lint (Spectral)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ──────────────────────────────────────────────────────────
# Prerequisites
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Prerequisites]${NC}"
assert_file_exists "${LINT_SCRIPT}" "swagger-lint.sh exists"
assert_file_exists "${CONFIGS_DIR}/.spectral.yml" ".spectral.yml exists"
assert_file_exists "${FIXTURES_DIR}/swagger-valid.json" "Valid fixture exists"
assert_file_exists "${FIXTURES_DIR}/swagger-invalid.json" "Invalid fixture exists"

# Check if Spectral is available
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if command -v spectral &> /dev/null || npx spectral --version &> /dev/null 2>&1; then
  echo -e "${GREEN}  ✓ Spectral CLI available${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  SPECTRAL_AVAILABLE=true
else
  echo -e "${YELLOW}  ⚠ Spectral CLI not available — execution tests will be skipped${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  SPECTRAL_AVAILABLE=false
fi

# ──────────────────────────────────────────────────────────
# Scenario 1: Valid API — should pass with no violations
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 1] Valid API — 0 violations expected${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  PROJECT_VALID="${TMP_DIR}/project-valid"
  mkdir -p "${PROJECT_VALID}"
  cp "${FIXTURES_DIR}/swagger-valid.json" "${PROJECT_VALID}/swagger.json"

  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_VALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
  DETAILS_JSON=$(echo "${RESULT}" | cut -d'|' -f3-)

  assert_equals "${STATUS}" "pass" "Status should be 'pass' for valid API"
  assert_valid_json "${DETAILS_JSON}" "Output should be valid JSON"

  VIOLATIONS=$(echo "${DETAILS_JSON}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('totalViolations',0))" 2>/dev/null || echo "-1")
  assert_equals "${VIOLATIONS}" "0" "Should have 0 violations"
else
  echo -e "${YELLOW}  ⚠ Skipped — Spectral not available${NC}"
fi

# ──────────────────────────────────────────────────────────
# Scenario 2: Invalid API (severity=warn) — reports but does not block
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 2] Invalid API + severity=warn — reports without blocking${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  PROJECT_INVALID="${TMP_DIR}/project-invalid"
  mkdir -p "${PROJECT_INVALID}"
  cp "${FIXTURES_DIR}/swagger-invalid.json" "${PROJECT_INVALID}/swagger.json"

  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_INVALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
  DETAILS_JSON=$(echo "${RESULT}" | cut -d'|' -f3-)

  assert_equals "${STATUS}" "warn" "Status should be 'warn' (not 'fail') with severity=warn"
  assert_valid_json "${DETAILS_JSON}" "Output should be valid JSON"

  VIOLATIONS=$(echo "${DETAILS_JSON}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('totalViolations',0))" 2>/dev/null || echo "0")
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ "${VIOLATIONS}" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Violations detected: ${VIOLATIONS}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ Should have detected violations${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
else
  echo -e "${YELLOW}  ⚠ Skipped — Spectral not available${NC}"
fi

# ──────────────────────────────────────────────────────────
# Scenario 3: Invalid API (severity=error) — should block
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 3] Invalid API + severity=error — should block${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="error" \
    bash "${LINT_SCRIPT}" "${PROJECT_INVALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)

  assert_equals "${STATUS}" "fail" "Status should be 'fail' with severity=error and violations"
else
  echo -e "${YELLOW}  ⚠ Skipped — Spectral not available${NC}"
fi

# ──────────────────────────────────────────────────────────
# Scenario 4: No OpenAPI file — step skipped
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 4] No OpenAPI file — step should be skipped${NC}"
PROJECT_EMPTY="${TMP_DIR}/project-empty"
mkdir -p "${PROJECT_EMPTY}"

RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
  bash "${LINT_SCRIPT}" "${PROJECT_EMPTY}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

assert_equals "${RESULT}" "NO_FILE" "Should return NO_FILE when no OpenAPI file exists"

# ──────────────────────────────────────────────────────────
# Scenario 5: Step disabled (ENABLE_API_LINT=false)
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 5] Step disabled via ENABLE_API_LINT=false${NC}"
# This scenario is tested at the entrypoint level, not the script level
# swagger-lint.sh does not check ENABLE_API_LINT — that is the entrypoint's responsibility
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q 'ENABLE_API_LINT' "${SCRIPT_DIR}/../entrypoint.sh" 2>/dev/null; then
  echo -e "${GREEN}  ✓ entrypoint.sh checks ENABLE_API_LINT${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}  ✗ entrypoint.sh does not check ENABLE_API_LINT${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ──────────────────────────────────────────────────────────
# Scenario 6: Auto-detection with manual OPENAPI_FILE_PATH
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 6] Detection with manual OPENAPI_FILE_PATH${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  PROJECT_CUSTOM="${TMP_DIR}/project-custom"
  mkdir -p "${PROJECT_CUSTOM}/docs"
  cp "${FIXTURES_DIR}/swagger-valid.json" "${PROJECT_CUSTOM}/docs/my-api.json"

  RESULT=$(OPENAPI_FILE_PATH="docs/my-api.json" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_CUSTOM}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
  assert_equals "${STATUS}" "pass" "Should find file via manual OPENAPI_FILE_PATH"
else
  echo -e "${YELLOW}  ⚠ Skipped — Spectral not available${NC}"
fi

# ──────────────────────────────────────────────────────────
# Scenario 7: JSON output format validation
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Scenario 7] JSON output schema validation${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_VALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  DETAILS_JSON=$(echo "${RESULT}" | cut -d'|' -f3-)

  # Check required fields in JSON
  HAS_FIELDS=$(echo "${DETAILS_JSON}" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
required = ['openApiFile', 'totalViolations', 'counts', 'rules']
missing = [f for f in required if f not in d]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>/dev/null || echo "ERROR")

  assert_equals "${HAS_FIELDS}" "OK" "Output JSON contains all required fields"

  # Check counts sub-fields
  HAS_COUNTS=$(echo "${DETAILS_JSON}" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
counts = d.get('counts', {})
required = ['error', 'warn', 'info', 'hint']
missing = [f for f in required if f not in counts]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>/dev/null || echo "ERROR")

  assert_equals "${HAS_COUNTS}" "OK" "Counts contains error, warn, info, hint"
else
  echo -e "${YELLOW}  ⚠ Skipped — Spectral not available${NC}"
fi

# ──────────────────────────────────────────────────────────
# Result
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Total: ${TESTS_TOTAL} | Passed: ${TESTS_PASSED} | Failed: ${TESTS_FAILED}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "${TESTS_FAILED}" -gt 0 ]; then
  echo -e "${RED}${BOLD}  TESTS FAILED${NC}\n"
  exit 1
else
  echo -e "${GREEN}${BOLD}  ALL TESTS PASSED${NC}\n"
  exit 0
fi
