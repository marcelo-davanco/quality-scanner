#!/bin/bash
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SonarQube Analysis - NestJS Project   ${NC}"
echo -e "${BLUE}========================================${NC}"

# Carregar variáveis de ambiente
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-nestjs-project}"

# Verificar se o SonarQube está rodando
echo -e "\n${YELLOW}[1/4] Verificando se o SonarQube está rodando...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0
until curl -s "${SONAR_HOST_URL}/api/system/status" | grep -q '"status":"UP"'; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo -e "${RED}✗ SonarQube não está respondendo. Execute: docker compose up -d${NC}"
    exit 1
  fi
  echo -e "  Aguardando SonarQube iniciar... (${RETRY_COUNT}/${MAX_RETRIES})"
  sleep 5
done
echo -e "${GREEN}✓ SonarQube está rodando!${NC}"

# Instalar dependências se necessário
echo -e "\n${YELLOW}[2/4] Verificando dependências...${NC}"
if [ ! -d "node_modules" ]; then
  echo -e "  Instalando dependências..."
  npm install
fi

# Verificar se sonar-scanner está instalado
if ! command -v sonar-scanner &> /dev/null && ! npx sonar-scanner --version &> /dev/null 2>&1; then
  echo -e "  Instalando sonar-scanner..."
  npm install -D sonar-scanner
fi
echo -e "${GREEN}✓ Dependências OK!${NC}"

# Rodar testes com cobertura
echo -e "\n${YELLOW}[3/4] Executando testes com cobertura...${NC}"
npm run test:cov || {
  echo -e "${RED}✗ Testes falharam! Verifique os erros acima.${NC}"
  echo -e "${YELLOW}  Continuando análise mesmo com falhas nos testes...${NC}"
}
echo -e "${GREEN}✓ Testes executados!${NC}"

# Rodar análise do SonarQube
echo -e "\n${YELLOW}[4/4] Executando análise do SonarQube...${NC}"

SONAR_ARGS="-Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.projectKey=${SONAR_PROJECT_KEY}"

if [ -n "${SONAR_TOKEN}" ]; then
  SONAR_ARGS="${SONAR_ARGS} -Dsonar.token=${SONAR_TOKEN}"
else
  echo -e "${YELLOW}  ⚠ SONAR_TOKEN não definido. Usando login padrão (admin/admin).${NC}"
  SONAR_ARGS="${SONAR_ARGS} -Dsonar.login=admin -Dsonar.password=admin"
fi

npx sonar-scanner ${SONAR_ARGS}

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Análise concluída com sucesso!      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${BLUE}Acesse o dashboard: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}${NC}\n"
