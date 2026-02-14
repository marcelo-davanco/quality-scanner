#!/bin/bash
# ============================================================
# Quality Gate — Análise Local Pré-Push (9 steps)
# Pega os mesmos problemas que Copilot/Cursor bot e SonarQube
# ============================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ERRORS=0
WARNINGS=0
TOTAL_STEPS=11
START_TIME=$(date +%s)

step_pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
step_fail() { echo -e "${RED}  ✗ $1${NC}"; ERRORS=$((ERRORS + 1)); }
step_warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; WARNINGS=$((WARNINGS + 1)); }

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  Quality Gate — Análise Local Pré-Push (${TOTAL_STEPS} steps)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ============================================================
# [1/9] Gitleaks — Detecção de secrets
# ============================================================
echo -e "\n${CYAN}[1/${TOTAL_STEPS}] Gitleaks — Verificando secrets no código...${NC}"
if command -v gitleaks &> /dev/null; then
  GITLEAKS_OUTPUT=$(gitleaks detect --source . --no-git --quiet 2>&1 || true)
  GITLEAKS_EXIT=$?
  if [ $GITLEAKS_EXIT -eq 0 ]; then
    step_pass "Gitleaks: nenhum secret encontrado"
  else
    LEAKS_COUNT=$(echo "$GITLEAKS_OUTPUT" | grep -c "RuleID" 2>/dev/null || echo "?")
    step_fail "Gitleaks: ${LEAKS_COUNT} secret(s) encontrado(s)"
    echo "$GITLEAKS_OUTPUT" | head -20
  fi
else
  step_warn "Gitleaks não instalado — pulando"
  echo -e "${YELLOW}  Instale: brew install gitleaks${NC}"
fi

# ============================================================
# [2/9] TypeScript — Compilação
# ============================================================
echo -e "\n${CYAN}[2/${TOTAL_STEPS}] TypeScript — Verificando compilação...${NC}"
TSC_OUTPUT=$(npx tsc --noEmit 2>&1 || true)
TSC_ERRORS=$(echo "$TSC_OUTPUT" | grep -c "error TS" 2>/dev/null || echo "0")
if [ "$TSC_ERRORS" -eq 0 ]; then
  step_pass "TypeScript compila sem erros"
else
  step_fail "TypeScript: ${TSC_ERRORS} erro(s) de compilação"
  echo "$TSC_OUTPUT" | grep "error TS" | head -10
fi

# ============================================================
# [3/9] ESLint — Qualidade de código
# ============================================================
echo -e "\n${CYAN}[3/${TOTAL_STEPS}] ESLint — Verificando regras de qualidade...${NC}"
ESLINT_OUTPUT=$(npx eslint 'src/**/*.ts' --format compact 2>&1 || true)
ESLINT_ERRORS=$(echo "$ESLINT_OUTPUT" | grep -c "Error -" 2>/dev/null || echo "0")
ESLINT_WARNINGS=$(echo "$ESLINT_OUTPUT" | grep -c "Warning -" 2>/dev/null || echo "0")

if [ "$ESLINT_ERRORS" -gt 0 ]; then
  step_fail "ESLint: ${ESLINT_ERRORS} erro(s)"
  echo "$ESLINT_OUTPUT" | grep "Error -" | head -10
  echo -e "${YELLOW}  (mostrando primeiros 10)${NC}"
elif [ "$ESLINT_WARNINGS" -gt 0 ]; then
  step_warn "ESLint: ${ESLINT_WARNINGS} warning(s)"
else
  step_pass "ESLint: nenhum problema encontrado"
fi

# ============================================================
# [4/9] Prettier — Formatação
# ============================================================
echo -e "\n${CYAN}[4/${TOTAL_STEPS}] Prettier — Verificando formatação...${NC}"
PRETTIER_OUTPUT=$(npx prettier --check 'src/**/*.ts' 2>&1 || true)
if echo "$PRETTIER_OUTPUT" | grep -q "All matched files use Prettier code style"; then
  step_pass "Prettier: formatação OK"
else
  UNFORMATTED=$(echo "$PRETTIER_OUTPUT" | grep -c "\.ts$" 2>/dev/null || echo "0")
  step_fail "Prettier: ${UNFORMATTED} arquivo(s) mal formatado(s)"
  echo -e "${YELLOW}  Fix: npx prettier --write 'src/**/*.ts'${NC}"
fi

# ============================================================
# [5/9] npm audit — Vulnerabilidades em dependências
# ============================================================
echo -e "\n${CYAN}[5/${TOTAL_STEPS}] npm audit — Verificando dependências...${NC}"
AUDIT_OUTPUT=$(npm audit --production 2>&1 || true)
CRITICAL=$(echo "$AUDIT_OUTPUT" | grep -oi '[0-9]\+ critical' | grep -o '[0-9]\+' || echo "0")
HIGH=$(echo "$AUDIT_OUTPUT" | grep -oi '[0-9]\+ high' | grep -o '[0-9]\+' || echo "0")

if [ "$CRITICAL" -gt 0 ]; then
  step_fail "npm audit: ${CRITICAL} vulnerabilidade(s) CRITICAL"
  echo -e "${YELLOW}  Fix: npm audit fix${NC}"
elif [ "$HIGH" -gt 0 ]; then
  step_warn "npm audit: ${HIGH} vulnerabilidade(s) HIGH"
else
  step_pass "npm audit: sem vulnerabilidades críticas"
fi

# ============================================================
# [6/9] Knip — Código morto
# ============================================================
echo -e "\n${CYAN}[6/${TOTAL_STEPS}] Knip — Verificando código morto...${NC}"
if npx knip --version &> /dev/null 2>&1; then
  KNIP_OUTPUT=$(npx knip --no-progress 2>&1 || true)
  UNUSED_EXPORTS=$(echo "$KNIP_OUTPUT" | grep -c "Unused export" 2>/dev/null || echo "0")
  UNUSED_FILES=$(echo "$KNIP_OUTPUT" | grep -c "Unused file" 2>/dev/null || echo "0")
  UNUSED_DEPS=$(echo "$KNIP_OUTPUT" | grep -c "Unused depend" 2>/dev/null || echo "0")

  TOTAL_DEAD=$((UNUSED_EXPORTS + UNUSED_FILES + UNUSED_DEPS))
  if [ "$TOTAL_DEAD" -gt 0 ]; then
    step_warn "Knip: ${UNUSED_FILES} arquivo(s), ${UNUSED_EXPORTS} export(s), ${UNUSED_DEPS} dep(s) não utilizados"
    echo "$KNIP_OUTPUT" | head -15
  else
    step_pass "Knip: sem código morto detectado"
  fi
else
  step_warn "Knip não instalado — pulando"
  echo -e "${YELLOW}  Instale: npm install -D knip${NC}"
fi

# ============================================================
# [7/9] Jest — Testes + Cobertura
# ============================================================
echo -e "\n${CYAN}[7/${TOTAL_STEPS}] Jest — Executando testes com cobertura...${NC}"
JEST_OUTPUT=$(npx jest --coverage --silent 2>&1 || true)
JEST_EXIT=$?

if echo "$JEST_OUTPUT" | grep -q "Tests:.*failed"; then
  FAILED=$(echo "$JEST_OUTPUT" | grep -o '[0-9]\+ failed' | head -1)
  step_fail "Jest: ${FAILED}"
else
  step_pass "Testes: todos passando"
fi

# Mostrar resumo de cobertura
echo -e "${CYAN}  Cobertura:${NC}"
echo "$JEST_OUTPUT" | grep -E "(Statements|Branches|Functions|Lines)\s*:" | while read -r line; do
  echo -e "    $line"
done

# ============================================================
# [8/9] SonarQube (opcional — só roda se o container estiver UP)
# ============================================================
echo -e "\n${CYAN}[8/${TOTAL_STEPS}] SonarQube — Análise estática...${NC}"

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs 2>/dev/null)
fi

SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"

if curl -s "${SONAR_HOST_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
  SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-nestjs-project}"

  SONAR_ARGS="-Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.projectKey=${SONAR_PROJECT_KEY}"
  if [ -n "${SONAR_TOKEN}" ]; then
    SONAR_ARGS="${SONAR_ARGS} -Dsonar.token=${SONAR_TOKEN}"
  else
    SONAR_ARGS="${SONAR_ARGS} -Dsonar.login=admin -Dsonar.password=admin"
  fi

  npx sonarqube-scanner ${SONAR_ARGS} 2>&1 | tail -5

  sleep 5
  QG_STATUS=$(curl -s -u admin:admin "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ "$QG_STATUS" = "OK" ]; then
    step_pass "SonarQube Quality Gate: PASSED"
  elif [ "$QG_STATUS" = "ERROR" ]; then
    step_fail "SonarQube Quality Gate: FAILED"
    echo -e "${YELLOW}  Dashboard: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}${NC}"
  else
    step_warn "SonarQube Quality Gate: status '${QG_STATUS}'"
  fi
else
  step_warn "SonarQube não está rodando — pulando"
  echo -e "${YELLOW}  Ativar: docker compose up -d${NC}"
fi

# ============================================================
# [9/10] API Lint — Validação de Contrato OpenAPI (Spectral)
# ============================================================
echo -e "\n${CYAN}[9/${TOTAL_STEPS}] API Lint — Validação de contrato OpenAPI...${NC}"
if [ "${ENABLE_API_LINT:-false}" = "true" ]; then
  if command -v spectral &> /dev/null || npx spectral --version &> /dev/null 2>&1; then
    # Detectar arquivo OpenAPI
    OPENAPI_FILE="${OPENAPI_FILE_PATH:-}"
    if [ -z "${OPENAPI_FILE}" ]; then
      for candidate in swagger.json swagger.yaml swagger.yml openapi.json openapi.yaml openapi.yml docs/swagger.json docs/openapi.json dist/swagger.json; do
        if [ -f "${candidate}" ]; then
          OPENAPI_FILE="${candidate}"
          break
        fi
      done
    fi

    if [ -n "${OPENAPI_FILE}" ] && [ -f "${OPENAPI_FILE}" ]; then
      SPECTRAL_OUTPUT=$(npx spectral lint "${OPENAPI_FILE}" --format text 2>&1 || true)
      SPECTRAL_ERRORS=$(echo "${SPECTRAL_OUTPUT}" | grep -c "error" 2>/dev/null || echo "0")
      SPECTRAL_WARNINGS=$(echo "${SPECTRAL_OUTPUT}" | grep -c "warning" 2>/dev/null || echo "0")

      if [ "${SPECTRAL_ERRORS:-0}" -gt 0 ]; then
        if [ "${API_LINT_SEVERITY:-warn}" = "error" ]; then
          step_fail "API Lint: ${SPECTRAL_ERRORS} erro(s), ${SPECTRAL_WARNINGS} warning(s)"
        else
          step_warn "API Lint: ${SPECTRAL_ERRORS} erro(s), ${SPECTRAL_WARNINGS} warning(s)"
        fi
        echo "${SPECTRAL_OUTPUT}" | head -20
      elif [ "${SPECTRAL_WARNINGS:-0}" -gt 0 ]; then
        step_warn "API Lint: ${SPECTRAL_WARNINGS} warning(s)"
      else
        step_pass "API Lint: contrato OpenAPI válido"
      fi
    else
      step_warn "API Lint: nenhum arquivo OpenAPI encontrado — pulando"
    fi
  else
    step_warn "Spectral não instalado — pulando"
    echo -e "${YELLOW}  Instale: npm install -g @stoplight/spectral-cli${NC}"
  fi
else
  step_warn "API Lint desativado (ENABLE_API_LINT=false). Ativar: ENABLE_API_LINT=true ./quality-gate.sh"
fi

# ============================================================
# [10/11] Infra Scan — Segurança de Infraestrutura (Trivy)
# ============================================================
echo -e "\n${CYAN}[10/${TOTAL_STEPS}] Infra Scan — Segurança de infraestrutura (Trivy)...${NC}"
if [ "${ENABLE_INFRA_SCAN:-false}" = "true" ]; then
  if command -v trivy &> /dev/null; then
    INFRA_FINDINGS=0
    INFRA_SCAN_SEVERITY="${INFRA_SCAN_SEVERITY:-HIGH}"

    # Scan Dockerfiles
    if [ "${SCAN_DOCKERFILE:-true}" = "true" ]; then
      DOCKERFILES=$(find . -maxdepth 4 -type f \( -name "Dockerfile" -o -name "Dockerfile.*" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/scanner/test/fixtures/*" 2>/dev/null || true)
      if [ -n "${DOCKERFILES}" ]; then
        DF_FINDINGS=$(trivy config . --severity "${INFRA_SCAN_SEVERITY},CRITICAL" --format json --quiet 2>/dev/null | python3 -c "
import json, sys
try:
  data = json.load(sys.stdin)
  count = sum(len(r.get('Misconfigurations', []) or []) for r in (data.get('Results', []) or []))
  print(count)
except: print(0)
" 2>/dev/null || echo "0")
        INFRA_FINDINGS=$((INFRA_FINDINGS + DF_FINDINGS))
      fi
    fi

    # Scan K8s manifests
    if [ "${SCAN_K8S:-true}" = "true" ]; then
      for k8s_dir in k8s kubernetes manifests deploy deployments; do
        if [ -d "${k8s_dir}" ]; then
          K8S_FINDINGS=$(trivy config "${k8s_dir}" --severity "${INFRA_SCAN_SEVERITY},CRITICAL" --format json --quiet 2>/dev/null | python3 -c "
import json, sys
try:
  data = json.load(sys.stdin)
  count = sum(len(r.get('Misconfigurations', []) or []) for r in (data.get('Results', []) or []))
  print(count)
except: print(0)
" 2>/dev/null || echo "0")
          INFRA_FINDINGS=$((INFRA_FINDINGS + K8S_FINDINGS))
        fi
      done
    fi

    if [ "${INFRA_FINDINGS}" -gt 0 ]; then
      step_warn "Infra Scan: ${INFRA_FINDINGS} finding(s) de segurança"
    else
      step_pass "Infra Scan: infraestrutura segura"
    fi
  else
    step_warn "Trivy não instalado — pulando"
    echo -e "${YELLOW}  Instale: https://aquasecurity.github.io/trivy/latest/getting-started/installation/${NC}"
  fi
else
  step_warn "Infra Scan desativado (ENABLE_INFRA_SCAN=false). Ativar: ENABLE_INFRA_SCAN=true ./quality-gate.sh"
fi

# ============================================================
# [11/11] Stryker — Mutation Testing (opcional, pesado)
# ============================================================
echo -e "\n${CYAN}[11/${TOTAL_STEPS}] Stryker — Mutation testing...${NC}"
if [ "${RUN_STRYKER:-false}" = "true" ]; then
  if npx stryker --version &> /dev/null 2>&1; then
    STRYKER_OUTPUT=$(npx stryker run 2>&1 || true)
    MUTATION_SCORE=$(echo "$STRYKER_OUTPUT" | grep -o 'Mutation score: [0-9.]*' | grep -o '[0-9.]*' || echo "0")

    if [ -n "$MUTATION_SCORE" ]; then
      SCORE_INT=${MUTATION_SCORE%.*}
      if [ "$SCORE_INT" -ge 60 ]; then
        step_pass "Stryker: mutation score ${MUTATION_SCORE}%"
      else
        step_warn "Stryker: mutation score ${MUTATION_SCORE}% (abaixo de 60%)"
      fi
    else
      step_warn "Stryker: não foi possível extrair o score"
    fi
  else
    step_warn "Stryker não instalado — pulando"
    echo -e "${YELLOW}  Instale: npm install -D @stryker-mutator/core @stryker-mutator/jest-runner @stryker-mutator/typescript-checker${NC}"
  fi
else
  step_warn "Stryker desabilitado (pesado). Ativar: RUN_STRYKER=true ./quality-gate.sh"
fi

# ============================================================
# RESULTADO FINAL
# ============================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Tempo total: ${DURATION}s${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}${BOLD}  QUALITY GATE FAILED — ${ERRORS} erro(s), ${WARNINGS} warning(s)${NC}"
  echo -e "${RED}  Corrija os erros antes de fazer push.${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}  QUALITY GATE PASSED com ${WARNINGS} warning(s)${NC}"
  echo -e "${YELLOW}  Considere corrigir os warnings.${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 0
else
  echo -e "${GREEN}${BOLD}  QUALITY GATE PASSED — Código limpo!${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 0
fi
