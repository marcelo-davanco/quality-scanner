# Quality Scanner

> 🌐 **Traduções:** [English](./README.md) · [中文](./README.zh-CN.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

Pipeline de qualidade de código baseado em Docker para projetos NestJS/TypeScript, com SonarQube Community Edition. Executa 10 etapas de análise automatizadas — da detecção de segredos à segurança de infraestrutura — e gera um relatório JSON por varredura.

## Pré-requisitos

- **Docker** e **Docker Compose**
- **Node.js** >= 18
- **npm** ou **yarn**

> ⚠️ No macOS/Linux, aumente o limite de memória virtual exigido pelo SonarQube:
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```

## Início Rápido

### 1. Configurar variáveis de ambiente

```bash
cp .env.example .env
```

Edite o `.env` e preencha seus valores. A única alteração obrigatória para a primeira execução é o `SONAR_TOKEN` (veja o passo 2).

### 2. Iniciar o SonarQube

```bash
docker compose up -d
```

Aguarde ~1 minuto para o SonarQube iniciar e acesse **http://localhost:9000**.

- **Login padrão:** `admin` / `admin`
- Você será solicitado a alterar a senha no primeiro acesso.

### 3. Gerar um Token de Acesso

1. Acesse **My Account** → **Security** → **Generate Tokens**
2. Crie um token do tipo **Project Analysis Token**
3. Copie o token e defina no `.env`:

```env
SONAR_TOKEN=seu_token_aqui
```

### 4. Executar o Scanner

```bash
# Varrer o diretório atual
./scan.sh .

# Varrer qualquer projeto Node.js/NestJS
./scan.sh /caminho/para/seu/projeto
```

O container do scanner irá:

1. Instalar as dependências do projeto
2. Executar as 10 etapas de análise
3. Salvar os relatórios JSON em `./reports/<data>/<scan-id>/`

### 5. Visualizar Resultados

- **Dashboard SonarQube:** http://localhost:9000/dashboard?id=seu-projeto
- **Relatórios locais:** `./reports/`

---

## Etapas de Análise

| Etapa | Ferramenta | O que verifica |
|-------|------------|----------------|
| 1 | **Gitleaks** | Segredos e credenciais no código |
| 2 | **TypeScript** | Erros de compilação |
| 3 | **ESLint** | Regras de qualidade de código (config centralizada) |
| 4 | **Prettier** | Formatação de código (config centralizada) |
| 5 | **npm audit** | Vulnerabilidades em dependências |
| 6 | **Knip** | Código morto (exports, arquivos, deps não usados) |
| 7 | **Jest** | Testes + cobertura |
| 8 | **SonarQube** | Análise estática + quality gate |
| 9 | **Spectral** | Validação de contrato OpenAPI *(opcional)* |
| 10 | **Trivy** | Segurança de infraestrutura (IaC) *(opcional)* |

---

## Quality Gate Local (Pré-Push)

Execute as mesmas verificações localmente antes de fazer push:

```bash
chmod +x quality-gate.sh
./quality-gate.sh
```

---

## API Lint — Validação de Contrato OpenAPI (Etapa 9)

Valida contratos OpenAPI/Swagger usando **Spectral**.

### Ativação

```bash
# Via variável de ambiente
ENABLE_API_LINT=true ./scan.sh /caminho/para/projeto

# Via docker-compose
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### O que é validado

- Todas as rotas têm resposta `400` mapeada
- Paths usam `kebab-case` (ex: `/meu-recurso`)
- Propriedades de schema usam `camelCase`
- Toda operação tem `operationId`, `description`, `summary` e `tags`
- Paths não terminam com `/`
- Respostas `200`/`201` têm `content` definido

### Configuração

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `ENABLE_API_LINT` | `false` | Habilitar/desabilitar esta etapa |
| `API_LINT_SEVERITY` | `warn` | `warn` = apenas reportar, `error` = bloquear pipeline |
| `OPENAPI_FILE_PATH` | *(auto-detect)* | Caminho manual para o arquivo OpenAPI |

O arquivo OpenAPI é detectado automaticamente (`swagger.json`, `openapi.yaml`, etc.). Para personalizar as regras, edite `scanner/configs/.spectral.yml`. Veja o guia completo em [`scanner/configs/README.md`](./scanner/configs/README.md).

---

## Infra Scan — Segurança de Infraestrutura (Etapa 10)

Varre `Dockerfile`, `docker-compose.yml` e manifestos Kubernetes usando **Trivy**.

### Ativação

```bash
# Via variável de ambiente
ENABLE_INFRA_SCAN=true ./scan.sh /caminho/para/projeto

# Via docker-compose
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### O que é varrido

| Tipo | Arquivos detectados | Exemplos de problemas |
|------|--------------------|-----------------------|
| **Dockerfile** | `Dockerfile`, `Dockerfile.*` | tag `latest`, sem `USER`, sem `HEALTHCHECK`, uso de `ADD` |
| **docker-compose** | `docker-compose.yml`, `compose.yaml` | `privileged: true`, portas expostas, volumes perigosos |
| **Kubernetes** | `deployment.yaml`, `service.yaml`, etc. | `hostNetwork`, `securityContext` ausente, sem limites de recursos |

### Configuração

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `ENABLE_INFRA_SCAN` | `false` | Habilitar/desabilitar esta etapa |
| `INFRA_SCAN_SEVERITY` | `HIGH` | Severidade mínima de bloqueio: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `SCAN_DOCKERFILE` | `true` | Habilitar varredura de Dockerfile |
| `SCAN_K8S` | `true` | Habilitar varredura de manifestos Kubernetes |
| `SCAN_COMPOSE` | `true` | Habilitar varredura de docker-compose |

Para personalizar as políticas de segurança, edite `scanner/configs/trivy-policy.yaml`. Veja o guia completo em [`scanner/configs/README.md`](./scanner/configs/README.md).

---

## Comandos Úteis

| Comando | Descrição |
|---------|-----------|
| `docker compose up -d` | Iniciar SonarQube |
| `docker compose down` | Parar SonarQube |
| `docker compose down -v` | Parar e remover todos os dados |
| `docker compose logs -f sonarqube` | Ver logs do SonarQube |
| `./scan.sh /caminho/para/projeto` | Executar análise completa |
| `./quality-gate.sh` | Executar verificações locais pré-push |

---

## Estrutura do Projeto

```text
quality-scanner/
├── docker-compose.yml          # SonarQube + PostgreSQL + Scanner
├── sonar-project.properties    # Configuração do scanner
├── quality-gate.sh             # Quality gate local pré-push
├── run-sonar.sh                # Script standalone de análise SonarQube
├── scan.sh                     # Wrapper Docker do scanner
├── .env.example                # Template de variáveis de ambiente
├── scanner/
│   ├── Dockerfile              # Imagem do scanner
│   ├── entrypoint.sh           # Pipeline de 10 etapas (container)
│   ├── configs/
│   │   ├── .eslintrc.js        # Regras ESLint centralizadas
│   │   ├── .prettierrc         # Config de formatação Prettier
│   │   ├── .gitleaks.toml      # Regras de detecção de segredos
│   │   ├── .spectral.yml       # Regras OpenAPI/Swagger
│   │   ├── trivy-policy.yaml   # Políticas de segurança Trivy
│   │   └── README.md           # Guia de configuração
│   ├── scripts/
│   │   ├── swagger-lint.sh     # Script de lint OpenAPI
│   │   └── infra-scan.sh       # Script de segurança de infraestrutura
│   └── test/
│       ├── fixtures/           # Fixtures seguras/inseguras para testes
│       ├── test-api-lint.sh    # Testes do API Lint
│       └── test-infra-scan.sh  # Testes do Infra Scan
├── quality-configs/            # Configs do quality gate local
├── dashboard/                  # Dashboard de resultados (Next.js)
├── example-nestjs/             # Projeto NestJS de exemplo
├── .gitignore
├── LICENSE
└── README.md
```

---

## Solução de Problemas

### SonarQube não inicia

```bash
# Verificar logs
docker compose logs sonarqube

# Correção comum no Linux/macOS — aumentar vm.max_map_count
sudo sysctl -w vm.max_map_count=524288
```

### Erro de memória insuficiente

Adicione ao serviço `sonarqube` no `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 2g
```

### Scanner não encontra arquivos

Certifique-se de que `sonar-project.properties` está na raiz do projeto e que todos os caminhos estão corretos.

---

## Contribuindo

Contribuições são bem-vindas! Leia o [CONTRIBUTING.md](./CONTRIBUTING.md) antes de abrir um pull request.

## Licença

[MIT](./LICENSE)
