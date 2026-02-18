# Scanner Configs — Configuration Guide

This directory contains all centralized configurations for the Quality Scanner, bundled inside the Docker container.

## Files

| File | Purpose |
|------|---------|
| `.eslintrc.js` | ESLint code quality rules (TypeScript) |
| `.prettierrc` | Code formatting config |
| `.gitleaks.toml` | Secret detection rules |
| `.spectral.yml` | OpenAPI/Swagger contract validation rules |
| `trivy-policy.yaml` | Infrastructure security policies (Trivy) |
| `sonar-project.properties` | Default SonarQube scanner configuration |

---

## API Lint — OpenAPI Contract Validation (Spectral)

### What it is

**Spectral** is a linting tool for OpenAPI/Swagger files. It validates that API documentation follows the REST standards defined for the project.

### Activation

```bash
# Via environment variable
ENABLE_API_LINT=true ./scan.sh /path/to/project

# Via docker-compose
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_API_LINT` | `false` | Enable/disable the API Lint step |
| `API_LINT_SEVERITY` | `warn` | Blocking level: `warn` (report only) or `error` (block pipeline) |
| `OPENAPI_FILE_PATH` | *(auto-detect)* | Manual path to the OpenAPI file, relative to the project root |

### Auto-Detection

When `OPENAPI_FILE_PATH` is not set, the scanner automatically searches in the following locations (in priority order):

1. `swagger.json` / `swagger.yaml` / `swagger.yml`
2. `openapi.json` / `openapi.yaml` / `openapi.yml`
3. `api-docs.json` / `api-docs.yaml` / `api-docs.yml`
4. `docs/swagger.json` / `docs/openapi.json`
5. `api/swagger.json` / `api/openapi.json`
6. `dist/swagger.json` / `dist/openapi.json`
7. Recursive search (up to 3 levels deep, ignoring `node_modules`)

### Ruleset Customization (`.spectral.yml`)

The `.spectral.yml` file extends the default `spectral:oas` ruleset and adds custom rules.

#### Included Custom Rules

| Rule | Severity | Description |
|------|----------|-------------|
| `operation-must-have-400-response` | warn | Every operation must map a 400 response |
| `paths-must-be-kebab-case` | warn | Paths must use `kebab-case` |
| `properties-must-be-camel-case` | warn | Schema properties must use `camelCase` |
| `operation-must-have-tags` | warn | Every operation must have at least one tag |
| `operation-must-have-summary` | warn | Every operation must have a summary |
| `no-trailing-slash` | error | Paths must not end with `/` |
| `response-must-have-content` | warn | 200/201 responses must have content defined |

#### Default OAS Rules (Severity Override)

| Rule | Severity | Description |
|------|----------|-------------|
| `operation-operationId` | error | Every operation must have an `operationId` |
| `operation-description` | error | Every operation must have a `description` |
| `info-description` | error | Info must have a description |
| `info-contact` | warn | Info should have contact info |
| `oas3-api-servers` | warn | Must define servers |

#### How to Add New Rules

Edit `.spectral.yml` and add a new rule following this pattern:

```yaml
rules:
  my-custom-rule:
    description: "Rule description"
    severity: warn  # error | warn | info | hint
    given: "$.paths[*][*]"  # JSONPath to the target
    then:
      field: "fieldName"
      function: truthy  # truthy | falsy | pattern | schema | etc.
```

#### Spectral Function Reference

- **`truthy`** — field must exist and be truthy
- **`falsy`** — field must be falsy
- **`pattern`** — field must match a regex (`functionOptions.match` or `functionOptions.notMatch`)
- **`schema`** — field must conform to a JSON Schema
- **`enumeration`** — field must be one of the listed values
- **`length`** — field length must be within a range

### JSON Output

The step generates a JSON report with the following structure:

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
          "message": "Every operation must map a 400 (Bad Request) response.",
          "path": "paths./users.get",
          "source": "swagger.json",
          "range": { "start": { "line": 10, "character": 6 }, "end": { "line": 10, "character": 20 } }
        }
      ]
    }
  ]
}
```

### Tests

```bash
# Run API Lint tests
bash scanner/test/test-api-lint.sh
```

Test scenarios covered:

| Scenario | Expected Result |
|----------|----------------|
| Valid API | 0 violations, step passes |
| Invalid API + severity=warn | Violations reported, pipeline continues |
| Invalid API + severity=error | Violations reported, pipeline blocked |
| No OpenAPI file | Step skipped gracefully |
| Step disabled | Step does not run |
| Manual OPENAPI_FILE_PATH | File found at specified path |
| JSON schema validation | Output contains all required fields |

---

## Infra Scan — Infrastructure Security (Trivy)

### What it is

**Trivy** is an open-source security scanner by Aqua Security. It detects misconfigurations in Infrastructure as Code (IaC) files: Dockerfiles, docker-compose, Kubernetes manifests, and Terraform.

### Activation

```bash
# Via environment variable
ENABLE_INFRA_SCAN=true ./scan.sh /path/to/project

# Via docker-compose
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_INFRA_SCAN` | `false` | Enable/disable the Infra Scan step |
| `INFRA_SCAN_SEVERITY` | `HIGH` | Minimum blocking severity: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `SCAN_DOCKERFILE` | `true` | Enable Dockerfile scanning |
| `SCAN_K8S` | `true` | Enable Kubernetes manifest scanning |
| `SCAN_COMPOSE` | `true` | Enable docker-compose scanning |

### Automatic File Detection

The scanner automatically detects IaC files in the project:

**Dockerfiles:**
- `Dockerfile`, `Dockerfile.*`, `*.dockerfile`
- Searches up to 4 levels deep (ignores `node_modules`, `.git`)

**docker-compose:**
- `docker-compose.yml`, `docker-compose.yaml`
- `docker-compose.*.yml`, `compose.yml`, `compose.yaml`

**Kubernetes:**
- Directories: `k8s/`, `kubernetes/`, `manifests/`, `deploy/`, `deployments/`, `helm/`, `charts/`
- Root-level files: `deployment.yaml`, `service.yaml`, `ingress.yaml`, `configmap.yaml`, etc.

### Security Rules Covered

#### Dockerfile

| ID | Severity | Description |
|----|----------|-------------|
| DS001 | HIGH | Base image using `latest` tag |
| DS002 | HIGH | Container running as root |
| DS005 | LOW | Use of `ADD` instead of `COPY` |
| DS006 | LOW | Missing `HEALTHCHECK` |
| DS012 | LOW | `apt-get` without `--no-install-recommends` |
| DS013 | HIGH | Missing `USER` instruction |
| DS014 | MEDIUM | Use of `sudo` |
| DS026 | LOW | Privileged port exposed |

#### Kubernetes

| ID | Severity | Description |
|----|----------|-------------|
| KSV001 | HIGH | Container running as root |
| KSV003 | MEDIUM | Capabilities not dropped |
| KSV006 | HIGH | `hostNetwork` enabled |
| KSV009 | HIGH | `hostPID` enabled |
| KSV010 | HIGH | `hostIPC` enabled |
| KSV011 | MEDIUM | CPU limits not defined |
| KSV013 | MEDIUM | Memory limits not defined |
| KSV014 | CRITICAL | Privileged container |
| KSV020 | HIGH | Missing `runAsNonRoot` |
| KSV021 | HIGH | Missing `securityContext` |

### Policy Customization (`trivy-policy.yaml`)

The `trivy-policy.yaml` file controls which severities and scanners are active. To adjust:

```yaml
# Example: report only CRITICAL and HIGH
severity:
  - CRITICAL
  - HIGH

# Example: include only Docker and Kubernetes checks
misconfig:
  include:
    - docker
    - kubernetes
```

### JSON Output

The step generates a JSON report with the following structure:

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

### Troubleshooting — Common Findings

#### Dockerfile: "Image user should not be root" (DS002/DS013)

```dockerfile
# PROBLEM: No USER instruction
FROM node:18
COPY . /app
CMD ["node", "app.js"]

# SOLUTION: Add a non-root USER
FROM node:18
COPY --chown=node:node . /app
USER node
CMD ["node", "app.js"]
```

#### Dockerfile: "Add instead of Copy" (DS005)

```dockerfile
# PROBLEM: ADD can download URLs and auto-extract tars
ADD . /app

# SOLUTION: Use COPY (more explicit and secure)
COPY . /app
```

#### Dockerfile: "No HEALTHCHECK" (DS006)

```dockerfile
# SOLUTION: Add a HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

#### Kubernetes: "Container is privileged" (KSV014 — CRITICAL)

```yaml
# PROBLEM
securityContext:
  privileged: true

# SOLUTION
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
# SOLUTION: Define requests and limits
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
# PROBLEM
spec:
  hostNetwork: true
  hostPID: true

# SOLUTION: Remove or set to false
spec:
  hostNetwork: false
  hostPID: false
  hostIPC: false
```

### Tests

```bash
# Run Infra Scan tests
bash scanner/test/test-infra-scan.sh
```

Test scenarios covered:

| Scenario | Expected Result |
|----------|----------------|
| Safe Dockerfile | 0 blocking findings, step passes |
| Unsafe Dockerfile | Findings reported, blocked per severity |
| K8s without securityContext | CRITICAL/HIGH finding |
| Compose with privileged | HIGH findings |
| No IaC files | Step skipped gracefully |
| Step disabled | Step does not run |
| Severity threshold CRITICAL vs MEDIUM | Blocking proportional to threshold |
| JSON schema validation | Output contains all required fields |
