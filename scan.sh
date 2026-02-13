#!/bin/bash
# ============================================================
# scan.sh — Roda o Quality Scanner em qualquer projeto
#
# Uso:
#   ./scan.sh /caminho/do/seu/projeto
#   ./scan.sh .                          (projeto atual)
#   ./scan.sh ~/projetos/meu-backend
#
# O container usa suas próprias configs (ESLint, Prettier, etc.)
# e ignora qualquer config local do projeto.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Carregar variáveis do .env
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

PROJECT_PATH="${1:-.}"

# Resolver caminho absoluto
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "Erro: Diretório '$1' não encontrado."
  exit 1
}

# Verificar se é um projeto Node.js
if [ ! -f "$PROJECT_PATH/package.json" ]; then
  echo "Erro: package.json não encontrado em $PROJECT_PATH"
  echo "Certifique-se de apontar para a raiz de um projeto Node.js/NestJS."
  exit 1
fi

PROJECT_NAME=$(node -e "console.log(require('$PROJECT_PATH/package.json').name || 'unknown')" 2>/dev/null || echo "unknown")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Quality Scanner                                     ║"
echo "║  Projeto: $PROJECT_NAME"
echo "║  Path:    $PROJECT_PATH"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Variáveis com defaults do .env
SCANNER_IMG="${SCANNER_IMAGE:-quality-scanner:latest}"
SONAR_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_ADM_USER="${SONAR_ADMIN_USER:-admin}"
SONAR_ADM_PASS="${SONAR_ADMIN_PASSWORD:-admin}"
REPORTS="${REPORTS_DIR:-./reports}"
REPORTS="${REPORTS#./}"
DASH_PORT="${DASHBOARD_PORT:-3000}"

# Garantir que o SonarQube + Scanner estão buildados
echo "Verificando containers..."
cd "$SCRIPT_DIR"

# Build do scanner se necessário
if ! docker image inspect "${SCANNER_IMG}" &>/dev/null; then
  echo "Buildando imagem do scanner (primeira vez)..."
  docker build -t "${SCANNER_IMG}" ./scanner/
fi

# Subir SonarQube se não estiver rodando
if ! curl -s "${SONAR_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
  echo "Subindo SonarQube..."
  docker compose up -d sonarqube db
  echo "Aguardando SonarQube iniciar..."
  for i in $(seq 1 60); do
    if curl -s "${SONAR_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
      echo "SonarQube está UP!"
      break
    fi
    if [ $i -eq 60 ]; then
      echo "Timeout: SonarQube não iniciou em 5 minutos."
      echo "Continuando sem SonarQube..."
    fi
    sleep 5
  done
fi

# Gerar token se não existir
if [ -z "$SONAR_TOKEN" ]; then
  echo "Gerando token do SonarQube..."
  TOKEN_RESPONSE=$(curl -s -u "${SONAR_ADM_USER}:${SONAR_ADM_PASS}" -X POST "${SONAR_URL}/api/user_tokens/generate?name=scanner-$(date +%s)" 2>/dev/null || true)
  SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)
fi

# Criar projeto no SonarQube se não existir
curl -s -u "${SONAR_ADM_USER}:${SONAR_ADM_PASS}" -X POST "${SONAR_URL}/api/projects/create?name=${PROJECT_NAME}&project=${PROJECT_NAME}" 2>/dev/null || true

# Criar diretório de reports
mkdir -p "$SCRIPT_DIR/${REPORTS}"

# Rodar o scanner via docker compose
echo ""
echo "Iniciando análise..."
echo ""

PROJECT_PATH="$PROJECT_PATH" \
SONAR_PROJECT_KEY="${PROJECT_NAME}" \
SONAR_TOKEN="${SONAR_TOKEN}" \
docker compose --profile scan run --rm scanner

# Encontrar o report mais recente
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
