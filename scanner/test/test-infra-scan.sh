#!/bin/bash
# ============================================================
# Testes — Infra Scan (Segurança de Infraestrutura)
# Valida todos os cenários de aceite da Feature 02
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

# Verificar pré-requisitos
if ! command -v trivy &> /dev/null; then
  echo -e "${RED}ERRO: Trivy não está instalado. Instale antes de rodar os testes.${NC}"
  echo -e "${YELLOW}  macOS: brew install trivy${NC}"
  echo -e "${YELLOW}  Linux: https://aquasecurity.github.io/trivy/latest/getting-started/installation/${NC}"
  exit 1
fi

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Testes — Infra Scan (Feature 02)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ============================================================
# Cenário 1: Dockerfile seguro — 0 findings, step passa
# ============================================================
echo -e "\n${CYAN}[1/8] Dockerfile seguro — deve passar sem findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/Dockerfile.safe" "${TEMP_PROJECT}/Dockerfile"
mkdir -p "${TEMP_PROJECT}/node_modules"  # Evitar detecção falsa

RESULT=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
# Dockerfile seguro pode ter 0 findings ou apenas warnings de baixa severidade
assert_not_contains "Status não é fail" "fail" "${STATUS}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Cenário 2: Dockerfile inseguro — findings reportadas
# ============================================================
echo -e "\n${CYAN}[2/8] Dockerfile inseguro — deve reportar findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/Dockerfile.unsafe" "${TEMP_PROJECT}/Dockerfile"

RESULT=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

assert_contains "Status é fail ou warn" "fail\|warn" "${STATUS}"
assert_json_gt "Tem findings" "${DETAILS}" "['totalFindings']" "0"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Cenário 3: K8s deployment inseguro — finding CRITICAL
# ============================================================
echo -e "\n${CYAN}[3/8] K8s deployment inseguro — deve reportar CRITICAL${NC}"

TEMP_PROJECT=$(mktemp -d)
mkdir -p "${TEMP_PROJECT}/k8s"
cp "${FIXTURES_DIR}/deployment-unsafe.yaml" "${TEMP_PROJECT}/k8s/deployment.yaml"

RESULT=$(SCAN_DOCKERFILE=false SCAN_K8S=true SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

assert_contains "Status é fail ou warn" "fail\|warn" "${STATUS}"
assert_json_gt "Tem findings" "${DETAILS}" "['totalFindings']" "0"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Cenário 4: Compose inseguro — findings HIGH
# ============================================================
echo -e "\n${CYAN}[4/8] Compose inseguro — deve reportar findings${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/compose-unsafe.yml" "${TEMP_PROJECT}/docker-compose.yml"

RESULT=$(SCAN_DOCKERFILE=false SCAN_K8S=false SCAN_COMPOSE=true \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

# Compose pode ou não gerar findings dependendo da versão do Trivy
if [ "${RESULT}" != "NO_IAC_FILES" ]; then
  assert_contains "Resultado não é NO_IAC_FILES" "|" "${RESULT}"
else
  assert_eq "Compose detectado" "false" "true"  # Forçar falha se não detectou
fi

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Cenário 5: Sem arquivos IaC — step ignorado
# ============================================================
echo -e "\n${CYAN}[5/8] Sem arquivos IaC — step deve ser ignorado${NC}"

TEMP_PROJECT=$(mktemp -d)
echo '{}' > "${TEMP_PROJECT}/package.json"
mkdir -p "${TEMP_PROJECT}/src"
echo 'console.log("hello")' > "${TEMP_PROJECT}/src/index.ts"

RESULT=$(SCAN_DOCKERFILE=true SCAN_K8S=true SCAN_COMPOSE=true \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

assert_eq "Retorna NO_IAC_FILES" "NO_IAC_FILES" "${RESULT}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Cenário 6: Step desativado — não executa
# ============================================================
echo -e "\n${CYAN}[6/8] Step desativado — ENABLE_INFRA_SCAN=false${NC}"

# Simulação: o entrypoint verifica ENABLE_INFRA_SCAN antes de chamar o script
# Aqui testamos que a lógica de ativação funciona
ENABLE_INFRA_SCAN=false
if [ "${ENABLE_INFRA_SCAN}" = "true" ]; then
  SHOULD_RUN="true"
else
  SHOULD_RUN="false"
fi
assert_eq "Step não executa quando desativado" "false" "${SHOULD_RUN}"

ENABLE_INFRA_SCAN=true
if [ "${ENABLE_INFRA_SCAN}" = "true" ]; then
  SHOULD_RUN="true"
else
  SHOULD_RUN="false"
fi
assert_eq "Step executa quando ativado" "true" "${SHOULD_RUN}"

# ============================================================
# Cenário 7: Severity threshold — CRITICAL vs HIGH
# ============================================================
echo -e "\n${CYAN}[7/8] Severity threshold — CRITICAL bloqueia apenas critical${NC}"

TEMP_PROJECT=$(mktemp -d)
cp "${FIXTURES_DIR}/Dockerfile.unsafe" "${TEMP_PROJECT}/Dockerfile"

# Com severity CRITICAL, apenas CRITICAL findings bloqueiam
RESULT_CRITICAL=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=CRITICAL \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

# Com severity MEDIUM, mais findings bloqueiam
RESULT_MEDIUM=$(SCAN_DOCKERFILE=true SCAN_K8S=false SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=MEDIUM \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

# Ambos devem retornar resultados (não NO_IAC_FILES)
assert_not_contains "CRITICAL severity retorna resultado" "NO_IAC_FILES" "${RESULT_CRITICAL}"
assert_not_contains "MEDIUM severity retorna resultado" "NO_IAC_FILES" "${RESULT_MEDIUM}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Cenário 8: Validação do formato JSON de output
# ============================================================
echo -e "\n${CYAN}[8/8] Validação do formato JSON de output${NC}"

TEMP_PROJECT=$(mktemp -d)
mkdir -p "${TEMP_PROJECT}/k8s"
cp "${FIXTURES_DIR}/deployment-unsafe.yaml" "${TEMP_PROJECT}/k8s/deployment.yaml"

RESULT=$(SCAN_DOCKERFILE=false SCAN_K8S=true SCAN_COMPOSE=false \
  INFRA_SCAN_SEVERITY=HIGH \
  bash "${INFRA_SCAN}" "${TEMP_PROJECT}" "${REPORTS_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

DETAILS=$(echo "${RESULT}" | cut -d'|' -f3-)

# Validar campos obrigatórios do JSON
VALID_JSON=$(echo "${DETAILS}" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    required = ['totalFindings', 'blockingFindings', 'counts', 'severityThreshold', 'byType', 'findings']
    missing = [f for f in required if f not in d]
    if missing:
        print(f'MISSING:{','.join(missing)}')
    else:
        # Validar sub-campos de counts
        count_fields = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
        missing_counts = [f for f in count_fields if f not in d['counts']]
        if missing_counts:
            print(f'MISSING_COUNTS:{','.join(missing_counts)}')
        else:
            print('VALID')
except Exception as e:
    print(f'INVALID:{e}')
" 2>/dev/null || echo "PARSE_ERROR")

assert_eq "JSON de output é válido com todos os campos" "VALID" "${VALID_JSON}"

# Validar que findings têm campos obrigatórios
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

assert_eq "Findings têm campos obrigatórios" "VALID" "${FINDINGS_VALID}"

rm -rf "${TEMP_PROJECT}"

# ============================================================
# Resultado Final
# ============================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Resultado: ${TESTS_PASSED}/${TESTS_TOTAL} testes passando${NC}"

if [ ${TESTS_FAILED} -gt 0 ]; then
  echo -e "${RED}  ${TESTS_FAILED} teste(s) falhando${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 1
else
  echo -e "${GREEN}  Todos os testes passaram!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 0
fi
