# SonarQube + NestJS/TypeScript

Setup Docker para análise de código com SonarQube Community Edition, otimizado para projetos NestJS/TypeScript.

## Pré-requisitos

- **Docker** e **Docker Compose** instalados
- **Node.js** >= 18
- **npm** ou **yarn**

> ⚠️ No macOS/Linux, aumente o limite de memória virtual:
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```

## Quick Start

### 1. Subir o SonarQube

```bash
docker compose up -d
```

Aguarde ~1 minuto para o SonarQube iniciar. Acesse: **http://localhost:9000**

- **Login padrão:** `admin` / `admin`
- Na primeira vez, será solicitado alterar a senha.

### 2. Gerar Token de Acesso

1. Acesse http://localhost:9000
2. Vá em **My Account** → **Security** → **Generate Tokens**
3. Crie um token do tipo **Project Analysis Token**
4. Copie o token e cole no arquivo `.env`:

```env
SONAR_TOKEN=seu_token_aqui
```

### 3. Configurar seu projeto NestJS

Copie os seguintes arquivos para a raiz do seu projeto NestJS:

- `sonar-project.properties`
- `run-sonar.sh`
- `.env` (ajuste o token)

Ou configure o `jest` no `package.json` do seu projeto para gerar cobertura no formato LCOV:

```json
{
  "jest": {
    "coverageDirectory": "coverage",
    "coverageReporters": ["text", "lcov", "clover"],
    "collectCoverageFrom": [
      "src/**/*.ts",
      "!src/**/*.spec.ts",
      "!src/**/*.module.ts",
      "!src/main.ts"
    ]
  }
}
```

### 4. Rodar a Análise

```bash
# Dar permissão ao script
chmod +x run-sonar.sh

# Executar análise completa (testes + sonar)
./run-sonar.sh
```

Ou manualmente:

```bash
# Rodar testes com cobertura
npm run test:cov

# Rodar sonar-scanner
npx sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=SEU_TOKEN
```

### 5. Ver Resultados

Acesse: **http://localhost:9000/dashboard?id=nestjs-project**

## Comandos Úteis

| Comando | Descrição |
|---------|-----------|
| `docker compose up -d` | Iniciar SonarQube |
| `docker compose down` | Parar SonarQube |
| `docker compose down -v` | Parar e remover dados |
| `docker compose logs -f sonarqube` | Ver logs do SonarQube |
| `./run-sonar.sh` | Rodar análise completa |
| `npm run test:cov` | Rodar apenas testes com cobertura |

## O que o SonarQube analisa

- **Bugs** — Problemas que podem causar erros em runtime
- **Vulnerabilities** — Falhas de segurança
- **Code Smells** — Problemas de manutenibilidade
- **Coverage** — Cobertura de testes (linhas e branches)
- **Duplications** — Código duplicado
- **Security Hotspots** — Pontos que precisam revisão de segurança

## Estrutura dos Arquivos

```
sonar/
├── docker-compose.yml        # SonarQube + PostgreSQL
├── sonar-project.properties  # Configuração do scanner
├── run-sonar.sh              # Script de análise automatizada
├── .env                      # Variáveis de ambiente (não commitado)
├── .env.example              # Exemplo de variáveis
├── .gitignore
└── README.md
```

## Troubleshooting

### SonarQube não inicia
```bash
# Verificar logs
docker compose logs sonarqube

# Problema comum no Linux/macOS - aumentar vm.max_map_count
sudo sysctl -w vm.max_map_count=524288
```

### Erro de memória
Adicione ao `docker-compose.yml` no serviço `sonarqube`:
```yaml
deploy:
  resources:
    limits:
      memory: 2g
```

### Scanner não encontra arquivos
Verifique se o `sonar-project.properties` está na raiz do projeto e os paths estão corretos.
