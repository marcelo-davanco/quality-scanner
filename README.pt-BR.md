# Quality Scanner

> 🌐 **Traduções:** [English](./README.md) · [中文](./README.zh-CN.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/marcelo-davanco/quality-scanner)](https://github.com/marcelo-davanco/quality-scanner/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/marcelo-davanco/quality-scanner/ci.yml?branch=develop&label=CI)](https://github.com/marcelo-davanco/quality-scanner/actions/workflows/ci.yml)

Um **monorepo Nx** que fornece um pipeline completo de qualidade de código para projetos NestJS/TypeScript. Alimentado pelo SonarQube Community Edition com o [Community Branch Plugin](./docs/community-branch-plugin.md), executa 10 etapas de análise automatizadas — da detecção de segredos à segurança de infraestrutura — e persiste todos os resultados em um banco de dados PostgreSQL via uma API REST dedicada.

## Arquitetura

```
quality-scanner/ (Monorepo Nx)
├── apps/scanner/     Pipeline de qualidade em Docker com 10 etapas
├── apps/api/         API REST NestJS + TypeORM + PostgreSQL
└── apps/dashboard/   Dashboard de resultados em Next.js
```

### Serviços (docker compose)

| Serviço      | Descrição                                           | Porta |
|--------------|-----------------------------------------------------|-------|
| `sonarqube`  | SonarQube Community Edition                         | 9000  |
| `db`         | PostgreSQL para o SonarQube                         | 5432  |
| `api-db`     | PostgreSQL para a API do Quality Scanner            | 5433  |
| `liquibase`  | Executa as migrations antes da API iniciar          | —     |
| `api`        | API REST NestJS (projetos, scans, perfis)           | 3001  |
| `scanner`    | Pipeline de análise de 10 etapas (sob demanda)      | —     |

---

## Pré-requisitos

- **Docker** e **Docker Compose**
- **Git**

> ⚠️ No macOS/Linux, aumente o limite de memória virtual exigido pelo SonarQube:
>
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```
>
> No **macOS com Colima**, inicie com pelo menos 6 GB de memória:
>
> ```bash
> colima start --memory 6 --cpu 4
> ```

---

## Início Rápido

### 1. Configurar variáveis de ambiente

```bash
cp .env.example .env
```

Variáveis principais a definir:

| Variável               | Descrição                                              |
|------------------------|--------------------------------------------------------|
| `SONAR_ADMIN_PASSWORD` | Senha do admin do SonarQube (alterar no primeiro login)|
| `SONAR_DB_PASSWORD`    | Senha do PostgreSQL para o SonarQube                   |
| `API_DB_PASSWORD`      | Senha do PostgreSQL para o banco da API                |

> **Nota:** `SONAR_TOKEN` é gerado automaticamente pelo `scan.sh`. Deixe em branco.

### 2. Iniciar todos os serviços

```bash
docker compose up -d
```

Isso inicia o SonarQube, o banco da API, executa as migrations do Liquibase e sobe a API.

- **SonarQube:** [http://localhost:9000](http://localhost:9000) — login padrão `admin` / `admin`
- **API:** [http://localhost:3001/api/docs](http://localhost:3001/api/docs) — Swagger UI
- **Dashboard:** [http://localhost:3000](http://localhost:3000)

### 3. Adicionar `sonar-project-localhost.properties` ao seu projeto

```properties
sonar.projectKey=meu-projeto
sonar.projectName=meu-projeto
sonar.projectVersion=1.0.0
sonar.language=ts
sonar.sourceEncoding=UTF-8
sonar.sources=src/
sonar.exclusions=**/node_modules/**,**/dist/**,**/*.spec.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.qualitygate.wait=false
sonar.scm.disabled=true
```

### 4. Executar o scanner

```bash
./scan.sh /caminho/para/seu/projeto
```

O scanner irá:
1. Iniciar o SonarQube se não estiver rodando
2. Gerar um token de acesso
3. Criar o projeto no SonarQube se não existir
4. **Registrar o scan na API** e buscar configs do perfil de qualidade
5. Executar as 10 etapas de análise
6. **Reportar cada resultado de fase à API**
7. Salvar relatórios JSON em `./reports/<data>/<scan-id>/`
8. **Finalizar o registro do scan na API** com status e métricas

### 5. Visualizar resultados

- **Dashboard:** [http://localhost:3000](http://localhost:3000)
- **API Swagger:** [http://localhost:3001/api/docs](http://localhost:3001/api/docs)
- **SonarQube:** `http://localhost:9000/dashboard?id=<project-key>`
- **Relatórios locais:** `./reports/`

---

## Etapas de Análise

| Etapa | Ferramenta     | O que verifica                                    | Padrão     |
|-------|----------------|---------------------------------------------------|------------|
| 1     | **Gitleaks**   | Segredos e credenciais no código                  | habilitado |
| 2     | **TypeScript** | Erros de compilação                               | habilitado |
| 3     | **ESLint**     | Regras de qualidade de código                     | habilitado |
| 4     | **Prettier**   | Formatação de código                              | habilitado |
| 5     | **npm audit**  | Vulnerabilidades em dependências                  | habilitado |
| 6     | **Knip**       | Código morto (exports, arquivos, deps não usados) | habilitado |
| 7     | **Jest**       | Testes + cobertura                                | habilitado |
| 8     | **SonarQube**  | Análise estática + quality gate                   | habilitado |
| 9     | **Spectral**   | Validação de contrato OpenAPI                     | desabilitado |
| 10    | **Trivy**      | Segurança de infraestrutura (IaC)                 | desabilitado |

### Habilitando/desabilitando etapas

Cada etapa pode ser controlada via variável de ambiente:

```bash
ENABLE_GITLEAKS=true
ENABLE_TYPESCRIPT=true
ENABLE_ESLINT=true
ENABLE_PRETTIER=true
ENABLE_AUDIT=true
ENABLE_KNIP=true
ENABLE_JEST=true
ENABLE_SONARQUBE=true
ENABLE_API_LINT=false    # Etapa 9 — desabilitada por padrão
ENABLE_INFRA_SCAN=false  # Etapa 10 — desabilitada por padrão
```

---

## Perfis de Qualidade

Os Perfis de Qualidade permitem definir conjuntos reutilizáveis de arquivos de configuração (ESLint, Prettier, TypeScript, Gitleaks, etc.) e associá-los a projetos. Quando um scan é executado, o scanner busca as configs do perfil atribuído via API e as aplica automaticamente.

### Gerenciando perfis

1. Acesse o dashboard em [http://localhost:3000/quality-profiles](http://localhost:3000/quality-profiles)
2. Crie um perfil (ex: "Strict Frontend")
3. Adicione itens de configuração — cada item é um nome de ferramenta, nome de arquivo e conteúdo completo
4. Vincule o perfil a um ou mais projetos

### Como funciona

```
Perfil de Qualidade "Strict Frontend"
  ├── .eslintrc.js        (regras ESLint customizadas)
  ├── .prettierrc          (config Prettier customizada)
  └── tsconfig.strict.json (config TypeScript customizada)

Projeto A ──→ "Strict Frontend"
Projeto B ──→ "Strict Frontend"
Projeto C ──→ "Backend Standard"
```

Quando o scanner executa para um projeto com perfil atribuído, chama `GET /api/projects/configs/:key` e sobrescreve os arquivos de config estáticos no container antes das fases executarem. Se nenhum perfil estiver atribuído, os arquivos estáticos de `quality-configs/` são usados como fallback.

---

## API REST

A API está disponível em `http://localhost:3001/api` com documentação Swagger completa em `/api/docs`.

### Endpoints

| Recurso              | Endpoints                                                            |
|----------------------|----------------------------------------------------------------------|
| **Projetos**         | `POST/GET /projects` · `GET/PATCH/DELETE /projects/:id`              |
| **Scans**            | `POST /projects/:id/scans` · `GET/PATCH /scans/:id`                  |
| **Resultados**       | `POST/GET /scans/:id/phases`                                         |
| **Perfis**           | `POST/GET /quality-profiles` · `GET/PATCH/DELETE /quality-profiles/:id` |
| **Itens de Config**  | `POST/GET /quality-profiles/:id/configs` · `PATCH/DELETE /quality-profiles/configs/:itemId` |
| **Config Scanner**   | `GET /projects/configs/:key` *(usado pelo scanner)*                  |

### Schema do banco

```
projects ──→ quality_profiles ──→ quality_config_items
    │
    └──→ scans ──→ phase_results
```

O schema é gerenciado pelo **Liquibase** — as migrations são executadas automaticamente na inicialização via o serviço Docker `liquibase`.

---

## Análise de Branch e Pull Request

```bash
# Análise de branch
SONAR_BRANCH_NAME=feature/minha-branch ./scan.sh /caminho/para/projeto

# Análise de pull request
SONAR_PR_KEY=42 \
SONAR_PR_BRANCH=feature/minha-branch \
SONAR_PR_BASE=main \
./scan.sh /caminho/para/projeto
```

---

## Dashboard

O dashboard Next.js conecta-se à API e fornece:

| Página                              | Descrição                                          |
|-------------------------------------|----------------------------------------------------|
| `/projects`                         | Lista todos os projetos cadastrados                |
| `/projects/:id`                     | Detalhe do projeto, histórico de scans, perfil     |
| `/projects/:id/scans/:scanId`       | Detalhe do scan com resultados por fase            |
| `/quality-profiles`                 | Listar e criar perfis de qualidade                 |
| `/quality-profiles/:id`             | Gerenciar itens de config, vincular projetos       |

---

## Estrutura do Projeto

```text
quality-scanner/                    # Raiz do Monorepo Nx
├── apps/
│   ├── scanner/                    # Pipeline de qualidade em Docker
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh           # Pipeline de 10 etapas
│   │   ├── configs/                # Configs estáticas de fallback
│   │   └── scripts/                # swagger-lint.sh, infra-scan.sh
│   ├── api/                        # API REST NestJS
│   │   ├── src/
│   │   │   ├── modules/
│   │   │   │   ├── projects/       # CRUD de projetos
│   │   │   │   ├── scans/          # Scan + PhaseResult
│   │   │   │   └── quality-profiles/ # CRUD de perfis + configs
│   │   │   └── config/             # Config do banco, data-source
│   │   ├── liquibase/              # Changelogs do Liquibase
│   │   │   └── changelogs/
│   │   │       ├── v1.0.0/         # Schema inicial
│   │   │       └── v1.1.0/         # Perfis de qualidade
│   │   └── Dockerfile
│   └── dashboard/                  # Dashboard Next.js
│       ├── app/
│       │   ├── projects/           # Páginas de projetos
│       │   └── quality-profiles/   # Páginas de perfis
│       └── lib/api.ts              # Cliente da API
├── docker-compose.yml              # Todos os serviços
├── scan.sh                         # Wrapper do scanner
├── nx.json                         # Config do workspace Nx
├── package.json                    # Raiz do workspace
├── tsconfig.base.json              # Config TS compartilhada
├── quality-configs/                # Configs estáticas de qualidade (fallback)
├── .env.example
└── README.md
```

---

## Comandos Úteis

| Comando                                    | Descrição                              |
|--------------------------------------------|----------------------------------------|
| `docker compose up -d`                     | Iniciar todos os serviços              |
| `docker compose down`                      | Parar todos os serviços                |
| `docker compose down -v`                   | Parar e remover todos os dados         |
| `docker compose logs -f api`               | Ver logs da API                        |
| `docker compose logs -f sonarqube`         | Ver logs do SonarQube                  |
| `./scan.sh /caminho/para/projeto`          | Executar análise completa              |
| `npx nx build api`                         | Compilar a API                         |
| `npx nx serve api`                         | Rodar API em modo dev                  |
| `npx nx dev dashboard`                     | Rodar dashboard em modo dev            |

---

## Solução de Problemas

### SonarQube não inicia

```bash
docker compose logs sonarqube
sudo sysctl -w vm.max_map_count=524288
```

### API não inicia

```bash
docker compose logs api
docker compose logs liquibase   # Verificar se as migrations rodaram
```

### Scanner não conecta à API

Certifique-se de que `API_URL=http://api:3001` está definido no ambiente do scanner (já configurado no `docker-compose.yml`). Se rodar o scanner fora do Docker, defina `API_URL=http://localhost:3001`.

---

## Contribuindo

Contribuições são bem-vindas! Leia o [CONTRIBUTING.md](./CONTRIBUTING.md) antes de abrir um pull request.

## Licença

[MIT](./LICENSE)
