#!/bin/bash
# ============================================================
# Quality Scanner — Entrypoint do Container
# Aplica configs centralizadas do container, ignora configs locais
# Salva resultados em JSON para o dashboard
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ERRORS=0
WARNINGS=0
TOTAL_STEPS=8
START_TIME=$(date +%s)
SCAN_ID=$(date +%Y%m%d_%H%M%S)
SCAN_DATE=$(date +%Y-%m-%d)
CONFIGS_DIR="/quality/configs"
REPORTS_DIR="/reports/${SCAN_DATE}/${SCAN_ID}"

step_pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
step_fail() { echo -e "${RED}  ✗ $1${NC}"; ERRORS=$((ERRORS + 1)); }
step_warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; WARNINGS=$((WARNINGS + 1)); }

# Helper: escreve JSON de resultado de um step
# Uso: write_report <tool> <status> <summary> <details_json>
write_report() {
  local tool="$1" status="$2" summary="$3" details="$4"
  cat > "${REPORTS_DIR}/${tool}.json" <<EOJSON
{
  "tool": "${tool}",
  "status": "${status}",
  "summary": "${summary}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": ${details:-"[]"}
}
EOJSON
}

# Verificar se o projeto foi montado
if [ ! -f /project/package.json ]; then
  echo -e "${RED}Erro: Nenhum projeto encontrado em /project${NC}"
  echo -e "${YELLOW}Use: ./scan.sh /caminho/do/seu/projeto${NC}"
  exit 1
fi

PROJECT_NAME=$(node -e "console.log(require('/project/package.json').name || 'unknown')" 2>/dev/null || echo "unknown")

# Criar diretório de reports
mkdir -p "${REPORTS_DIR}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  Quality Scanner — ${PROJECT_NAME}${NC}"
echo -e "${BLUE}  Report: ${REPORTS_DIR}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Instalar dependências do projeto se necessário
if [ ! -d /project/node_modules ]; then
  echo -e "\n${CYAN}Instalando dependências do projeto...${NC}"
  cd /project && npm ci --silent 2>&1 || npm install --silent 2>&1
fi

cd /project

# ============================================================
# [1/8] Gitleaks — Secrets
# ============================================================
echo -e "\n${CYAN}[1/${TOTAL_STEPS}] Gitleaks — Verificando secrets...${NC}"
GITLEAKS_OUTPUT=$(gitleaks detect --source /project --no-git --config "${CONFIGS_DIR}/.gitleaks.toml" --report-format json --report-path "${REPORTS_DIR}/gitleaks_raw.json" 2>&1 || true)

if [ -f "${REPORTS_DIR}/gitleaks_raw.json" ] && [ -s "${REPORTS_DIR}/gitleaks_raw.json" ]; then
  LEAKS_COUNT=$(python3 -c "import json; d=json.load(open('${REPORTS_DIR}/gitleaks_raw.json')); print(len(d))" 2>/dev/null || echo "0")
else
  LEAKS_COUNT=0
fi

if [ "${LEAKS_COUNT:-0}" -gt 0 ]; then
  step_fail "Gitleaks: ${LEAKS_COUNT} secret(s) encontrado(s)"
  # Converter raw para formato padronizado
  python3 -c "
import json
raw = json.load(open('${REPORTS_DIR}/gitleaks_raw.json'))
items = [{'file': r.get('File',''), 'rule': r.get('RuleID',''), 'line': r.get('StartLine',0), 'match': r.get('Match','')[:80]} for r in raw]
print(json.dumps(items))
" > /tmp/gitleaks_details.json 2>/dev/null || echo "[]" > /tmp/gitleaks_details.json
  write_report "gitleaks" "fail" "${LEAKS_COUNT} secret(s) encontrado(s)" "$(cat /tmp/gitleaks_details.json)"
else
  step_pass "Nenhum secret encontrado"
  write_report "gitleaks" "pass" "Nenhum secret encontrado" "[]"
fi
rm -f "${REPORTS_DIR}/gitleaks_raw.json"

# ============================================================
# [2/8] TypeScript — Compilação
# ============================================================
echo -e "\n${CYAN}[2/${TOTAL_STEPS}] TypeScript — Verificando compilação...${NC}"
if [ -f /project/tsconfig.json ]; then
  TSC_OUTPUT=$(npx tsc --noEmit 2>&1 || true)
  TSC_ERRORS=$(echo "$TSC_OUTPUT" | grep -c "error TS" 2>/dev/null | tr -d '\n' || echo "0")

  if [ "${TSC_ERRORS:-0}" -eq 0 ]; then
    step_pass "TypeScript compila sem erros"
    write_report "typescript" "pass" "Compila sem erros" "[]"
  else
    step_fail "TypeScript: ${TSC_ERRORS} erro(s) de compilação"
    # Extrair detalhes dos erros
    DETAILS=$(echo "$TSC_OUTPUT" | grep "error TS" | head -50 | python3 -c "
import sys, json, re
items = []
for line in sys.stdin:
  line = line.strip()
  m = re.match(r'(.+)\((\d+),(\d+)\):\s*error\s+(TS\d+):\s*(.*)', line)
  if m:
    items.append({'file': m.group(1), 'line': int(m.group(2)), 'code': m.group(4), 'message': m.group(5)})
print(json.dumps(items))
" 2>/dev/null || echo "[]")
    write_report "typescript" "fail" "${TSC_ERRORS} erro(s) de compilação" "$DETAILS"
  fi
else
  step_warn "tsconfig.json não encontrado — pulando"
  write_report "typescript" "skip" "tsconfig.json não encontrado" "[]"
fi

# ============================================================
# [3/8] ESLint — Qualidade (usa config do CONTAINER)
# ============================================================
echo -e "\n${CYAN}[3/${TOTAL_STEPS}] ESLint — Regras de qualidade (config centralizada)...${NC}"
if [ -d /project/src ]; then
  # Gerar output JSON para o report
  npx eslint /project/src --ext .ts \
    --config "${CONFIGS_DIR}/.eslintrc.js" \
    --resolve-plugins-relative-to /usr/local/lib/node_modules \
    --no-eslintrc \
    --format json > "${REPORTS_DIR}/eslint_raw.json" 2>/dev/null || true

  # Contar erros e warnings do JSON
  ESLINT_COUNTS=$(python3 -c "
import json
data = json.load(open('${REPORTS_DIR}/eslint_raw.json'))
errors = sum(f['errorCount'] for f in data)
warnings = sum(f['warningCount'] for f in data)
print(f'{errors} {warnings}')
" 2>/dev/null || echo "0 0")
  ESLINT_ERRORS=$(echo "$ESLINT_COUNTS" | awk '{print $1}')
  ESLINT_WARNINGS=$(echo "$ESLINT_COUNTS" | awk '{print $2}')

  # Gerar detalhes agrupados por regra
  DETAILS=$(python3 -c "
import json
from collections import defaultdict
data = json.load(open('${REPORTS_DIR}/eslint_raw.json'))
by_rule = defaultdict(list)
for f in data:
  fp = f['filePath'].replace('/project/', '')
  for m in f.get('messages', []):
    rule = m.get('ruleId', 'unknown')
    by_rule[rule].append({'file': fp, 'line': m.get('line',0), 'message': m.get('message',''), 'severity': 'error' if m.get('severity')==2 else 'warning'})
items = [{'rule': k, 'count': len(v), 'occurrences': v[:10]} for k, v in sorted(by_rule.items(), key=lambda x: -len(x[1]))]
print(json.dumps(items))
" 2>/dev/null || echo "[]")

  if [ "${ESLINT_ERRORS:-0}" -gt 0 ]; then
    step_fail "ESLint: ${ESLINT_ERRORS} erro(s), ${ESLINT_WARNINGS} warning(s)"
    write_report "eslint" "fail" "${ESLINT_ERRORS} erro(s), ${ESLINT_WARNINGS} warning(s)" "$DETAILS"
  elif [ "${ESLINT_WARNINGS:-0}" -gt 0 ]; then
    step_warn "ESLint: ${ESLINT_WARNINGS} warning(s)"
    write_report "eslint" "warn" "${ESLINT_WARNINGS} warning(s)" "$DETAILS"
  else
    step_pass "ESLint: nenhum problema"
    write_report "eslint" "pass" "Nenhum problema" "[]"
  fi
  rm -f "${REPORTS_DIR}/eslint_raw.json"
else
  step_warn "Diretório src/ não encontrado — pulando ESLint"
  write_report "eslint" "skip" "Diretório src/ não encontrado" "[]"
fi

# ============================================================
# [4/8] Prettier — Formatação (usa config do CONTAINER)
# ============================================================
echo -e "\n${CYAN}[4/${TOTAL_STEPS}] Prettier — Formatação (config centralizada)...${NC}"
if [ -d /project/src ]; then
  PRETTIER_OUTPUT=$(npx prettier --check '/project/src/**/*.ts' \
    --config "${CONFIGS_DIR}/.prettierrc" 2>&1 || true)

  if echo "$PRETTIER_OUTPUT" | grep -q "All matched files use Prettier code style"; then
    step_pass "Formatação OK"
    write_report "prettier" "pass" "Todos os arquivos formatados" "[]"
  else
    FILES_LIST=$(echo "$PRETTIER_OUTPUT" | grep "\.ts" | sed 's|/project/||g' || true)
    UNFORMATTED=$(echo "$FILES_LIST" | grep -c "\.ts" 2>/dev/null | tr -d '\n' || echo "0")
    if [ "${UNFORMATTED:-0}" -gt 0 ]; then
      step_warn "Prettier: ${UNFORMATTED} arquivo(s) com formatação diferente do padrão"
      DETAILS=$(echo "$FILES_LIST" | python3 -c "
import sys, json
items = [{'file': line.strip()} for line in sys.stdin if line.strip()]
print(json.dumps(items))
" 2>/dev/null || echo "[]")
      write_report "prettier" "warn" "${UNFORMATTED} arquivo(s) com formatação diferente" "$DETAILS"
    else
      step_pass "Formatação OK"
      write_report "prettier" "pass" "Todos os arquivos formatados" "[]"
    fi
  fi
else
  step_warn "Diretório src/ não encontrado — pulando Prettier"
  write_report "prettier" "skip" "Diretório src/ não encontrado" "[]"
fi

# ============================================================
# [5/8] npm audit — Vulnerabilidades
# ============================================================
echo -e "\n${CYAN}[5/${TOTAL_STEPS}] npm audit — Vulnerabilidades...${NC}"
npm audit --production --json > "${REPORTS_DIR}/audit_raw.json" 2>/dev/null || true

AUDIT_COUNTS=$(python3 -c "
import json
try:
  data = json.load(open('${REPORTS_DIR}/audit_raw.json'))
  meta = data.get('metadata', {}).get('vulnerabilities', {})
  print(f\"{meta.get('critical',0)} {meta.get('high',0)} {meta.get('moderate',0)} {meta.get('low',0)}\")
except: print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
CRITICAL=$(echo "$AUDIT_COUNTS" | awk '{print $1}')
HIGH=$(echo "$AUDIT_COUNTS" | awk '{print $2}')
MODERATE=$(echo "$AUDIT_COUNTS" | awk '{print $3}')
LOW=$(echo "$AUDIT_COUNTS" | awk '{print $4}')

DETAILS=$(python3 -c "
import json
try:
  data = json.load(open('${REPORTS_DIR}/audit_raw.json'))
  vulns = data.get('vulnerabilities', {})
  items = []
  for name, v in vulns.items():
    items.append({'package': name, 'severity': v.get('severity',''), 'title': v.get('via',[{}])[0].get('title','') if isinstance(v.get('via',[{}])[0], dict) else str(v.get('via',[''])[0]), 'fixAvailable': bool(v.get('fixAvailable'))})
  items.sort(key=lambda x: {'critical':0,'high':1,'moderate':2,'low':3}.get(x['severity'],4))
  print(json.dumps(items[:50]))
except: print('[]')
" 2>/dev/null || echo "[]")

if [ "${CRITICAL:-0}" -gt 0 ]; then
  step_fail "npm audit: ${CRITICAL} critical, ${HIGH} high"
  write_report "audit" "fail" "${CRITICAL} critical, ${HIGH} high, ${MODERATE} moderate, ${LOW} low" "$DETAILS"
elif [ "${HIGH:-0}" -gt 0 ]; then
  step_warn "npm audit: ${HIGH} high"
  write_report "audit" "warn" "${HIGH} high, ${MODERATE} moderate, ${LOW} low" "$DETAILS"
else
  step_pass "Sem vulnerabilidades críticas"
  write_report "audit" "pass" "Sem vulnerabilidades críticas" "$DETAILS"
fi
rm -f "${REPORTS_DIR}/audit_raw.json"

# ============================================================
# [6/8] Knip — Código morto
# ============================================================
echo -e "\n${CYAN}[6/${TOTAL_STEPS}] Knip — Código morto...${NC}"
KNIP_OUTPUT=$(npx knip --no-progress 2>&1 || true)

KNIP_DETAILS=$(echo "$KNIP_OUTPUT" | python3 -c "
import sys, json, re
items = []
current_type = 'unknown'
for line in sys.stdin:
  line = line.rstrip()
  if 'Unused file' in line: current_type = 'unused_file'
  elif 'Unused export' in line: current_type = 'unused_export'
  elif 'Unused depend' in line: current_type = 'unused_dependency'
  elif line.strip() and not line.startswith(' ') and not line.startswith('='):
    items.append({'type': current_type, 'item': line.strip()})
print(json.dumps(items[:100]))
" 2>/dev/null || echo "[]")

UNUSED_EXPORTS=$(echo "$KNIP_OUTPUT" | grep -c "Unused export" 2>/dev/null | tr -d '\n' || echo "0")
UNUSED_FILES=$(echo "$KNIP_OUTPUT" | grep -c "Unused file" 2>/dev/null | tr -d '\n' || echo "0")
UNUSED_DEPS=$(echo "$KNIP_OUTPUT" | grep -c "Unused depend" 2>/dev/null | tr -d '\n' || echo "0")

if [ "${UNUSED_FILES:-0}" -gt 0 ] || [ "${UNUSED_EXPORTS:-0}" -gt 0 ] || [ "${UNUSED_DEPS:-0}" -gt 0 ]; then
  step_warn "Knip: ${UNUSED_FILES} arquivo(s), ${UNUSED_EXPORTS} export(s), ${UNUSED_DEPS} dep(s) não usados"
  write_report "knip" "warn" "${UNUSED_FILES} arquivo(s), ${UNUSED_EXPORTS} export(s), ${UNUSED_DEPS} dep(s)" "$KNIP_DETAILS"
else
  step_pass "Sem código morto detectado"
  write_report "knip" "pass" "Sem código morto detectado" "[]"
fi

# ============================================================
# [7/8] Jest — Testes + Cobertura
# ============================================================
echo -e "\n${CYAN}[7/${TOTAL_STEPS}] Jest — Testes + Cobertura...${NC}"
JEST_OUTPUT=$(npx jest --coverage --silent --forceExit --json 2>/dev/null || true)

# Salvar JSON do Jest
echo "$JEST_OUTPUT" > "${REPORTS_DIR}/jest_raw.json" 2>/dev/null || true

JEST_SUMMARY=$(python3 -c "
import json, sys
try:
  data = json.loads(open('${REPORTS_DIR}/jest_raw.json').read())
  r = data.get('testResults', [])
  passed = data.get('numPassedTests', 0)
  failed = data.get('numFailedTests', 0)
  total = data.get('numTotalTests', 0)
  suites_failed = data.get('numFailedTestSuites', 0)

  # Coverage
  cov = {}
  cmap = data.get('coverageMap', {})
  total_stmts = total_stmts_covered = 0
  total_branches = total_branches_covered = 0
  total_funcs = total_funcs_covered = 0
  total_lines = total_lines_covered = 0
  file_cov = []
  for fp, fc in cmap.items():
    s = fc.get('s', {}); b = fc.get('b', {}); f = fc.get('f', {}); sm = fc.get('statementMap', {})
    sc = sum(1 for v in s.values() if v > 0); st = len(s)
    bc = sum(1 for bv in b.values() for v in bv if v > 0); bt = sum(len(bv) for bv in b.values())
    fcc = sum(1 for v in f.values() if v > 0); ft = len(f)
    lm = fc.get('lineMap', fc.get('statementMap', {}))
    lines = set()
    for k, v in sm.items():
      for ln in range(v.get('start',{}).get('line',0), v.get('end',{}).get('line',0)+1):
        lines.add(ln)
    lc = sum(1 for k, v in s.items() if v > 0)
    lt = len(s)
    total_stmts += st; total_stmts_covered += sc
    total_branches += bt; total_branches_covered += bc
    total_funcs += ft; total_funcs_covered += fcc
    total_lines += lt; total_lines_covered += lc
    file_cov.append({'file': fp.replace('/project/',''), 'statements': f'{sc}/{st}', 'branches': f'{bc}/{bt}', 'functions': f'{fcc}/{ft}'})

  cov = {
    'statements': {'covered': total_stmts_covered, 'total': total_stmts, 'pct': round(total_stmts_covered/total_stmts*100,1) if total_stmts else 100},
    'branches': {'covered': total_branches_covered, 'total': total_branches, 'pct': round(total_branches_covered/total_branches*100,1) if total_branches else 100},
    'functions': {'covered': total_funcs_covered, 'total': total_funcs, 'pct': round(total_funcs_covered/total_funcs*100,1) if total_funcs else 100},
    'lines': {'covered': total_lines_covered, 'total': total_lines, 'pct': round(total_lines_covered/total_lines*100,1) if total_lines else 100}
  }

  # Failed tests details
  failures = []
  for suite in r:
    for ar in suite.get('assertionResults', []):
      if ar.get('status') == 'failed':
        failures.append({'test': ar.get('fullName',''), 'message': '\\n'.join(ar.get('failureMessages',[])) [:500]})

  result = {'passed': passed, 'failed': failed, 'total': total, 'coverage': cov, 'failures': failures[:20], 'files': file_cov}
  print(json.dumps(result))
except Exception as e:
  print(json.dumps({'passed':0,'failed':0,'total':0,'coverage':{},'failures':[],'files':[],'error':str(e)}))
" 2>/dev/null || echo '{"passed":0,"failed":0,"total":0,"coverage":{},"failures":[],"files":[]}')

JEST_FAILED=$(echo "$JEST_SUMMARY" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('failed',0))" 2>/dev/null || echo "0")
JEST_PASSED=$(echo "$JEST_SUMMARY" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('passed',0))" 2>/dev/null || echo "0")

if [ "${JEST_FAILED:-0}" -gt 0 ]; then
  step_fail "Jest: ${JEST_FAILED} teste(s) falhando"
  write_report "jest" "fail" "${JEST_FAILED} falhando, ${JEST_PASSED} passando" "$JEST_SUMMARY"
else
  step_pass "Testes: todos passando (${JEST_PASSED})"
  write_report "jest" "pass" "${JEST_PASSED} teste(s) passando" "$JEST_SUMMARY"
fi

# Mostrar cobertura no terminal
echo "$JEST_SUMMARY" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
cov = d.get('coverage', {})
for k in ['statements','branches','functions','lines']:
  c = cov.get(k, {})
  pct = c.get('pct', 0)
  total = c.get('total', 0)
  covered = c.get('covered', 0)
  print(f'    {k.capitalize():14s}: {pct}% ( {covered}/{total} )')
" 2>/dev/null || true
rm -f "${REPORTS_DIR}/jest_raw.json"

# ============================================================
# [8/8] SonarQube — Dispara análise via API REST
# ============================================================
echo -e "\n${CYAN}[8/${TOTAL_STEPS}] SonarQube — Disparando análise...${NC}"

SONAR_HOST="${SONAR_HOST_URL:-http://sonarqube:9000}"
SONAR_KEY="${SONAR_PROJECT_KEY:-${PROJECT_NAME}}"
SQ_USER="${SONAR_ADMIN_USER:-admin}"
SQ_PASS="${SONAR_ADMIN_PASSWORD:-admin}"
SQ_PUBLIC="${SONAR_PUBLIC_URL:-${SONAR_HOST}}"

if curl -s "${SONAR_HOST}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
  # Buscar métricas da última análise existente no SonarQube
  SQ_MEASURES=$(curl -s -u "${SQ_USER}:${SQ_PASS}" \
    "${SONAR_HOST}/api/measures/component?component=${SONAR_KEY}&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,sqale_rating,reliability_rating,security_rating,alert_status" \
    2>/dev/null || echo "{}")

  SQ_ISSUES=$(curl -s -u "${SQ_USER}:${SQ_PASS}" \
    "${SONAR_HOST}/api/issues/search?componentKeys=${SONAR_KEY}&ps=100&resolved=false" \
    2>/dev/null || echo "{}")

  QG_RESPONSE=$(curl -s -u "${SQ_USER}:${SQ_PASS}" \
    "${SONAR_HOST}/api/qualitygates/project_status?projectKey=${SONAR_KEY}" \
    2>/dev/null || echo "{}")

  QG_STATUS=$(echo "$QG_RESPONSE" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('projectStatus',{}).get('status','NONE'))" 2>/dev/null || echo "NONE")

  # Gerar report do SonarQube
  SQ_DETAILS=$(python3 -c "
import json
measures_raw = json.loads('''${SQ_MEASURES}''')
issues_raw = json.loads('''${SQ_ISSUES}''')
qg_raw = json.loads('''${QG_RESPONSE}''')

# Métricas
metrics = {}
for m in measures_raw.get('component', {}).get('measures', []):
  metrics[m['metric']] = m.get('value', '0')

# Issues agrupados por tipo e severidade
issues = issues_raw.get('issues', [])
by_type = {}
for i in issues:
  t = i.get('type', 'UNKNOWN')
  if t not in by_type: by_type[t] = []
  by_type[t].append({
    'rule': i.get('rule',''),
    'severity': i.get('severity',''),
    'message': i.get('message','')[:200],
    'component': i.get('component','').replace('${SONAR_KEY}:',''),
    'line': i.get('line', 0)
  })

# Quality Gate conditions
conditions = qg_raw.get('projectStatus', {}).get('conditions', [])

result = {
  'qualityGate': '${QG_STATUS}',
  'dashboardUrl': '${SQ_PUBLIC}/dashboard?id=${SONAR_KEY}',
  'metrics': metrics,
  'issuesByType': {k: {'count': len(v), 'items': v[:20]} for k, v in by_type.items()},
  'totalIssues': len(issues),
  'conditions': conditions
}
print(json.dumps(result))
" 2>/dev/null || echo '{"qualityGate":"NONE","metrics":{},"issuesByType":{},"totalIssues":0}')

  if [ "$QG_STATUS" = "OK" ]; then
    step_pass "SonarQube Quality Gate: PASSED"
    write_report "sonarqube" "pass" "Quality Gate: PASSED" "$SQ_DETAILS"
  elif [ "$QG_STATUS" = "ERROR" ]; then
    step_fail "SonarQube Quality Gate: FAILED"
    write_report "sonarqube" "fail" "Quality Gate: FAILED" "$SQ_DETAILS"
  else
    step_warn "SonarQube: sem análise prévia (execute sonar-scanner separadamente)"
    write_report "sonarqube" "warn" "Sem análise prévia — execute sonar-scanner separadamente" "$SQ_DETAILS"
  fi
  echo -e "${CYAN}  Dashboard: ${SQ_PUBLIC}/dashboard?id=${SONAR_KEY}${NC}"
else
  step_warn "SonarQube não acessível em ${SONAR_HOST} — pulando"
  write_report "sonarqube" "skip" "SonarQube não acessível" "[]"
fi

# ============================================================
# RESULTADO FINAL — Gerar summary.json
# ============================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $ERRORS -gt 0 ]; then
  GATE_STATUS="FAILED"
elif [ $WARNINGS -gt 0 ]; then
  GATE_STATUS="PASSED_WITH_WARNINGS"
else
  GATE_STATUS="PASSED"
fi

cat > "${REPORTS_DIR}/summary.json" <<EOJSON
{
  "scanId": "${SCAN_ID}",
  "project": "${PROJECT_NAME}",
  "date": "${SCAN_DATE}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration": ${DURATION},
  "gateStatus": "${GATE_STATUS}",
  "errors": ${ERRORS},
  "warnings": ${WARNINGS},
  "tools": ["gitleaks","typescript","eslint","prettier","audit","knip","jest","sonarqube"]
}
EOJSON

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Projeto: ${PROJECT_NAME} | Tempo: ${DURATION}s${NC}"
echo -e "${BLUE}  Reports: ${REPORTS_DIR}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}${BOLD}  QUALITY GATE FAILED — ${ERRORS} erro(s), ${WARNINGS} warning(s)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}  QUALITY GATE PASSED com ${WARNINGS} warning(s)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 0
else
  echo -e "${GREEN}${BOLD}  QUALITY GATE PASSED — Código limpo!${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  exit 0
fi
