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

## API Lint — Validação de Contratos OpenAPI (Step 9)

O scanner inclui um step opcional para validação de contratos OpenAPI/Swagger usando **Spectral**. Ele garante que a documentação da API segue padrões REST da organização.

### Ativação

```bash
# Via variável de ambiente no scan
ENABLE_API_LINT=true ./scan.sh /caminho/do/projeto

# Via docker-compose
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### O que é validado

- Todas as rotas têm response `400` mapeado
- Paths usam `kebab-case` (ex: `/meu-recurso`)
- Propriedades de schema usam `camelCase`
- Toda operação tem `operationId`, `description`, `summary` e `tags`
- Paths não terminam com `/`
- Responses 200/201 têm `content` definido

### Configuração

| Variável | Default | Descrição |
| -------- | ------- | --------- |
| `ENABLE_API_LINT` | `false` | Ativa/desativa o step |
| `API_LINT_SEVERITY` | `warn` | `warn` = apenas reporta, `error` = bloqueia pipeline |
| `OPENAPI_FILE_PATH` | *(auto-detect)* | Caminho manual para o arquivo OpenAPI |

O arquivo OpenAPI é detectado automaticamente (`swagger.json`, `openapi.yaml`, etc.). Para customizar as regras, edite `scanner/configs/.spectral.yml`. Veja o guia completo em [`scanner/configs/README.md`](./scanner/configs/README.md).

## Infra Scan — Segurança de Infraestrutura (Step 10)

O scanner inclui um step opcional para análise de segurança de infraestrutura usando **Trivy**. Ele varre `Dockerfile`, `docker-compose.yml` e manifests Kubernetes, bloqueando antes que cheguem ao cluster:

- Imagens base desatualizadas ou usando tag `latest`
- Containers rodando como `root`
- Configurações de rede expostas (`hostNetwork`, `hostPID`)
- Containers privilegiados
- Falta de limites de recursos (CPU/memory)
- Falta de `securityContext` e `HEALTHCHECK`

### Ativação

```bash
# Via variável de ambiente no scan
ENABLE_INFRA_SCAN=true ./scan.sh /caminho/do/projeto

# Via docker-compose
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### O que é varrido

| Tipo | Arquivos Detectados | Exemplos de Findings |
| ---- | ------------------- | -------------------- |
| **Dockerfile** | `Dockerfile`, `Dockerfile.*` | Imagem `latest`, sem `USER`, sem `HEALTHCHECK`, uso de `ADD` |
| **docker-compose** | `docker-compose.yml`, `compose.yaml` | `privileged: true`, portas expostas, volumes perigosos |
| **Kubernetes** | `deployment.yaml`, `service.yaml`, etc. | `hostNetwork`, sem `securityContext`, sem limites de recursos |

### Configuração

| Variável | Default | Descrição |
| -------- | ------- | --------- |
| `ENABLE_INFRA_SCAN` | `false` | Ativa/desativa o step |
| `INFRA_SCAN_SEVERITY` | `HIGH` | Nível mínimo para bloqueio: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `SCAN_DOCKERFILE` | `true` | Ativa varredura de Dockerfiles |
| `SCAN_K8S` | `true` | Ativa varredura de manifests Kubernetes |
| `SCAN_COMPOSE` | `true` | Ativa varredura de docker-compose |

### Severity Thresholds

- **`CRITICAL`** — bloqueia sempre (ex: container privilegiado em K8s)
- **`HIGH`** — bloqueia por padrão (ex: rodando como root, hostNetwork)
- **`MEDIUM`** / **`LOW`** — apenas reporta (ex: falta de seccomp profile)

Para customizar as políticas de segurança, edite `scanner/configs/trivy-policy.yaml`. Veja o guia completo em [`scanner/configs/README.md`](./scanner/configs/README.md).

## Estrutura dos Arquivos

```
sonar/
├── docker-compose.yml          # SonarQube + PostgreSQL + Scanner
├── sonar-project.properties    # Configuração do scanner
├── quality-gate.sh             # Quality gate local (11 steps)
├── run-sonar.sh                # Script de análise automatizada
├── scan.sh                     # Wrapper para o scanner Docker
├── .env                        # Variáveis de ambiente (não commitado)
├── .env.example                # Exemplo de variáveis
├── scanner/
│   ├── Dockerfile              # Imagem do scanner
│   ├── entrypoint.sh           # Pipeline de 10 steps (container)
│   ├── configs/
│   │   ├── .eslintrc.js        # Regras ESLint centralizadas
│   │   ├── .prettierrc         # Formatação Prettier
│   │   ├── .gitleaks.toml      # Detecção de secrets
│   │   ├── .spectral.yml       # Regras OpenAPI/Swagger
│   │   ├── trivy-policy.yaml   # Políticas de segurança Trivy
│   │   ├── sonar-project.properties
│   │   └── README.md           # Guia de configuração
│   ├── scripts/
│   │   ├── swagger-lint.sh     # Script de lint OpenAPI
│   │   └── infra-scan.sh       # Script de segurança de infraestrutura
│   └── test/
│       ├── fixtures/
│       │   ├── swagger-valid.json
│       │   ├── swagger-invalid.json
│       │   ├── Dockerfile.safe
│       │   ├── Dockerfile.unsafe
│       │   ├── compose-safe.yml
│       │   ├── compose-unsafe.yml
│       │   ├── deployment-safe.yaml
│       │   └── deployment-unsafe.yaml
│       ├── test-api-lint.sh    # Testes do API Lint
│       └── test-infra-scan.sh  # Testes do Infra Scan
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
