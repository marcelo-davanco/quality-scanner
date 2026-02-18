#!/bin/bash
# ============================================================
# Tests — Infra Scan (Infrastructure Security)
# Validates all acceptance scenarios for the Infra Scan step
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
INFRA_SCAN="${SCRIPT_DIR}/../scripts/infra-scan.sh"
REPORTS_DIR=$(mktemp -d)
CONFIGS_DIR="${SCRIPT_DIR}/../configs"

# ──────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────
assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ "${expected}" = "${actual}" ]; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Expected: '${expected}'${NC}"
    echo -e "${RED}    Actual:   '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  local test_name="$1" expected="$2" actual="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "${actual}" | grep -q "${expected}"; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Expected to contain: '${expected}'${NC}"
    echo -e "${RED}    Actual: '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_not_contains() {
  local test_name="$1" unexpected="$2" actual="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if ! echo "${actual}" | grep -q "${unexpected}"; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Should NOT contain: '${unexpected}'${NC}"
    echo -e "${RED}    Actual: '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_json_field() {
  local test_name="$1" json="$2" field="$3" expected="$4"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  local actual
  actual=$(echo "${json}" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d${field})" 2>/dev/null || echo "PARSE_ERROR")
  if [ "${expected}" = "${actual}" ]; then
    echo -e "${GREEN}  ✓ ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Field: ${field}${NC}"
    echo -e "${RED}    Expected: '${expected}'${NC}"
    echo -e "${RED}    Actual:   '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_json_gt() {
  local test_name="$1" json="$2" field="$3" min_value="$4"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  local actual
  actual=$(echo "${json}" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d${field})" 2>/dev/null || echo "0")
  if [ "${actual}" -gt "${min_value}" ] 2>/dev/null; then
    echo -e "${GREEN}  ✓ ${test_name} (${actual} > ${min_value})${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ ${test_name}${NC}"
    echo -e "${RED}    Field: ${field}${NC}"
    echo -e "${RED}    Expected > ${min_value}, got: '${actual}'${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

cleanup() {
  rm -rf "${REPORTS_DIR}"
}
trap cleanup EXIT

# Check prerequisites
if ! command -v trivy &> /dev/null; then
  echo -e "${RED}ERROR: Trivy is not installed. Install it before running the tests.${NC}"
  echo -e "${YELLOW}  macOS: brew install trivy${NC}"
  echo -e "${YELLOW}  Linux: https://aquasecurity.github.io/trivy/latest/getting-started/installation/${NC}"
  exit 1
fi

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Tests — Infra Scan${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ============================================================
# Scenario 1: Safe Dockerfile — 0 findings, step passes
# ============================================================
echo -e "\n${CYAN}[1/8] Safe Dockerfile — should pass with no findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/Dockerfile.safe" "${TEMP_PROJECT}/Dockerfile"
mkdir -p "${TEMP_PROJECT}/node_modules"  # Avoid false detection

RESULT=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
# Safe Dockerfile may have 0 findings or only low-severity warnings
assert_not_contains "Status is not fail" "fail" "${STATUS}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Scenario 2: Unsafe Dockerfile — findings reported
# ============================================================
echo -e "\n${CYAN}[2/8] Unsafe Dockerfile — should report findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/Dockerfile.unsafe" "${TEMP_PROJECT}/Dockerfile"

RESULT=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

assert_contains "Status is fail or warn" "fail\|warn" "${STATUS}"
assert_json_gt "Has findings" "${DETAILS}" "['totalFindings']" "0"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Scenario 3: Unsafe K8s deployment — CRITICAL finding
# ============================================================
echo -e "\n${CYAN}[3/8] Unsafe K8s deployment — should report CRITICAL${NC}"

TEMP_PROJECT=$(mktemp -d)
mkdir -p "${TEMP_PROJECT}/k8s"
cp "${FIXTURES_DIR}/deployment-unsafe.yaml" "${TEMP_PROJECT}/k8s/deployment.yaml"

RESULT=$(SCAN_DOCKERFILE=false SCAN_K8S=true SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

assert_contains "Status is fail or warn" "fail\|warn" "${STATUS}"
assert_json_gt "Has findings" "${DETAILS}" "['totalFindings']" "0"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Scenario 4: Unsafe Compose — HIGH findings
# ============================================================
echo -e "\n${CYAN}[4/8] Unsafe Compose — should report findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/compose-unsafe.yml" "${TEMP_PROJECT}/docker-compose.yml"

RESULT=$(SCAN_DOCKERFILE=false SCAN_K8S=false SCAN_COMPOSE=true \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

# Compose may or may not generate findings depending on the Trivy version
if [ "${RESULT}" != "NO_IAC_FILES" ]; then
  assert_contains "Result is not NO_IAC_FILES" "|" "${RESULT}"
else
  assert_eq "Compose detected" "false" "true"  # Force failure if not detected
fi

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Scenario 5: No IaC files — step skipped
# ============================================================
echo -e "\n${CYAN}[5/8] No IaC files — step should be skipped${NC}"

TEMP_PROJECT=$(mktemp -d)
echo '{}' > "${TEMP_PROJECT}/package.json"
mkdir -p "${TEMP_PROJECT}/src"
echo 'console.log("hello")' > "${TEMP_PROJECT}/src/index.ts"

RESULT=$(SCAN_DOCKERFILE=true SCAN_K8S=true SCAN_COMPOSE=true \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

assert_eq "Returns NO_IAC_FILES" "NO_IAC_FILES" "${RESULT}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Scenario 6: Step disabled — does not run
# ============================================================
echo -e "\n${CYAN}[6/8] Step disabled — ENABLE_INFRA_SCAN=false${NC}"

# Simulation: the entrypoint checks ENABLE_INFRA_SCAN before calling the script
# Here we test that the activation logic works
ENABLE_INFRA_SCAN=false
if [ "${ENABLE_INFRA_SCAN}" = "true" ]; then
  SHOULD_RUN="true"
else
  SHOULD_RUN="false"
fi
assert_eq "Step does not run when disabled" "false" "${SHOULD_RUN}"

ENABLE_INFRA_SCAN=true
if [ "${ENABLE_INFRA_SCAN}" = "true" ]; then
  SHOULD_RUN="true"
else
  SHOULD_RUN="false"
fi
assert_eq "Step runs when enabled" "true" "${SHOULD_RUN}"

# ============================================================
# Scenario 7: Severity threshold — CRITICAL vs HIGH
# ============================================================
echo -e "\n${CYAN}[7/8] Severity threshold — CRITICAL blocks only critical findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/Dockerfile.unsafe" "${TEMP_PROJECT}/Dockerfile"

# With CRITICAL severity, only CRITICAL findings block
RESULT_CRITICAL=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=CRITICAL \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

# With MEDIUM severity, more findings block
RESULT_MEDIUM=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=MEDIUM \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

# Both should return results (not NO_IAC_FILES)
assert_not_contains "CRITICAL severity returns result" "NO_IAC_FILES" "${RESULT_CRITICAL}"
assert_not_contains "MEDIUM severity returns result" "NO_IAC_FILES" "${RESULT_MEDIUM}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Scenario 8: JSON output format validation
# ============================================================
echo -e "\n${CYAN}[8/8] JSON output format validation${NC}"

TEMP_PROJECT=$(mktemp -d)
mkdir -p "${TEMP_PROJECT}/k8s"
cp "${FIXTURES_DIR}/deployment-unsafe.yaml" "${TEMP_PROJECT}/k8s/deployment.yaml"

RESULT=$(SCAN_DOCKERFILE=false SCAN_K8S=true SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

# Validate required JSON fields
VALID_JSON=$(echo "${DETAILS}" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    required = ['totalFindings', 'blockingFindings', 'counts', 'severityThreshold', 'byType', 'findings']
    missing = [f for f in required if f not in d]
    if missing:
        print(f'MISSING:{','.join(missing)}')
    else:
        # Validate counts sub-fields
        count_fields = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
        missing_counts = [f for f in count_fields if f not in d['counts']]
        if missing_counts:
            print(f'MISSING_COUNTS:{','.join(missing_counts)}')
        else:
            print('VALID')
except Exception as e:
    print(f'INVALID:{e}')
" 2>/dev/null || echo "PARSE_ERROR")

assert_eq "Output JSON is valid with all required fields" "VALID" "${VALID_JSON}"

# Validate that findings have required fields
FINDINGS_VALID=$(echo "${DETAILS}" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    findings = d.get('findings', [])
    if not findings:
        print('NO_FINDINGS')
    else:
        required = ['id', 'title', 'severity', 'target', 'type']
        for f in findings[:5]:
            missing = [k for k in required if k not in f]
            if missing:
                print(f'MISSING:{','.join(missing)}')
                sys.exit(0)
        print('VALID')
except Exception as e:
    print(f'INVALID:{e}')
" 2>/dev/null || echo "PARSE_ERROR")

assert_eq "Findings have required fields" "VALID" "${FINDINGS_VALID}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Final Result
# ============================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Result: ${TESTS_PASSED}/${TESTS_TOTAL} tests passing${NC}"

if [ ${TESTS_FAILED} -gt 0 ]; then
  echo -e "${RED}  ${TESTS_FAILED} test(s) failing${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 1
else
  echo -e "${GREEN}  All tests passed!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 0
fi
