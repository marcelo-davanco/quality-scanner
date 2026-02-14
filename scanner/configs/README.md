# Scanner Configs — Guia de Configuração

Este diretório contém todas as configurações centralizadas do Quality Scanner, embutidas no container Docker.

## Arquivos

| Arquivo | Propósito |
| ------- | --------- |
| `.eslintrc.js` | Regras de qualidade ESLint (TypeScript) |
| `.prettierrc` | Formatação de código |
| `.gitleaks.toml` | Detecção de secrets |
| `.spectral.yml` | Validação de contratos OpenAPI/Swagger |
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
