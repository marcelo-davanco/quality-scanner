# Quality Scanner

> 🌐 **翻译：** [English](./README.md) · [Português](./README.pt-BR.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/marcelo-davanco/quality-scanner)](https://github.com/marcelo-davanco/quality-scanner/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/marcelo-davanco/quality-scanner/ci.yml?branch=develop&label=CI)](https://github.com/marcelo-davanco/quality-scanner/actions/workflows/ci.yml)

一个 **Nx 单体仓库**，为 NestJS/TypeScript 项目提供完整的代码质量流水线。基于 SonarQube Community Edition 和 [Community Branch Plugin](./docs/community-branch-plugin.md)，执行 10 个自动化分析步骤——从密钥检测到基础设施安全——并通过专用 REST API 将所有结果持久化到 PostgreSQL 数据库。

## 架构

```
quality-scanner/ (Nx 单体仓库)
├── apps/scanner/     基于 Docker 的 10 步质量流水线
├── apps/api/         NestJS REST API + TypeORM + PostgreSQL
└── apps/dashboard/   Next.js 结果仪表板
```

### 服务（docker compose）

| 服务         | 描述                                        | 端口 |
|--------------|---------------------------------------------|------|
| `sonarqube`  | SonarQube Community Edition                 | 9000 |
| `db`         | SonarQube 使用的 PostgreSQL                 | 5432 |
| `api-db`     | Quality Scanner API 使用的 PostgreSQL       | 5433 |
| `liquibase`  | API 启动前执行数据库迁移                    | —    |
| `api`        | NestJS REST API（项目、扫描、配置文件）     | 3001 |
| `scanner`    | 10 步分析流水线（按需运行）                 | —    |

---

## 前提条件

- **Docker** 和 **Docker Compose**
- **Git**

> ⚠️ 在 macOS/Linux 上，增加 SonarQube 所需的虚拟内存限制：
>
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```
>
> 在 **macOS 使用 Colima** 时，至少使用 6 GB 内存启动：
>
> ```bash
> colima start --memory 6 --cpu 4
> ```

---

## 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
```

需要设置的关键变量：

| 变量                   | 描述                                     |
|------------------------|------------------------------------------|
| `SONAR_ADMIN_PASSWORD` | SonarQube 管理员密码（首次登录后修改）   |
| `SONAR_DB_PASSWORD`    | SonarQube 的 PostgreSQL 密码             |
| `API_DB_PASSWORD`      | API 数据库的 PostgreSQL 密码             |

> **注意：** `SONAR_TOKEN` 由 `scan.sh` 自动生成，留空即可。

### 2. 启动所有服务

```bash
docker compose up -d
```

这将启动 SonarQube、API 数据库，运行 Liquibase 迁移，并启动 API。

- **SonarQube：** [http://localhost:9000](http://localhost:9000) — 默认登录 `admin` / `admin`
- **API：** [http://localhost:3001/api/docs](http://localhost:3001/api/docs) — Swagger UI
- **仪表板：** [http://localhost:3000](http://localhost:3000)

### 3. 在项目中添加 `sonar-project-localhost.properties`

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

### 4. 运行扫描器

```bash
./scan.sh /path/to/your/project
```

扫描器将：
1. 如果 SonarQube 未运行则启动它
2. 生成访问令牌
3. 如果项目不存在则在 SonarQube 中创建
4. **在 API 中注册扫描**并获取质量配置文件的配置
5. 执行 10 个分析步骤
6. **向 API 报告每个阶段结果**
7. 将 JSON 报告保存到 `./reports/<date>/<scan-id>/`
8. **在 API 中完成扫描记录**，包含状态和指标

### 5. 查看结果

- **仪表板：** [http://localhost:3000](http://localhost:3000)
- **API Swagger：** [http://localhost:3001/api/docs](http://localhost:3001/api/docs)
- **SonarQube：** `http://localhost:9000/dashboard?id=<project-key>`
- **本地报告：** `./reports/`

---

## 分析步骤

| 步骤 | 工具           | 检查内容                                  | 默认状态 |
|------|----------------|-------------------------------------------|----------|
| 1    | **Gitleaks**   | 代码中的硬编码密钥和凭证                  | 启用     |
| 2    | **TypeScript** | 编译错误                                  | 启用     |
| 3    | **ESLint**     | 代码质量规则                              | 启用     |
| 4    | **Prettier**   | 代码格式                                  | 启用     |
| 5    | **npm audit**  | 依赖漏洞                                  | 启用     |
| 6    | **Knip**       | 死代码（未使用的导出、文件、依赖）        | 启用     |
| 7    | **Jest**       | 测试 + 覆盖率                             | 启用     |
| 8    | **SonarQube**  | 静态分析 + 质量门禁                       | 启用     |
| 9    | **Spectral**   | OpenAPI 合约验证                          | 禁用     |
| 10   | **Trivy**      | 基础设施安全（IaC）                       | 禁用     |

### 启用/禁用步骤

```bash
ENABLE_GITLEAKS=true
ENABLE_TYPESCRIPT=true
ENABLE_ESLINT=true
ENABLE_PRETTIER=true
ENABLE_AUDIT=true
ENABLE_KNIP=true
ENABLE_JEST=true
ENABLE_SONARQUBE=true
ENABLE_API_LINT=false    # 步骤 9 — 默认禁用
ENABLE_INFRA_SCAN=false  # 步骤 10 — 默认禁用
```

---

## 质量配置文件

质量配置文件允许定义可复用的配置文件集合（ESLint、Prettier、TypeScript、Gitleaks 等）并将其分配给项目。当扫描运行时，扫描器从 API 获取已分配配置文件的配置并自动应用。

### 管理配置文件

1. 在仪表板打开 [http://localhost:3000/quality-profiles](http://localhost:3000/quality-profiles)
2. 创建配置文件（例如："Strict Frontend"）
3. 添加配置项——每个项包含工具名称、文件名和完整文件内容
4. 将配置文件链接到一个或多个项目

### 工作原理

```
质量配置文件 "Strict Frontend"
  ├── .eslintrc.js        （自定义 ESLint 规则）
  ├── .prettierrc          （自定义 Prettier 配置）
  └── tsconfig.strict.json （自定义 TypeScript 配置）

项目 A ──→ "Strict Frontend"
项目 B ──→ "Strict Frontend"
项目 C ──→ "Backend Standard"
```

当扫描器为已分配配置文件的项目运行时，调用 `GET /api/projects/configs/:key` 并在阶段执行前覆盖容器中的静态配置文件。如果未分配配置文件，则使用 `quality-configs/` 中的静态文件作为备用。

---

## REST API

API 在 `http://localhost:3001/api` 提供，完整 Swagger 文档在 `/api/docs`。

### 端点

| 资源             | 端点                                                                     |
|------------------|--------------------------------------------------------------------------|
| **项目**         | `POST/GET /projects` · `GET/PATCH/DELETE /projects/:id`                  |
| **扫描**         | `POST /projects/:id/scans` · `GET/PATCH /scans/:id`                      |
| **阶段结果**     | `POST/GET /scans/:id/phases`                                             |
| **质量配置文件** | `POST/GET /quality-profiles` · `GET/PATCH/DELETE /quality-profiles/:id`  |
| **配置项**       | `POST/GET /quality-profiles/:id/configs` · `PATCH/DELETE /quality-profiles/configs/:itemId` |
| **扫描器配置**   | `GET /projects/configs/:key` *（扫描器使用）*                            |

### 数据库模式

```
projects ──→ quality_profiles ──→ quality_config_items
    │
    └──→ scans ──→ phase_results
```

模式由 **Liquibase** 管理——迁移通过 Docker 服务 `liquibase` 在启动时自动运行。

---

## 分支和 Pull Request 分析

```bash
# 分支分析
SONAR_BRANCH_NAME=feature/my-branch ./scan.sh /path/to/project

# Pull request 分析
SONAR_PR_KEY=42 \
SONAR_PR_BRANCH=feature/my-branch \
SONAR_PR_BASE=main \
./scan.sh /path/to/project
```

---

## 仪表板

Next.js 仪表板连接到 API 并提供：

| 页面                              | 描述                                       |
|-----------------------------------|--------------------------------------------|
| `/projects`                       | 列出所有已注册项目                         |
| `/projects/:id`                   | 项目详情、扫描历史、配置文件分配           |
| `/projects/:id/scans/:scanId`     | 扫描详情，按阶段显示结果                   |
| `/quality-profiles`               | 列出并创建质量配置文件                     |
| `/quality-profiles/:id`           | 管理配置项，链接/取消链接项目              |

---

## 常用命令

| 命令                                       | 描述                     |
|--------------------------------------------|--------------------------|
| `docker compose up -d`                     | 启动所有服务             |
| `docker compose down`                      | 停止所有服务             |
| `docker compose down -v`                   | 停止并删除所有数据       |
| `docker compose logs -f api`               | 查看 API 日志            |
| `docker compose logs -f sonarqube`         | 查看 SonarQube 日志      |
| `./scan.sh /path/to/project`               | 运行完整分析             |
| `npx nx build api`                         | 构建 API                 |
| `npx nx serve api`                         | 以开发模式运行 API       |
| `npx nx dev dashboard`                     | 以开发模式运行仪表板     |

---

## 故障排除

### SonarQube 无法启动

```bash
docker compose logs sonarqube
sudo sysctl -w vm.max_map_count=524288
```

### API 无法启动

```bash
docker compose logs api
docker compose logs liquibase   # 检查迁移是否成功运行
```

### 扫描器无法连接到 API

确保 `API_URL=http://api:3001` 在扫描器环境中已设置（已在 `docker-compose.yml` 中配置）。如果在 Docker 外运行扫描器，请设置 `API_URL=http://localhost:3001`。

---

## 贡献

欢迎贡献！提交 pull request 前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 许可证

[MIT](./LICENSE)
