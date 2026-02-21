# Quality Scanner

> 🌐 **Traducciones:** [English](./README.md) · [Português](./README.pt-BR.md) · [中文](./README.zh-CN.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/marcelo-davanco/quality-scanner)](https://github.com/marcelo-davanco/quality-scanner/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/marcelo-davanco/quality-scanner/ci.yml?branch=develop&label=CI)](https://github.com/marcelo-davanco/quality-scanner/actions/workflows/ci.yml)

Un **monorepo Nx** que proporciona un pipeline completo de calidad de código para proyectos NestJS/TypeScript. Impulsado por SonarQube Community Edition con el [Community Branch Plugin](./docs/community-branch-plugin.md), ejecuta 10 pasos de análisis automatizados y persiste todos los resultados en PostgreSQL a través de una API REST dedicada.

## Arquitectura

```
quality-scanner/ (Monorepo Nx)
├── apps/scanner/     Pipeline de calidad en Docker con 10 pasos
├── apps/api/         API REST NestJS + TypeORM + PostgreSQL
└── apps/dashboard/   Dashboard de resultados en Next.js
```

### Servicios (docker compose)

| Servicio     | Descripción                                          | Puerto |
|--------------|------------------------------------------------------|--------|
| `sonarqube`  | SonarQube Community Edition                          | 9000   |
| `db`         | PostgreSQL para SonarQube                            | 5432   |
| `api-db`     | PostgreSQL para la API del Quality Scanner           | 5433   |
| `liquibase`  | Ejecuta migraciones antes de iniciar la API          | —      |
| `api`        | API REST NestJS (proyectos, scans, perfiles)         | 3001   |
| `scanner`    | Pipeline de análisis de 10 pasos (bajo demanda)      | —      |

---

## Requisitos previos

- **Docker** y **Docker Compose**
- **Git**

> ⚠️ En macOS/Linux: `sudo sysctl -w vm.max_map_count=524288`
>
> En **macOS con Colima**: `colima start --memory 6 --cpu 4`

---

## Inicio Rápido

### 1. Configurar variables de entorno

```bash
cp .env.example .env
```

| Variable               | Descripción                                              |
|------------------------|----------------------------------------------------------|
| `SONAR_ADMIN_PASSWORD` | Contraseña del admin de SonarQube                        |
| `SONAR_DB_PASSWORD`    | Contraseña de PostgreSQL para SonarQube                  |
| `API_DB_PASSWORD`      | Contraseña de PostgreSQL para la base de datos de la API |

### 2. Iniciar todos los servicios

```bash
docker compose up -d
```

- **SonarQube:** [http://localhost:9000](http://localhost:9000) — login `admin` / `admin`
- **API Swagger:** [http://localhost:3001/api/docs](http://localhost:3001/api/docs)
- **Dashboard:** [http://localhost:3000](http://localhost:3000)

### 3. Agregar `sonar-project-localhost.properties` a tu proyecto

```properties
sonar.projectKey=mi-proyecto
sonar.projectName=mi-proyecto
sonar.projectVersion=1.0.0
sonar.language=ts
sonar.sourceEncoding=UTF-8
sonar.sources=src/
sonar.exclusions=**/node_modules/**,**/dist/**,**/*.spec.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.qualitygate.wait=false
sonar.scm.disabled=true
```

### 4. Ejecutar el scanner

```bash
./scan.sh /ruta/a/tu/proyecto
```

El scanner registra el scan en la API, obtiene configs del perfil de calidad, ejecuta los 10 pasos, reporta cada resultado de fase y finaliza el registro con estado y métricas.

### 5. Ver resultados

- **Dashboard:** [http://localhost:3000](http://localhost:3000)
- **SonarQube:** `http://localhost:9000/dashboard?id=<project-key>`
- **Reportes locales:** `./reports/`

---

## Pasos de Análisis

| Paso | Herramienta    | Qué verifica                                      | Por defecto   |
|------|----------------|---------------------------------------------------|---------------|
| 1    | **Gitleaks**   | Secretos y credenciales en el código              | habilitado    |
| 2    | **TypeScript** | Errores de compilación                            | habilitado    |
| 3    | **ESLint**     | Reglas de calidad de código                       | habilitado    |
| 4    | **Prettier**   | Formato del código                                | habilitado    |
| 5    | **npm audit**  | Vulnerabilidades en dependencias                  | habilitado    |
| 6    | **Knip**       | Código muerto (exports, archivos, deps no usados) | habilitado    |
| 7    | **Jest**       | Tests + cobertura                                 | habilitado    |
| 8    | **SonarQube**  | Análisis estático + quality gate                  | habilitado    |
| 9    | **Spectral**   | Validación de contrato OpenAPI                    | deshabilitado |
| 10   | **Trivy**      | Seguridad de infraestructura (IaC)                | deshabilitado |

Cada paso se controla con `ENABLE_GITLEAKS`, `ENABLE_ESLINT`, `ENABLE_API_LINT`, etc.

---

## Perfiles de Calidad

Permiten definir conjuntos reutilizables de configs (ESLint, Prettier, TypeScript, etc.) y asignarlos a proyectos. El scanner obtiene las configs del perfil asignado vía `GET /api/projects/configs/:key` y las aplica antes de ejecutar las fases. Si no hay perfil, usa los archivos estáticos de `quality-configs/` como fallback.

**Gestión:** [http://localhost:3000/quality-profiles](http://localhost:3000/quality-profiles)

---

## API REST

`http://localhost:3001/api` — Swagger en `/api/docs`

| Recurso              | Endpoints                                                                |
|----------------------|--------------------------------------------------------------------------|
| **Proyectos**        | `POST/GET /projects` · `GET/PATCH/DELETE /projects/:id`                  |
| **Scans**            | `POST /projects/:id/scans` · `GET/PATCH /scans/:id`                      |
| **Resultados**       | `POST/GET /scans/:id/phases`                                             |
| **Perfiles**         | `POST/GET /quality-profiles` · `GET/PATCH/DELETE /quality-profiles/:id`  |
| **Items de Config**  | `POST/GET /quality-profiles/:id/configs` · `PATCH/DELETE /quality-profiles/configs/:itemId` |
| **Config Scanner**   | `GET /projects/configs/:key`                                             |

Schema gestionado por **Liquibase** (migraciones automáticas al iniciar).

---

## Análisis de Branch y Pull Request

```bash
# Branch
SONAR_BRANCH_NAME=feature/mi-branch ./scan.sh /ruta/al/proyecto

# Pull Request
SONAR_PR_KEY=42 SONAR_PR_BRANCH=feature/mi-branch SONAR_PR_BASE=main \
./scan.sh /ruta/al/proyecto
```

---

## Estructura del Proyecto

```text
quality-scanner/
├── apps/
│   ├── scanner/          # Pipeline Docker (entrypoint.sh, configs/, scripts/)
│   ├── api/              # NestJS API (modules/, liquibase/)
│   └── dashboard/        # Next.js (app/projects/, app/quality-profiles/)
├── docker-compose.yml
├── scan.sh
├── quality-configs/      # Configs estáticas de fallback
└── .env.example
```

---

## Comandos Útiles

| Comando                             | Descripción                    |
|-------------------------------------|--------------------------------|
| `docker compose up -d`              | Iniciar todos los servicios    |
| `docker compose down -v`            | Detener y eliminar datos       |
| `docker compose logs -f api`        | Ver logs de la API             |
| `./scan.sh /ruta/al/proyecto`       | Ejecutar análisis completo     |
| `npx nx build api`                  | Compilar la API                |
| `npx nx dev dashboard`              | Dashboard en modo dev          |

---

## Solución de Problemas

**SonarQube no inicia:** `docker compose logs sonarqube` · `sudo sysctl -w vm.max_map_count=524288`

**API no inicia:** `docker compose logs api` · `docker compose logs liquibase`

**Scanner no conecta con la API:** Verifica `API_URL=http://api:3001` en el entorno del scanner.

---

## Contribuir

¡Las contribuciones son bienvenidas! Lee [CONTRIBUTING.md](./CONTRIBUTING.md) antes de enviar un pull request.

## Licencia

[MIT](./LICENSE)
