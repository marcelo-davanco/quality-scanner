# Scanner Configs — Guia de Configuração

Este diretório contém todas as configurações centralizadas do Quality Scanner, embutidas no container Docker.

## Arquivos

| Arquivo | Propósito |
| ------- | --------- |
| `.eslintrc.js` | Regras de qualidade ESLint (TypeScript) |
| `.prettierrc` | Formatação de código |
| `.gitleaks.toml` | Detecção de secrets |
| `.spectral.yml` | Validação de contratos OpenAPI/Swagger |
| `trivy-policy.yaml` | Políticas de segurança de infraestrutura (Trivy) |
| `sonar-project.properties` | Configuração padrão do SonarQube |

---

## API Lint — Validação de Contratos OpenAPI (Spectral)

### O que é

O **Spectral** é uma ferramenta de lint para arquivos OpenAPI/Swagger. Ele valida que a documentação da API segue padrões REST definidos pela organização.

### Ativação

```bash
# Via variável de ambiente
ENABLE_API_LINT=true ./scan.sh /caminho/do/projeto

# Via docker-compose
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### Variáveis de Ambiente

| Variável | Default | Descrição |
| -------- | ------- | --------- |
| `ENABLE_API_LINT` | `false` | Ativa/desativa o step de API Lint |
| `API_LINT_SEVERITY` | `warn` | Nível de bloqueio: `warn` (apenas reporta) ou `error` (bloqueia pipeline) |
| `OPENAPI_FILE_PATH` | *(auto-detect)* | Caminho manual para o arquivo OpenAPI relativo ao projeto |

### Detecção Automática

Quando `OPENAPI_FILE_PATH` não é definido, o scanner procura automaticamente nos seguintes locais (em ordem de prioridade):

1. `swagger.json` / `swagger.yaml` / `swagger.yml`
2. `openapi.json` / `openapi.yaml` / `openapi.yml`
3. `api-docs.json` / `api-docs.yaml` / `api-docs.yml`
4. `docs/swagger.json` / `docs/openapi.json`
5. `api/swagger.json` / `api/openapi.json`
6. `dist/swagger.json` / `dist/openapi.json`
7. Busca recursiva (até 3 níveis, ignorando `node_modules`)

### Customização do Ruleset (`.spectral.yml`)

O arquivo `.spectral.yml` estende o ruleset padrão `spectral:oas` e adiciona regras customizadas.

#### Regras Customizadas Incluídas

| Regra | Severidade | Descrição |
| ----- | ---------- | --------- |
| `operation-must-have-400-response` | warn | Toda operação deve mapear response 400 |
| `paths-must-be-kebab-case` | warn | Paths devem usar `kebab-case` |
| `properties-must-be-camel-case` | warn | Propriedades de schema devem usar `camelCase` |
| `operation-must-have-tags` | warn | Toda operação deve ter pelo menos uma tag |
| `operation-must-have-summary` | warn | Toda operação deve ter um summary |
| `no-trailing-slash` | error | Paths não devem terminar com `/` |
| `response-must-have-content` | warn | Responses 200/201 devem ter content definido |

#### Regras Padrão OAS (Override de Severidade)

| Regra | Severidade | Descrição |
| ----- | ---------- | --------- |
| `operation-operationId` | error | Toda operação deve ter `operationId` |
| `operation-description` | error | Toda operação deve ter `description` |
| `info-description` | error | Info deve ter description |
| `info-contact` | warn | Info deve ter contact |
| `oas3-api-servers` | warn | Deve definir servers |

#### Como Adicionar Novas Regras

Edite o arquivo `.spectral.yml` e adicione uma nova regra seguindo o padrão:

```yaml
rules:
  minha-regra-customizada:
    description: "Descrição da regra"
    severity: warn  # error | warn | info | hint
    given: "$.paths[*][*]"  # JSONPath para o alvo
    then:
      field: "campo"
      function: truthy  # truthy | falsy | pattern | schema | etc.
```

#### Referência de Funções Spectral

- **`truthy`** — campo deve existir e ser truthy
- **`falsy`** — campo deve ser falsy
- **`pattern`** — campo deve corresponder a um regex (`functionOptions.match` ou `functionOptions.notMatch`)
- **`schema`** — campo deve corresponder a um JSON Schema
- **`enumeration`** — campo deve ser um dos valores listados
- **`length`** — campo deve ter comprimento dentro do range

### Output JSON

O step gera um relatório JSON com a seguinte estrutura:

```json
{
  "openApiFile": "swagger.json",
  "totalViolations": 5,
  "counts": {
    "error": 1,
    "warn": 3,
    "info": 1,
    "hint": 0
  },
  "rules": [
    {
      "rule": "operation-must-have-400-response",
      "severity": "warn",
      "count": 2,
      "occurrences": [
        {
          "message": "Toda operação deve mapear uma resposta 400 (Bad Request).",
          "path": "paths./users.get",
          "source": "swagger.json",
          "range": { "start": { "line": 10, "character": 6 }, "end": { "line": 10, "character": 20 } }
        }
      ]
    }
  ]
}
```

### Testes

```bash
# Executar testes do API Lint
bash scanner/test/test-api-lint.sh
```

Os testes cobrem os seguintes cenários:

| Cenário | Resultado Esperado |
| ------- | ------------------ |
| API válida | 0 violações, step passa |
| API inválida + severity=warn | Violações reportadas, pipeline continua |
| API inválida + severity=error | Violações reportadas, pipeline bloqueia |
| Sem arquivo OpenAPI | Step ignorado graciosamente |
| Step desativado | Step não executa |
| OPENAPI_FILE_PATH manual | Encontra arquivo no caminho especificado |
| Validação do schema JSON | Output contém todos os campos obrigatórios |

---

## Infra Scan — Segurança de Infraestrutura (Trivy)

### O que é

O **Trivy** é um scanner de segurança open-source da Aqua Security. Ele detecta misconfigurations em arquivos de infraestrutura como código (IaC): Dockerfiles, docker-compose, Kubernetes manifests e Terraform.

### Ativação

```bash
# Via variável de ambiente
ENABLE_INFRA_SCAN=true ./scan.sh /caminho/do/projeto

# Via docker-compose
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### Variáveis de Ambiente

| Variável | Default | Descrição |
| -------- | ------- | --------- |
| `ENABLE_INFRA_SCAN` | `false` | Ativa/desativa o step de Infra Scan |
| `INFRA_SCAN_SEVERITY` | `HIGH` | Nível mínimo para bloqueio: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `SCAN_DOCKERFILE` | `true` | Ativa varredura de Dockerfiles |
| `SCAN_K8S` | `true` | Ativa varredura de manifests Kubernetes |
| `SCAN_COMPOSE` | `true` | Ativa varredura de docker-compose |

### Detecção Automática de Arquivos

O scanner detecta automaticamente arquivos IaC no projeto:

**Dockerfiles:**
- `Dockerfile`, `Dockerfile.*`, `*.dockerfile`
- Busca até 4 níveis de profundidade (ignora `node_modules`, `.git`)

**docker-compose:**
- `docker-compose.yml`, `docker-compose.yaml`
- `docker-compose.*.yml`, `compose.yml`, `compose.yaml`

**Kubernetes:**
- Diretórios: `k8s/`, `kubernetes/`, `manifests/`, `deploy/`, `deployments/`, `helm/`, `charts/`
- Arquivos na raiz: `deployment.yaml`, `service.yaml`, `ingress.yaml`, `configmap.yaml`, etc.

### Regras de Segurança Cobertas

#### Dockerfile

| ID | Severidade | Descrição |
| -- | ---------- | --------- |
| DS001 | HIGH | Imagem base usando tag `latest` |
| DS002 | HIGH | Container rodando como root |
| DS005 | LOW | Uso de `ADD` ao invés de `COPY` |
| DS006 | LOW | Falta de `HEALTHCHECK` |
| DS012 | LOW | `apt-get` sem `--no-install-recommends` |
| DS013 | HIGH | Falta de instrução `USER` |
| DS014 | MEDIUM | Uso de `sudo` |
| DS026 | LOW | Exposição de porta privilegiada |

#### Kubernetes

| ID | Severidade | Descrição |
| -- | ---------- | --------- |
| KSV001 | HIGH | Container rodando como root |
| KSV003 | MEDIUM | Capabilities não dropadas |
| KSV006 | HIGH | `hostNetwork` habilitado |
| KSV009 | HIGH | `hostPID` habilitado |
| KSV010 | HIGH | `hostIPC` habilitado |
| KSV011 | MEDIUM | Limites de CPU não definidos |
| KSV013 | MEDIUM | Limites de memória não definidos |
| KSV014 | CRITICAL | Container privilegiado |
| KSV020 | HIGH | Falta de `runAsNonRoot` |
| KSV021 | HIGH | Falta de `securityContext` |

### Customização de Políticas (`trivy-policy.yaml`)

O arquivo `trivy-policy.yaml` controla quais severidades e scanners são ativados. Para ajustar:

```yaml
# Exemplo: reportar apenas CRITICAL e HIGH
severity:
  - CRITICAL
  - HIGH

# Exemplo: incluir apenas checks de Docker e Kubernetes
misconfig:
  include:
    - docker
    - kubernetes
```

### Output JSON

O step gera um relatório JSON com a seguinte estrutura:

```json
{
  "totalFindings": 5,
  "blockingFindings": 2,
  "counts": {
    "CRITICAL": 1,
    "HIGH": 1,
    "MEDIUM": 2,
    "LOW": 1
  },
  "severityThreshold": "HIGH",
  "byType": [
    {
      "type": "dockerfile",
      "count": 3,
      "findings": [...]
    },
    {
      "type": "kubernetes",
      "count": 2,
      "findings": [...]
    }
  ],
  "findings": [
    {
      "id": "DS002",
      "avdid": "AVD-DS-0002",
      "title": "Image user should not be 'root'",
      "description": "Running as root gives...",
      "severity": "HIGH",
      "resolution": "Add 'USER <non-root>' to Dockerfile",
      "target": "Dockerfile",
      "type": "dockerfile",
      "references": ["https://..."],
      "status": "FAIL"
    }
  ]
}
```

### Troubleshooting — Findings Comuns

#### Dockerfile: "Image user should not be root" (DS002/DS013)

```dockerfile
# PROBLEMA: Sem USER instruction
FROM node:18
COPY . /app
CMD ["node", "app.js"]

# SOLUÇÃO: Adicionar USER não-root
FROM node:18
COPY --chown=node:node . /app
USER node
CMD ["node", "app.js"]
```

#### Dockerfile: "Add instead of Copy" (DS005)

```dockerfile
# PROBLEMA: ADD pode baixar URLs e extrair tars automaticamente
ADD . /app

# SOLUÇÃO: Usar COPY (mais explícito e seguro)
COPY . /app
```

#### Dockerfile: "No HEALTHCHECK" (DS006)

```dockerfile
# SOLUÇÃO: Adicionar HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

#### Kubernetes: "Container is privileged" (KSV014 — CRITICAL)

```yaml
# PROBLEMA
securityContext:
  privileged: true

# SOLUÇÃO
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
```

#### Kubernetes: "No resource limits" (KSV011/KSV013)

```yaml
# SOLUÇÃO: Definir requests e limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

#### Kubernetes: "hostNetwork/hostPID/hostIPC" (KSV006/KSV009/KSV010)

```yaml
# PROBLEMA
spec:
  hostNetwork: true
  hostPID: true

# SOLUÇÃO: Remover ou setar como false
spec:
  hostNetwork: false
  hostPID: false
  hostIPC: false
```

### Testes

```bash
# Executar testes do Infra Scan
bash scanner/test/test-infra-scan.sh
```

Os testes cobrem os seguintes cenários:

| Cenário | Resultado Esperado |
| ------- | ------------------ |
| Dockerfile seguro | 0 findings bloqueantes, step passa |
| Dockerfile inseguro | Findings reportadas, bloqueio conforme severity |
| K8s sem securityContext | Finding CRITICAL/HIGH |
| Compose com privileged | Findings HIGH |
| Sem arquivos IaC | Step ignorado graciosamente |
| Step desativado | Step não executa |
| Severity threshold CRITICAL vs MEDIUM | Bloqueio proporcional ao threshold |
| Validação do schema JSON | Output contém todos os campos obrigatórios |
