#!/bin/bash
# ============================================================
# Swagger/OpenAPI Lint — Step 9 do Quality Scanner
# Usa Spectral para validar contratos OpenAPI/Swagger
# ============================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────
# Cores (herdadas do entrypoint, mas definidas como fallback)
# ──────────────────────────────────────────────────────────
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# ──────────────────────────────────────────────────────────
# Parâmetros (recebidos via variáveis de ambiente)
# ──────────────────────────────────────────────────────────
PROJECT_DIR="${1:-/project}"
REPORTS_DIR="${2:-/reports}"
CONFIGS_DIR="${3:-/quality/configs}"
OPENAPI_FILE_PATH="${OPENAPI_FILE_PATH:-}"
API_LINT_SEVERITY="${API_LINT_SEVERITY:-warn}"

# ──────────────────────────────────────────────────────────
# Detecção automática do arquivo OpenAPI
# Procura em ordem de prioridade nos locais mais comuns
# ──────────────────────────────────────────────────────────
detect_openapi_file() {
  local project_dir="$1"

  # Se o usuário especificou manualmente, usar esse
  if [ -n "${OPENAPI_FILE_PATH}" ]; then
    if [ -f "${project_dir}/${OPENAPI_FILE_PATH}" ]; then
      echo "${project_dir}/${OPENAPI_FILE_PATH}"
      return 0
    elif [ -f "${OPENAPI_FILE_PATH}" ]; then
      echo "${OPENAPI_FILE_PATH}"
      return 0
    fi
    echo ""
    return 0
  fi

  # Nomes de arquivo comuns para OpenAPI/Swagger
  local candidates=(
    "swagger.json"
    "swagger.yaml"
    "swagger.yml"
    "openapi.json"
    "openapi.yaml"
    "openapi.yml"
    "api-docs.json"
    "api-docs.yaml"
    "api-docs.yml"
    "docs/swagger.json"
    "docs/swagger.yaml"
    "docs/openapi.json"
    "docs/openapi.yaml"
    "api/swagger.json"
    "api/openapi.json"
    "dist/swagger.json"
    "dist/openapi.json"
  )

  for candidate in "${candidates[@]}"; do
    if [ -f "${project_dir}/${candidate}" ]; then
      echo "${project_dir}/${candidate}"
      return 0
    fi
  done

  # Busca recursiva como último recurso (ignora node_modules e dist)
  local found
  found=$(find "${project_dir}" \
    -maxdepth 3 \
    -type f \
    \( -name "swagger.json" -o -name "swagger.yaml" -o -name "swagger.yml" \
       -o -name "openapi.json" -o -name "openapi.yaml" -o -name "openapi.yml" \) \
    ! -path "*/node_modules/*" \
    ! -path "*/.next/*" \
    ! -path "*/coverage/*" \
    2>/dev/null | head -1)

  if [ -n "${found}" ]; then
    echo "${found}"
    return 0
  fi

  echo ""
  return 0
}

# ──────────────────────────────────────────────────────────
# Execução do Spectral
# ──────────────────────────────────────────────────────────
run_spectral_lint() {
  local openapi_file="$1"
  local ruleset="${CONFIGS_DIR}/.spectral.yml"
  local raw_output="${REPORTS_DIR}/spectral_raw.json"

  # Executar Spectral com output JSON
  spectral lint "${openapi_file}" \
    --ruleset "${ruleset}" \
    --format json \
    --output "${raw_output}" \
    2>/dev/null || true

  # Se não gerou arquivo, criar vazio
  if [ ! -f "${raw_output}" ]; then
    echo "[]" > "${raw_output}"
  fi

  echo "${raw_output}"
}

# ──────────────────────────────────────────────────────────
# Processamento dos resultados
# Gera JSON padronizado para o dashboard
# ──────────────────────────────────────────────────────────
process_results() {
  local raw_file="$1"
  local openapi_file="$2"

  python3 -c "
import json, sys

try:
    raw = json.load(open('${raw_file}'))
except:
    raw = []

# Contadores por severidade
counts = {'error': 0, 'warn': 0, 'info': 0, 'hint': 0}
severity_map = {0: 'error', 1: 'warn', 2: 'info', 3: 'hint'}

violations = []
by_rule = {}

for item in raw:
    sev = severity_map.get(item.get('severity', 2), 'info')
    counts[sev] = counts.get(sev, 0) + 1

    rule_code = item.get('code', 'unknown')
    if rule_code not in by_rule:
        by_rule[rule_code] = {'rule': rule_code, 'severity': sev, 'count': 0, 'occurrences': []}
    by_rule[rule_code]['count'] += 1

    source = item.get('source', '${openapi_file}').replace('/project/', '')
    path_parts = item.get('path', [])
    json_path = '.'.join(str(p) for p in path_parts) if path_parts else ''

    occurrence = {
        'message': item.get('message', ''),
        'path': json_path,
        'source': source,
        'range': item.get('range', {})
    }

    if by_rule[rule_code]['count'] <= 10:
        by_rule[rule_code]['occurrences'].append(occurrence)

result = {
    'openApiFile': '${openapi_file}'.replace('/project/', ''),
    'totalViolations': len(raw),
    'counts': counts,
    'rules': sorted(by_rule.values(), key=lambda x: -x['count'])
}

print(json.dumps(result))
" 2>/dev/null || echo '{"openApiFile":"","totalViolations":0,"counts":{"error":0,"warn":0,"info":0,"hint":0},"rules":[]}'
}

# ──────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────
main() {
  # Detectar arquivo OpenAPI
  local openapi_file
  openapi_file=$(detect_openapi_file "${PROJECT_DIR}")

  if [ -z "${openapi_file}" ]; then
    echo "NO_FILE"
    return 0
  fi

  # Executar lint
  local raw_output
  raw_output=$(run_spectral_lint "${openapi_file}")

  # Processar resultados
  local result
  result=$(process_results "${raw_output}" "${openapi_file}")

  # Extrair contadores
  local errors warnings
  errors=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['counts']['error'])" 2>/dev/null || echo "0")
  warnings=$(echo "${result}" | python3 -c "import json,sys; d=json.loads(sys.stdin.read())['counts']; print(d['warn']+d['info']+d['hint'])" 2>/dev/null || echo "0")

  # Determinar status baseado na severidade configurada
  local status="pass"
  local summary=""

  if [ "${errors}" -gt 0 ]; then
    if [ "${API_LINT_SEVERITY}" = "error" ]; then
      status="fail"
    else
      status="warn"
    fi
    summary="${errors} erro(s), ${warnings} warning(s)"
  elif [ "${warnings}" -gt 0 ]; then
    status="warn"
    summary="${warnings} warning(s)"
  else
    summary="Contrato OpenAPI válido — sem violações"
  fi

  # Output no formato: STATUS|SUMMARY|DETAILS_JSON
  echo "${status}|${summary}|${result}"

  # Limpar raw
  rm -f "${REPORTS_DIR}/spectral_raw.json"
}

main
