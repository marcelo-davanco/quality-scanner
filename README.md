# Quality Scanner

> 🌐 **Translations:** [Português](./README.pt-BR.md) · [中文](./README.zh-CN.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/marcelo-davanco/quality-scanner)](https://github.com/marcelo-davanco/quality-scanner/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/marcelo-davanco/quality-scanner/ci.yml?branch=develop&label=CI)](https://github.com/marcelo-davanco/quality-scanner/actions/workflows/ci.yml)

An **Nx monorepo** that provides a complete code quality pipeline for NestJS/TypeScript projects. Powered by SonarQube Community Edition with the [Community Branch Plugin](./docs/community-branch-plugin.md), it runs 10 automated analysis steps — from secret detection to infrastructure security — and persists all results in a PostgreSQL database via a dedicated REST API.

## Architecture

```
quality-scanner/ (Nx Monorepo)
├── apps/scanner/     Docker-based 10-step quality pipeline
├── apps/api/         NestJS REST API + TypeORM + PostgreSQL
└── apps/dashboard/   Next.js results dashboard
```

### Services (docker compose)

| Service      | Description                                    | Port  |
|--------------|------------------------------------------------|-------|
| `sonarqube`  | SonarQube Community Edition                    | 9000  |
| `db`         | PostgreSQL for SonarQube                       | 5432  |
| `api-db`     | PostgreSQL for the Quality Scanner API         | 5433  |
| `liquibase`  | Runs DB migrations before the API starts       | —     |
| `api`        | NestJS REST API (projects, scans, profiles)    | 3001  |
| `scanner`    | 10-step analysis pipeline (on-demand)          | —     |

---

## Prerequisites

- **Docker** and **Docker Compose**
- **Git**

> ⚠️ On macOS/Linux, increase the virtual memory limit required by SonarQube:
>
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```
>
> On **macOS with Colima**, start with at least 6 GB of memory:
>
> ```bash
> colima start --memory 6 --cpu 4
> ```

---

## Quick Start

### 1. Configure environment variables

```bash
cp .env.example .env
```

Key variables to set:

| Variable               | Description                                         |
|------------------------|-----------------------------------------------------|
| `SONAR_ADMIN_PASSWORD` | SonarQube admin password (change after first login) |
| `SONAR_DB_PASSWORD`    | PostgreSQL password for SonarQube                   |
| `API_DB_PASSWORD`      | PostgreSQL password for the API database            |

> **Note:** `SONAR_TOKEN` is generated automatically by `scan.sh`. Leave it empty.

### 2. Start all services

```bash
docker compose up -d
```

This starts SonarQube, the API database, runs Liquibase migrations, and starts the API.

- **SonarQube:** [http://localhost:9000](http://localhost:9000) — default login `admin` / `admin`
- **API:** [http://localhost:3001/api/docs](http://localhost:3001/api/docs) — Swagger UI
- **Dashboard:** [http://localhost:3000](http://localhost:3000)

### 3. Add `sonar-project-localhost.properties` to your project

```properties
sonar.projectKey=my-project
sonar.projectName=my-project
sonar.projectVersion=1.0.0
sonar.language=ts
sonar.sourceEncoding=UTF-8
sonar.sources=src/
sonar.exclusions=**/node_modules/**,**/dist/**,**/*.spec.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.qualitygate.wait=false
sonar.scm.disabled=true
```

### 4. Run the scanner

```bash
./scan.sh /path/to/your/project
```

The scanner will:
1. Start SonarQube if not running
2. Generate a fresh token
3. Create the project in SonarQube if it doesn't exist
4. **Register the scan in the API** and fetch quality profile configs
5. Run all 10 analysis steps
6. **Report each phase result to the API**
7. Save JSON reports to `./reports/<date>/<scan-id>/`
8. **Finalize the scan record in the API** with status and metrics

### 5. View results

- **Dashboard:** [http://localhost:3000](http://localhost:3000)
- **API Swagger:** [http://localhost:3001/api/docs](http://localhost:3001/api/docs)
- **SonarQube:** `http://localhost:9000/dashboard?id=<project-key>`
- **Local reports:** `./reports/`

---

## Analysis Steps

| Step | Tool           | What it checks                                    | Default  |
|------|----------------|---------------------------------------------------|----------|
| 1    | **Gitleaks**   | Hardcoded secrets and credentials                 | enabled  |
| 2    | **TypeScript** | Compilation errors                                | enabled  |
| 3    | **ESLint**     | Code quality rules                                | enabled  |
| 4    | **Prettier**   | Code formatting                                   | enabled  |
| 5    | **npm audit**  | Dependency vulnerabilities                        | enabled  |
| 6    | **Knip**       | Dead code (unused exports, files, deps)           | enabled  |
| 7    | **Jest**       | Tests + coverage                                  | enabled  |
| 8    | **SonarQube**  | Static analysis + quality gate                    | enabled  |
| 9    | **Spectral**   | OpenAPI contract validation                       | disabled |
| 10   | **Trivy**      | Infrastructure security (IaC)                     | disabled |

### Enabling/disabling steps

Each step can be toggled via environment variable:

```bash
ENABLE_GITLEAKS=true
ENABLE_TYPESCRIPT=true
ENABLE_ESLINT=true
ENABLE_PRETTIER=true
ENABLE_AUDIT=true
ENABLE_KNIP=true
ENABLE_JEST=true
ENABLE_SONARQUBE=true
ENABLE_API_LINT=false    # Step 9 — disabled by default
ENABLE_INFRA_SCAN=false  # Step 10 — disabled by default
```

---

## Quality Profiles

Quality Profiles allow you to define reusable sets of config files (ESLint, Prettier, TypeScript, Gitleaks, etc.) and assign them to projects. When a scan runs, the scanner fetches the assigned profile's configs from the API and applies them automatically.

### Managing profiles

1. Open the dashboard at [http://localhost:3000/quality-profiles](http://localhost:3000/quality-profiles)
2. Create a profile (e.g. "Strict Frontend")
3. Add config items — each item is a tool name, filename, and full file content
4. Link the profile to one or more projects

### How it works

```
Quality Profile "Strict Frontend"
  ├── .eslintrc.js        (custom ESLint rules)
  ├── .prettierrc          (custom Prettier config)
  └── tsconfig.strict.json (custom TypeScript config)

Project A ──→ "Strict Frontend"
Project B ──→ "Strict Frontend"
Project C ──→ "Backend Standard"
```

When the scanner runs for a project that has a profile assigned, it calls `GET /api/projects/configs/:key` and overwrites the static config files in the container before the phases execute. If no profile is assigned, the static files from `quality-configs/` are used as fallback.

---

## REST API

The API is available at `http://localhost:3001/api` with full Swagger documentation at `/api/docs`.

### Endpoints

| Resource           | Endpoints                                                    |
|--------------------|--------------------------------------------------------------|
| **Projects**       | `POST/GET /projects` · `GET/PATCH/DELETE /projects/:id`      |
| **Scans**          | `POST /projects/:id/scans` · `GET/PATCH /scans/:id`          |
| **Phase Results**  | `POST/GET /scans/:id/phases`                                 |
| **Quality Profiles** | `POST/GET /quality-profiles` · `GET/PATCH/DELETE /quality-profiles/:id` |
| **Config Items**   | `POST/GET /quality-profiles/:id/configs` · `PATCH/DELETE /quality-profiles/configs/:itemId` |
| **Scanner Config** | `GET /projects/configs/:key` *(used by scanner)*             |

### Database schema

```
projects ──→ quality_profiles ──→ quality_config_items
    │
    └──→ scans ──→ phase_results
```

Schema is managed by **Liquibase** — migrations run automatically on startup via the `liquibase` Docker service.

---

## Branch and Pull Request Analysis

```bash
# Branch analysis
SONAR_BRANCH_NAME=feature/my-branch ./scan.sh /path/to/project

# Pull request analysis
SONAR_PR_KEY=42 \
SONAR_PR_BRANCH=feature/my-branch \
SONAR_PR_BASE=main \
./scan.sh /path/to/project
```

---

## Dashboard

The Next.js dashboard connects to the API and provides:

| Page                              | Description                                      |
|-----------------------------------|--------------------------------------------------|
| `/projects`                       | List all registered projects                     |
| `/projects/:id`                   | Project detail, scan history, profile assignment |
| `/projects/:id/scans/:scanId`     | Scan detail with per-phase results               |
| `/quality-profiles`               | List and create quality profiles                 |
| `/quality-profiles/:id`           | Manage config items, link/unlink projects        |

---

## Project Structure

```text
quality-scanner/                    # Nx Monorepo root
├── apps/
│   ├── scanner/                    # Docker-based quality pipeline
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh           # 10-step pipeline
│   │   ├── configs/                # Static fallback configs
│   │   └── scripts/                # swagger-lint.sh, infra-scan.sh
│   ├── api/                        # NestJS REST API
│   │   ├── src/
│   │   │   ├── modules/
│   │   │   │   ├── projects/       # Project CRUD
│   │   │   │   ├── scans/          # Scan + PhaseResult
│   │   │   │   └── quality-profiles/ # Profile + ConfigItem CRUD
│   │   │   └── config/             # DB config, data-source
│   │   ├── liquibase/              # Liquibase changelogs
│   │   │   └── changelogs/
│   │   │       ├── v1.0.0/         # Initial schema
│   │   │       └── v1.1.0/         # Quality profiles
│   │   └── Dockerfile
│   └── dashboard/                  # Next.js dashboard
│       ├── app/
│       │   ├── projects/           # Projects pages
│       │   └── quality-profiles/   # Quality profiles pages
│       └── lib/api.ts              # API client
├── docker-compose.yml              # All services
├── scan.sh                         # Scanner wrapper
├── nx.json                         # Nx workspace config
├── package.json                    # Workspace root
├── tsconfig.base.json              # Shared TS config
├── quality-configs/                # Static quality configs (fallback)
├── .env.example
└── README.md
```

---

## Useful Commands

| Command                                    | Description                          |
|--------------------------------------------|--------------------------------------|
| `docker compose up -d`                     | Start all services                   |
| `docker compose down`                      | Stop all services                    |
| `docker compose down -v`                   | Stop and remove all data             |
| `docker compose logs -f api`               | View API logs                        |
| `docker compose logs -f sonarqube`         | View SonarQube logs                  |
| `./scan.sh /path/to/project`               | Run full analysis                    |
| `npx nx build api`                         | Build the API                        |
| `npx nx serve api`                         | Run API in dev mode                  |
| `npx nx dev dashboard`                     | Run dashboard in dev mode            |

---

## Troubleshooting

### SonarQube does not start

```bash
docker compose logs sonarqube
sudo sysctl -w vm.max_map_count=524288
```

### API does not start

```bash
docker compose logs api
docker compose logs liquibase   # Check if migrations ran successfully
```

### Scanner cannot connect to API

Ensure `API_URL=http://api:3001` is set in the scanner environment (already configured in `docker-compose.yml`). If running the scanner outside Docker, set `API_URL=http://localhost:3001`.

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting a pull request.

## License

[MIT](./LICENSE)
