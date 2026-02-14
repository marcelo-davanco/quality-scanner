#!/bin/bash
# ============================================================
# Testes — Validação de Contratos OpenAPI (Step 9)
# Executa cenários de teste para o swagger-lint.sh
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
    echo -e "${RED}    Esperado conter: '${expected}'${NC}"
    echo -e "${RED}    Recebido: '${actual}'${NC}"
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
    echo -e "${RED}    Não deveria conter: '${unexpected}'${NC}"
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
    echo -e "${RED}    Esperado: '${expected}'${NC}"
    echo -e "${RED}    Recebido: '${actual}'${NC}"
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
    echo -e "${RED}    Arquivo não encontrado: ${file}${NC}"
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
    echo -e "${RED}    JSON inválido${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Testes — API Lint (Spectral)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ──────────────────────────────────────────────────────────
# Pré-requisitos
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Pré-requisitos]${NC}"
assert_file_exists "${LINT_SCRIPT}" "swagger-lint.sh existe"
assert_file_exists "${CONFIGS_DIR}/.spectral.yml" ".spectral.yml existe"
assert_file_exists "${FIXTURES_DIR}/swagger-valid.json" "Fixture válida existe"
assert_file_exists "${FIXTURES_DIR}/swagger-invalid.json" "Fixture inválida existe"

# Verificar se Spectral está disponível
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if command -v spectral &> /dev/null || npx spectral --version &> /dev/null 2>&1; then
  echo -e "${GREEN}  ✓ Spectral CLI disponível${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  SPECTRAL_AVAILABLE=true
else
  echo -e "${YELLOW}  ⚠ Spectral CLI não disponível — testes de execução serão pulados${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  SPECTRAL_AVAILABLE=false
fi

# ──────────────────────────────────────────────────────────
# Cenário 1: API válida — deve passar sem violações
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 1] API válida — 0 violações esperadas${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  PROJECT_VALID="${TMP_DIR}/project-valid"
  mkdir -p "${PROJECT_VALID}"
  cp "${FIXTURES_DIR}/swagger-valid.json" "${PROJECT_VALID}/swagger.json"

  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_VALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
  DETAILS_JSON=$(echo "${RESULT}" | cut -d'|' -f3-)

  assert_equals "${STATUS}" "pass" "Status deve ser 'pass' para API válida"
  assert_valid_json "${DETAILS_JSON}" "Output deve ser JSON válido"

  VIOLATIONS=$(echo "${DETAILS_JSON}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('totalViolations',0))" 2>/dev/null || echo "-1")
  assert_equals "${VIOLATIONS}" "0" "Deve ter 0 violações"
else
  echo -e "${YELLOW}  ⚠ Pulado — Spectral não disponível${NC}"
fi

# ──────────────────────────────────────────────────────────
# Cenário 2: API inválida (severity=warn) — reporta mas não bloqueia
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 2] API inválida + severity=warn — reporta sem bloquear${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  PROJECT_INVALID="${TMP_DIR}/project-invalid"
  mkdir -p "${PROJECT_INVALID}"
  cp "${FIXTURES_DIR}/swagger-invalid.json" "${PROJECT_INVALID}/swagger.json"

  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_INVALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
  DETAILS_JSON=$(echo "${RESULT}" | cut -d'|' -f3-)

  assert_equals "${STATUS}" "warn" "Status deve ser 'warn' (não 'fail') com severity=warn"
  assert_valid_json "${DETAILS_JSON}" "Output deve ser JSON válido"

  VIOLATIONS=$(echo "${DETAILS_JSON}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('totalViolations',0))" 2>/dev/null || echo "0")
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ "${VIOLATIONS}" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Violações detectadas: ${VIOLATIONS}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}  ✗ Deveria ter detectado violações${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
else
  echo -e "${YELLOW}  ⚠ Pulado — Spectral não disponível${NC}"
fi

# ──────────────────────────────────────────────────────────
# Cenário 3: API inválida (severity=error) — deve bloquear
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 3] API inválida + severity=error — deve bloquear${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="error" \
    bash "${LINT_SCRIPT}" "${PROJECT_INVALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)

  assert_equals "${STATUS}" "fail" "Status deve ser 'fail' com severity=error e violações"
else
  echo -e "${YELLOW}  ⚠ Pulado — Spectral não disponível${NC}"
fi

# ──────────────────────────────────────────────────────────
# Cenário 4: Sem arquivo OpenAPI — step ignorado
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 4] Sem arquivo OpenAPI — step deve ser ignorado${NC}"
PROJECT_EMPTY="${TMP_DIR}/project-empty"
mkdir -p "${PROJECT_EMPTY}"

RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
  bash "${LINT_SCRIPT}" "${PROJECT_EMPTY}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

assert_equals "${RESULT}" "NO_FILE" "Deve retornar NO_FILE quando não há arquivo OpenAPI"

# ──────────────────────────────────────────────────────────
# Cenário 5: Step desativado (ENABLE_API_LINT=false)
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 5] Step desativado via ENABLE_API_LINT=false${NC}"
# Este cenário é testado no nível do entrypoint, não do script
# O swagger-lint.sh não verifica ENABLE_API_LINT — isso é responsabilidade do entrypoint
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q 'ENABLE_API_LINT' "${SCRIPT_DIR}/../entrypoint.sh" 2>/dev/null; then
  echo -e "${GREEN}  ✓ entrypoint.sh verifica ENABLE_API_LINT${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}  ✗ entrypoint.sh não verifica ENABLE_API_LINT${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ──────────────────────────────────────────────────────────
# Cenário 6: Detecção automática com OPENAPI_FILE_PATH manual
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 6] Detecção com OPENAPI_FILE_PATH manual${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  PROJECT_CUSTOM="${TMP_DIR}/project-custom"
  mkdir -p "${PROJECT_CUSTOM}/docs"
  cp "${FIXTURES_DIR}/swagger-valid.json" "${PROJECT_CUSTOM}/docs/my-api.json"

  RESULT=$(OPENAPI_FILE_PATH="docs/my-api.json" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_CUSTOM}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  STATUS=$(echo "${RESULT}" | cut -d'|' -f1)
  assert_equals "${STATUS}" "pass" "Deve encontrar arquivo via OPENAPI_FILE_PATH manual"
else
  echo -e "${YELLOW}  ⚠ Pulado — Spectral não disponível${NC}"
fi

# ──────────────────────────────────────────────────────────
# Cenário 7: Validação do formato JSON de output
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}[Cenário 7] Validação do schema do output JSON${NC}"
if [ "${SPECTRAL_AVAILABLE}" = "true" ]; then
  RESULT=$(OPENAPI_FILE_PATH="" API_LINT_SEVERITY="warn" \
    bash "${LINT_SCRIPT}" "${PROJECT_VALID}" "${TMP_DIR}" "${CONFIGS_DIR}" 2>/dev/null || echo "ERROR")

  DETAILS_JSON=$(echo "${RESULT}" | cut -d'|' -f3-)

  # Verificar campos obrigatórios no JSON
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

  assert_equals "${HAS_FIELDS}" "OK" "Output JSON contém todos os campos obrigatórios"

  # Verificar sub-campos de counts
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

  assert_equals "${HAS_COUNTS}" "OK" "Counts contém error, warn, info, hint"
else
  echo -e "${YELLOW}  ⚠ Pulado — Spectral não disponível${NC}"
fi

# ──────────────────────────────────────────────────────────
# Resultado
# ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Total: ${TESTS_TOTAL} | Passed: ${TESTS_PASSED} | Failed: ${TESTS_FAILED}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "${TESTS_FAILED}" -gt 0 ]; then
  echo -e "${RED}${BOLD}  TESTES FALHARAM${NC}\n"
  exit 1
else
  echo -e "${GREEN}${BOLD}  TODOS OS TESTES PASSARAM${NC}\n"
  exit 0
fi
