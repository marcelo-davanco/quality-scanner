# Quality Scanner

> 🌐 **翻译版本：** [English](./README.md) · [Português](./README.pt-BR.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

基于 Docker 的 NestJS/TypeScript 项目代码质量流水线，由 SonarQube 社区版驱动。自动执行 10 个分析步骤——从密钥检测到基础设施安全——并为每次扫描生成 JSON 报告。

## 前置条件

- **Docker** 和 **Docker Compose**
- **Node.js** >= 18
- **npm** 或 **yarn**

> ⚠️ 在 macOS/Linux 上，需提高 SonarQube 所需的虚拟内存限制：
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```

## 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 并填写配置。首次运行唯一必须修改的是 `SONAR_TOKEN`（见第 2 步）。

### 2. 启动 SonarQube

```bash
docker compose up -d
```

等待约 1 分钟后，访问 **http://localhost:9000**。默认账号：`admin` / `admin`，首次登录时系统会提示修改密码。

### 3. 生成访问令牌

1. 进入 **My Account** → **Security** → **Generate Tokens**
2. 创建类型为 **Project Analysis Token** 的令牌
3. 复制令牌并写入 `.env`：

```env
SONAR_TOKEN=your_token_here
```

### 4. 运行扫描器

```bash
# 扫描当前目录
./scan.sh .

# 扫描任意 Node.js/NestJS 项目
./scan.sh /path/to/your/project
```

扫描器容器将：

1. 安装项目依赖
2. 执行全部 10 个分析步骤
3. 将 JSON 报告保存至 `./reports/<date>/<scan-id>/`

### 5. 查看结果

- **SonarQube 仪表板：** http://localhost:9000/dashboard?id=your-project
- **本地报告：** `./reports/`

---

## 分析步骤

| 步骤 | 工具 | 检查内容 |
|------|------|----------|
| 1 | **Gitleaks** | 硬编码的密钥和凭证 |
| 2 | **TypeScript** | 编译错误 |
| 3 | **ESLint** | 代码质量规则（集中配置） |
| 4 | **Prettier** | 代码格式（集中配置） |
| 5 | **npm audit** | 依赖漏洞 |
| 6 | **Knip** | 死代码（未使用的导出、文件、依赖） |
| 7 | **Jest** | 测试 + 覆盖率 |
| 8 | **SonarQube** | 静态分析 + 质量门禁 |
| 9 | **Spectral** | OpenAPI 契约验证 *(可选)* |
| 10 | **Trivy** | 基础设施安全 (IaC) *(可选)* |

---

## 本地推送前质量门禁

```bash
chmod +x quality-gate.sh
./quality-gate.sh
```

---

## API Lint — OpenAPI 契约验证（第 9 步）

使用 **Spectral** 验证 OpenAPI/Swagger 契约。

### 启用方式

```bash
ENABLE_API_LINT=true ./scan.sh /path/to/project
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### 验证内容

- 所有路由映射了 `400` 响应
- 路径使用 `kebab-case`（如 `/my-resource`）
- Schema 属性使用 `camelCase`
- 每个操作包含 `operationId`、`description`、`summary` 和 `tags`
- 路径不以 `/` 结尾
- `200`/`201` 响应定义了 `content`

### 配置项

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_API_LINT` | `false` | 启用/禁用此步骤 |
| `API_LINT_SEVERITY` | `warn` | `warn` = 仅报告，`error` = 阻断流水线 |
| `OPENAPI_FILE_PATH` | *(自动检测)* | 手动指定 OpenAPI 文件路径 |

---

## Infra Scan — 基础设施安全（第 10 步）

使用 **Trivy** 扫描 `Dockerfile`、`docker-compose.yml` 和 Kubernetes 清单。

### 启用方式

```bash
ENABLE_INFRA_SCAN=true ./scan.sh /path/to/project
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### 扫描范围

| 类型 | 检测文件 | 典型问题 |
|------|----------|----------|
| **Dockerfile** | `Dockerfile`, `Dockerfile.*` | `latest` 标签、无 `USER`、无 `HEALTHCHECK` |
| **docker-compose** | `docker-compose.yml`, `compose.yaml` | `privileged: true`、暴露端口 |
| **Kubernetes** | `deployment.yaml`, `service.yaml` 等 | `hostNetwork`、缺少 `securityContext` |

### 配置项

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_INFRA_SCAN` | `false` | 启用/禁用此步骤 |
| `INFRA_SCAN_SEVERITY` | `HIGH` | 最低阻断严重级别：`CRITICAL`、`HIGH`、`MEDIUM`、`LOW` |
| `SCAN_DOCKERFILE` | `true` | 启用 Dockerfile 扫描 |
| `SCAN_K8S` | `true` | 启用 Kubernetes 清单扫描 |
| `SCAN_COMPOSE` | `true` | 启用 docker-compose 扫描 |

---

## 常用命令

| 命令 | 说明 |
|------|------|
| `docker compose up -d` | 启动 SonarQube |
| `docker compose down` | 停止 SonarQube |
| `docker compose down -v` | 停止并删除所有数据 |
| `docker compose logs -f sonarqube` | 查看 SonarQube 日志 |
| `./scan.sh /path/to/project` | 运行完整分析 |
| `./quality-gate.sh` | 运行本地推送前检查 |

---

## 故障排查

### SonarQube 无法启动

```bash
docker compose logs sonarqube
sudo sysctl -w vm.max_map_count=524288
```

### 内存不足

在 `docker-compose.yml` 的 `sonarqube` 服务中添加：

```yaml
deploy:
  resources:
    limits:
      memory: 2g
```

### Scanner 找不到文件

确保 `sonar-project.properties` 位于项目根目录，且所有路径配置正确。

---

## 贡献

欢迎贡献！提交 Pull Request 前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 许可证

[MIT](./LICENSE)
