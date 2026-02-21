# Quality Scanner

> 🌐 **Переводы:** [English](./README.md) · [Português](./README.pt-BR.md) · [中文](./README.zh-CN.md) · [Español](./README.es.md) · [हिन्दी / اردو](./README.hi.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/marcelo-davanco/quality-scanner)](https://github.com/marcelo-davanco/quality-scanner/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/marcelo-davanco/quality-scanner/ci.yml?branch=develop&label=CI)](https://github.com/marcelo-davanco/quality-scanner/actions/workflows/ci.yml)

**Nx монорепозиторий**, предоставляющий полный пайплайн контроля качества кода для проектов NestJS/TypeScript. На основе SonarQube Community Edition с [Community Branch Plugin](./docs/community-branch-plugin.md) выполняет 10 автоматизированных шагов анализа — от обнаружения секретов до безопасности инфраструктуры — и сохраняет все результаты в PostgreSQL через выделенный REST API.

## Архитектура

```
quality-scanner/ (Nx монорепозиторий)
├── apps/scanner/     Docker-пайплайн качества с 10 шагами
├── apps/api/         NestJS REST API + TypeORM + PostgreSQL
└── apps/dashboard/   Next.js дашборд результатов
```

### Сервисы (docker compose)

| Сервис       | Описание                                              | Порт |
|--------------|-------------------------------------------------------|------|
| `sonarqube`  | SonarQube Community Edition                           | 9000 |
| `db`         | PostgreSQL для SonarQube                              | 5432 |
| `api-db`     | PostgreSQL для API Quality Scanner                    | 5433 |
| `liquibase`  | Выполняет миграции БД перед запуском API              | —    |
| `api`        | NestJS REST API (проекты, сканы, профили)             | 3001 |
| `scanner`    | 10-шаговый пайплайн анализа (по требованию)           | —    |

---

## Требования

- **Docker** и **Docker Compose**
- **Git**

> ⚠️ На macOS/Linux: `sudo sysctl -w vm.max_map_count=524288`
>
> На **macOS с Colima**: `colima start --memory 6 --cpu 4`

---

## Быстрый старт

### 1. Настройка переменных окружения

```bash
cp .env.example .env
```

| Переменная             | Описание                                               |
|------------------------|--------------------------------------------------------|
| `SONAR_ADMIN_PASSWORD` | Пароль администратора SonarQube (изменить при 1-м входе)|
| `SONAR_DB_PASSWORD`    | Пароль PostgreSQL для SonarQube                        |
| `API_DB_PASSWORD`      | Пароль PostgreSQL для базы данных API                  |

> **Примечание:** `SONAR_TOKEN` генерируется автоматически скриптом `scan.sh`. Оставьте пустым.

### 2. Запуск всех сервисов

```bash
docker compose up -d
```

- **SonarQube:** [http://localhost:9000](http://localhost:9000) — логин `admin` / `admin`
- **API Swagger:** [http://localhost:3001/api/docs](http://localhost:3001/api/docs)
- **Дашборд:** [http://localhost:3000](http://localhost:3000)

### 3. Добавить `sonar-project-localhost.properties` в проект

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

### 4. Запуск сканера

```bash
./scan.sh /path/to/your/project
```

Сканер регистрирует скан в API, получает конфиги профиля качества, выполняет 10 шагов анализа, отправляет результат каждой фазы в API и завершает запись скана со статусом и метриками.

### 5. Просмотр результатов

- **Дашборд:** [http://localhost:3000](http://localhost:3000)
- **SonarQube:** `http://localhost:9000/dashboard?id=<project-key>`
- **Локальные отчёты:** `./reports/`

---

## Шаги анализа

| Шаг | Инструмент     | Что проверяет                                     | По умолчанию |
|-----|----------------|---------------------------------------------------|--------------|
| 1   | **Gitleaks**   | Захардкоженные секреты и учётные данные           | включён      |
| 2   | **TypeScript** | Ошибки компиляции                                 | включён      |
| 3   | **ESLint**     | Правила качества кода                             | включён      |
| 4   | **Prettier**   | Форматирование кода                               | включён      |
| 5   | **npm audit**  | Уязвимости зависимостей                           | включён      |
| 6   | **Knip**       | Мёртвый код (неиспользуемые exports, файлы, deps) | включён      |
| 7   | **Jest**       | Тесты + покрытие                                  | включён      |
| 8   | **SonarQube**  | Статический анализ + quality gate                 | включён      |
| 9   | **Spectral**   | Валидация OpenAPI контракта                       | отключён     |
| 10  | **Trivy**      | Безопасность инфраструктуры (IaC)                 | отключён     |

Каждый шаг управляется переменной: `ENABLE_GITLEAKS`, `ENABLE_ESLINT`, `ENABLE_API_LINT` и т.д.

---

## Профили качества

Профили качества позволяют определять повторно используемые наборы конфигурационных файлов (ESLint, Prettier, TypeScript и др.) и назначать их проектам. При запуске скана сканер получает конфиги назначенного профиля через `GET /api/projects/configs/:key` и применяет их перед выполнением фаз. Если профиль не назначен, используются статические файлы из `quality-configs/`.

**Управление:** [http://localhost:3000/quality-profiles](http://localhost:3000/quality-profiles)

```
Профиль "Strict Frontend"
  ├── .eslintrc.js         (кастомные правила ESLint)
  ├── .prettierrc           (кастомный конфиг Prettier)
  └── tsconfig.strict.json  (кастомный конфиг TypeScript)

Проект A ──→ "Strict Frontend"
Проект B ──→ "Strict Frontend"
Проект C ──→ "Backend Standard"
```

---

## REST API

`http://localhost:3001/api` — Swagger на `/api/docs`

| Ресурс               | Эндпоинты                                                                |
|----------------------|--------------------------------------------------------------------------|
| **Проекты**          | `POST/GET /projects` · `GET/PATCH/DELETE /projects/:id`                  |
| **Сканы**            | `POST /projects/:id/scans` · `GET/PATCH /scans/:id`                      |
| **Результаты фаз**   | `POST/GET /scans/:id/phases`                                             |
| **Профили**          | `POST/GET /quality-profiles` · `GET/PATCH/DELETE /quality-profiles/:id`  |
| **Элементы конфига** | `POST/GET /quality-profiles/:id/configs` · `PATCH/DELETE /quality-profiles/configs/:itemId` |
| **Конфиг сканера**   | `GET /projects/configs/:key`                                             |

Схема управляется **Liquibase** — миграции запускаются автоматически через Docker-сервис `liquibase`.

---

## Анализ веток и Pull Request

```bash
# Анализ ветки
SONAR_BRANCH_NAME=feature/my-branch ./scan.sh /path/to/project

# Анализ Pull Request
SONAR_PR_KEY=42 SONAR_PR_BRANCH=feature/my-branch SONAR_PR_BASE=main \
./scan.sh /path/to/project
```

---

## Дашборд

| Страница                            | Описание                                            |
|-------------------------------------|-----------------------------------------------------|
| `/projects`                         | Список всех зарегистрированных проектов             |
| `/projects/:id`                     | Детали проекта, история сканов, назначение профиля  |
| `/projects/:id/scans/:scanId`       | Детали скана с результатами по фазам                |
| `/quality-profiles`                 | Список и создание профилей качества                 |
| `/quality-profiles/:id`             | Управление элементами конфига, привязка проектов    |

---

## Структура проекта

```text
quality-scanner/
├── apps/
│   ├── scanner/          # Docker-пайплайн (entrypoint.sh, configs/, scripts/)
│   ├── api/              # NestJS API (modules/, liquibase/)
│   └── dashboard/        # Next.js (app/projects/, app/quality-profiles/)
├── docker-compose.yml
├── scan.sh
├── quality-configs/      # Статические конфиги (fallback)
└── .env.example
```

---

## Полезные команды

| Команда                             | Описание                          |
|-------------------------------------|-----------------------------------|
| `docker compose up -d`              | Запустить все сервисы             |
| `docker compose down -v`            | Остановить и удалить все данные   |
| `docker compose logs -f api`        | Логи API                          |
| `./scan.sh /path/to/project`        | Запустить полный анализ           |
| `npx nx build api`                  | Собрать API                       |
| `npx nx dev dashboard`              | Дашборд в режиме разработки       |

---

## Устранение неполадок

**SonarQube не запускается:** `docker compose logs sonarqube` · `sudo sysctl -w vm.max_map_count=524288`

**API не запускается:** `docker compose logs api` · `docker compose logs liquibase`

**Сканер не подключается к API:** Убедитесь, что `API_URL=http://api:3001` задан в окружении сканера.

---

## Вклад в проект

Вклад приветствуется! Прочитайте [CONTRIBUTING.md](./CONTRIBUTING.md) перед отправкой pull request.

## Лицензия

[MIT](./LICENSE)
