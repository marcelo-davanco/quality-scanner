# Quality Scanner

> 🌐 **Translations:** [Português](./README.pt-BR.md) · [中文](./README.zh-CN.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/marcelo-davanco/quality-scanner)](https://github.com/marcelo-davanco/quality-scanner/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/marcelo-davanco/quality-scanner/ci.yml?branch=develop&label=CI)](https://github.com/marcelo-davanco/quality-scanner/actions/workflows/ci.yml)

Docker-based code quality pipeline for NestJS/TypeScript projects, powered by SonarQube Community Edition. Runs 10 automated analysis steps — from secret detection to infrastructure security — and generates a JSON report for each scan.

## Prerequisites

- **Docker** and **Docker Compose**
- **Node.js** >= 18
- **npm** or **yarn**

> ⚠️ On macOS/Linux, increase the virtual memory limit required by SonarQube:
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```

## Quick Start

### 1. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in your values. The only required change for a first run is `SONAR_TOKEN` (see step 2).

### 2. Start SonarQube

```bash
docker compose up -d
```

Wait ~1 minute for SonarQube to start, then open **http://localhost:9000**.

- **Default login:** `admin` / `admin`
- You will be prompted to change the password on first login.

### 3. Generate an Access Token

1. Go to **My Account** → **Security** → **Generate Tokens**
2. Create a token of type **Project Analysis Token**
3. Copy the token and set it in `.env`:

```env
SONAR_TOKEN=your_token_here
```

### 4. Run the Scanner

```bash
# Scan the current directory
./scan.sh .

# Scan any Node.js/NestJS project
./scan.sh /path/to/your/project
```

The scanner container will:

1. Install project dependencies
2. Run all 10 analysis steps
3. Save JSON reports to `./reports/<date>/<scan-id>/`

### 5. View Results

- **SonarQube dashboard:** http://localhost:9000/dashboard?id=your-project
- **Local reports:** `./reports/`

---

## Analysis Steps

| Step | Tool | What it checks |
|------|------|----------------|
| 1 | **Gitleaks** | Hardcoded secrets and credentials |
| 2 | **TypeScript** | Compilation errors |
| 3 | **ESLint** | Code quality rules (centralized config) |
| 4 | **Prettier** | Code formatting (centralized config) |
| 5 | **npm audit** | Dependency vulnerabilities |
| 6 | **Knip** | Dead code (unused exports, files, deps) |
| 7 | **Jest** | Tests + coverage |
| 8 | **SonarQube** | Static analysis + quality gate |
| 9 | **Spectral** | OpenAPI contract validation *(optional)* |
| 10 | **Trivy** | Infrastructure security (IaC) *(optional)* |

---

## Local Pre-Push Quality Gate

Run the same checks locally before pushing:

```bash
chmod +x quality-gate.sh
./quality-gate.sh
```

---

## API Lint — OpenAPI Contract Validation (Step 9)

Validates OpenAPI/Swagger contracts using **Spectral**.

### Activation

```bash
# Via environment variable
ENABLE_API_LINT=true ./scan.sh /path/to/project

# Via docker-compose
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### What is validated

- All routes have a `400` response mapped
- Paths use `kebab-case` (e.g. `/my-resource`)
- Schema properties use `camelCase`
- Every operation has `operationId`, `description`, `summary`, and `tags`
- Paths do not end with `/`
- `200`/`201` responses have `content` defined

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_API_LINT` | `false` | Enable/disable this step |
| `API_LINT_SEVERITY` | `warn` | `warn` = report only, `error` = block pipeline |
| `OPENAPI_FILE_PATH` | *(auto-detect)* | Manual path to the OpenAPI file |

The OpenAPI file is auto-detected (`swagger.json`, `openapi.yaml`, etc.). To customize rules, edit `scanner/configs/.spectral.yml`. See the full guide in [`scanner/configs/README.md`](./scanner/configs/README.md).

---

## Infra Scan — Infrastructure Security (Step 10)

Scans `Dockerfile`, `docker-compose.yml`, and Kubernetes manifests using **Trivy**.

### Activation

```bash
# Via environment variable
ENABLE_INFRA_SCAN=true ./scan.sh /path/to/project

# Via docker-compose
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### What is scanned

| Type | Detected Files | Example Findings |
|------|----------------|------------------|
| **Dockerfile** | `Dockerfile`, `Dockerfile.*` | `latest` image tag, no `USER`, no `HEALTHCHECK`, use of `ADD` |
| **docker-compose** | `docker-compose.yml`, `compose.yaml` | `privileged: true`, exposed ports, dangerous volumes |
| **Kubernetes** | `deployment.yaml`, `service.yaml`, etc. | `hostNetwork`, missing `securityContext`, no resource limits |

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_INFRA_SCAN` | `false` | Enable/disable this step |
| `INFRA_SCAN_SEVERITY` | `HIGH` | Minimum blocking severity: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `SCAN_DOCKERFILE` | `true` | Enable Dockerfile scanning |
| `SCAN_K8S` | `true` | Enable Kubernetes manifest scanning |
| `SCAN_COMPOSE` | `true` | Enable docker-compose scanning |

To customize security policies, edit `scanner/configs/trivy-policy.yaml`. See the full guide in [`scanner/configs/README.md`](./scanner/configs/README.md).

---

## Useful Commands

| Command | Description |
|---------|-------------|
| `docker compose up -d` | Start SonarQube |
| `docker compose down` | Stop SonarQube |
| `docker compose down -v` | Stop and remove all data |
| `docker compose logs -f sonarqube` | View SonarQube logs |
| `./scan.sh /path/to/project` | Run full analysis |
| `./quality-gate.sh` | Run local pre-push checks |

---

## Project Structure

```text
quality-scanner/
├── docker-compose.yml          # SonarQube + PostgreSQL + Scanner
├── sonar-project.properties    # Scanner configuration
├── quality-gate.sh             # Local pre-push quality gate
├── run-sonar.sh                # Standalone SonarQube analysis script
├── scan.sh                     # Docker scanner wrapper
├── .env.example                # Environment variable template
├── scanner/
│   ├── Dockerfile              # Scanner image
│   ├── entrypoint.sh           # 10-step pipeline (container)
│   ├── configs/
│   │   ├── .eslintrc.js        # Centralized ESLint rules
│   │   ├── .prettierrc         # Prettier formatting config
│   │   ├── .gitleaks.toml      # Secret detection rules
│   │   ├── .spectral.yml       # OpenAPI/Swagger rules
│   │   ├── trivy-policy.yaml   # Trivy security policies
│   │   └── README.md           # Configuration guide
│   ├── scripts/
│   │   ├── swagger-lint.sh     # OpenAPI lint script
│   │   └── infra-scan.sh       # Infrastructure security script
│   └── test/
│       ├── fixtures/           # Safe/unsafe test fixtures
│       ├── test-api-lint.sh    # API Lint tests
│       └── test-infra-scan.sh  # Infra Scan tests
├── quality-configs/            # Local quality gate configs
├── dashboard/                  # Next.js results dashboard
├── example-nestjs/             # Example NestJS project
├── .gitignore
├── LICENSE
└── README.md
```

---

## Troubleshooting

### SonarQube does not start

```bash
# Check logs
docker compose logs sonarqube

# Common fix on Linux/macOS — increase vm.max_map_count
sudo sysctl -w vm.max_map_count=524288
```

### Out of memory error

Add to the `sonarqube` service in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 2g
```

### Scanner cannot find files

Make sure `sonar-project.properties` is at the project root and all paths are correct.

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting a pull request.

## License

[MIT](./LICENSE)
