# Quality Scanner

> 🌐 **Traducciones:** [English](./README.md) · [Português](./README.pt-BR.md) · [中文](./README.zh-CN.md) · [हिन्दी / اردو](./README.hi.md) · [Русский](./README.ru.md)

Pipeline de calidad de código basado en Docker para proyectos NestJS/TypeScript, impulsado por SonarQube Community Edition. Ejecuta 10 pasos de análisis automatizados — desde la detección de secretos hasta la seguridad de infraestructura — y genera un informe JSON por cada escaneo.

## Requisitos previos

- **Docker** y **Docker Compose**
- **Node.js** >= 18
- **npm** o **yarn**

> ⚠️ En macOS/Linux, aumenta el límite de memoria virtual requerido por SonarQube:
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> ```

## Inicio Rápido

### 1. Configurar variables de entorno

```bash
cp .env.example .env
```

Edita `.env` y completa tus valores. El único cambio obligatorio para la primera ejecución es `SONAR_TOKEN` (ver paso 2).

### 2. Iniciar SonarQube

```bash
docker compose up -d
```

Espera ~1 minuto y abre **http://localhost:9000**.

- **Credenciales por defecto:** `admin` / `admin`
- Se te pedirá cambiar la contraseña en el primer inicio de sesión.

### 3. Generar un Token de Acceso

1. Ve a **My Account** → **Security** → **Generate Tokens**
2. Crea un token de tipo **Project Analysis Token**
3. Cópialo y configúralo en `.env`:

```env
SONAR_TOKEN=tu_token_aqui
```

### 4. Ejecutar el Scanner

```bash
# Escanear el directorio actual
./scan.sh .

# Escanear cualquier proyecto Node.js/NestJS
./scan.sh /ruta/a/tu/proyecto
```

El contenedor del scanner:

1. Instalará las dependencias del proyecto
2. Ejecutará los 10 pasos de análisis
3. Guardará los informes JSON en `./reports/<fecha>/<scan-id>/`

### 5. Ver Resultados

- **Dashboard SonarQube:** http://localhost:9000/dashboard?id=tu-proyecto
- **Informes locales:** `./reports/`

---

## Pasos de Análisis

| Paso | Herramienta | Qué verifica |
|------|-------------|--------------|
| 1 | **Gitleaks** | Secretos y credenciales en el código |
| 2 | **TypeScript** | Errores de compilación |
| 3 | **ESLint** | Reglas de calidad de código (config centralizada) |
| 4 | **Prettier** | Formato del código (config centralizada) |
| 5 | **npm audit** | Vulnerabilidades en dependencias |
| 6 | **Knip** | Código muerto (exports, archivos, deps no usados) |
| 7 | **Jest** | Tests + cobertura |
| 8 | **SonarQube** | Análisis estático + quality gate |
| 9 | **Spectral** | Validación de contrato OpenAPI *(opcional)* |
| 10 | **Trivy** | Seguridad de infraestructura (IaC) *(opcional)* |

---

## Quality Gate Local (Pre-Push)

Ejecuta las mismas verificaciones localmente antes de hacer push:

```bash
chmod +x quality-gate.sh
./quality-gate.sh
```

---

## API Lint — Validación de Contrato OpenAPI (Paso 9)

Valida contratos OpenAPI/Swagger usando **Spectral**.

### Activación

```bash
# Via variable de entorno
ENABLE_API_LINT=true ./scan.sh /ruta/al/proyecto

# Via docker-compose
ENABLE_API_LINT=true docker compose --profile scan up scanner
```

### Qué se valida

- Todas las rutas tienen respuesta `400` mapeada
- Los paths usan `kebab-case` (ej. `/mi-recurso`)
- Las propiedades de schema usan `camelCase`
- Toda operación tiene `operationId`, `description`, `summary` y `tags`
- Los paths no terminan con `/`
- Las respuestas `200`/`201` tienen `content` definido

### Configuración

| Variable | Valor por defecto | Descripción |
|----------|-------------------|-------------|
| `ENABLE_API_LINT` | `false` | Habilitar/deshabilitar este paso |
| `API_LINT_SEVERITY` | `warn` | `warn` = solo reportar, `error` = bloquear pipeline |
| `OPENAPI_FILE_PATH` | *(auto-detect)* | Ruta manual al archivo OpenAPI |

El archivo OpenAPI se detecta automáticamente (`swagger.json`, `openapi.yaml`, etc.). Para personalizar las reglas, edita `scanner/configs/.spectral.yml`. Guía completa en [`scanner/configs/README.md`](./scanner/configs/README.md).

---

## Infra Scan — Seguridad de Infraestructura (Paso 10)

Escanea `Dockerfile`, `docker-compose.yml` y manifiestos de Kubernetes usando **Trivy**.

### Activación

```bash
# Via variable de entorno
ENABLE_INFRA_SCAN=true ./scan.sh /ruta/al/proyecto

# Via docker-compose
ENABLE_INFRA_SCAN=true docker compose --profile scan up scanner
```

### Qué se escanea

| Tipo | Archivos detectados | Hallazgos típicos |
|------|---------------------|-------------------|
| **Dockerfile** | `Dockerfile`, `Dockerfile.*` | Tag `latest`, sin `USER`, sin `HEALTHCHECK`, uso de `ADD` |
| **docker-compose** | `docker-compose.yml`, `compose.yaml` | `privileged: true`, puertos expuestos, volúmenes peligrosos |
| **Kubernetes** | `deployment.yaml`, `service.yaml`, etc. | `hostNetwork`, `securityContext` ausente, sin límites de recursos |

### Configuración

| Variable | Valor por defecto | Descripción |
|----------|-------------------|-------------|
| `ENABLE_INFRA_SCAN` | `false` | Habilitar/deshabilitar este paso |
| `INFRA_SCAN_SEVERITY` | `HIGH` | Severidad mínima de bloqueo: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `SCAN_DOCKERFILE` | `true` | Habilitar escaneo de Dockerfile |
| `SCAN_K8S` | `true` | Habilitar escaneo de manifiestos Kubernetes |
| `SCAN_COMPOSE` | `true` | Habilitar escaneo de docker-compose |

Para personalizar las políticas de seguridad, edita `scanner/configs/trivy-policy.yaml`. Guía completa en [`scanner/configs/README.md`](./scanner/configs/README.md).

---

## Comandos Útiles

| Comando | Descripción |
|---------|-------------|
| `docker compose up -d` | Iniciar SonarQube |
| `docker compose down` | Detener SonarQube |
| `docker compose down -v` | Detener y eliminar todos los datos |
| `docker compose logs -f sonarqube` | Ver logs de SonarQube |
| `./scan.sh /ruta/al/proyecto` | Ejecutar análisis completo |
| `./quality-gate.sh` | Ejecutar verificaciones locales pre-push |

---

## Estructura del Proyecto

```text
quality-scanner/
├── docker-compose.yml          # SonarQube + PostgreSQL + Scanner
├── sonar-project.properties    # Configuración del scanner
├── quality-gate.sh             # Quality gate local pre-push
├── run-sonar.sh                # Script standalone de análisis SonarQube
├── scan.sh                     # Wrapper Docker del scanner
├── .env.example                # Plantilla de variables de entorno
├── scanner/
│   ├── Dockerfile              # Imagen del scanner
│   ├── entrypoint.sh           # Pipeline de 10 pasos (contenedor)
│   ├── configs/
│   │   ├── .eslintrc.js        # Reglas ESLint centralizadas
│   │   ├── .prettierrc         # Config de formato Prettier
│   │   ├── .gitleaks.toml      # Reglas de detección de secretos
│   │   ├── .spectral.yml       # Reglas OpenAPI/Swagger
│   │   ├── trivy-policy.yaml   # Políticas de seguridad Trivy
│   │   └── README.md           # Guía de configuración
│   ├── scripts/
│   │   ├── swagger-lint.sh     # Script de lint OpenAPI
│   │   └── infra-scan.sh       # Script de seguridad de infraestructura
│   └── test/
│       ├── fixtures/           # Fixtures seguras/inseguras para tests
│       ├── test-api-lint.sh    # Tests del API Lint
│       └── test-infra-scan.sh  # Tests del Infra Scan
├── quality-configs/            # Configs del quality gate local
├── dashboard/                  # Dashboard de resultados (Next.js)
├── example-nestjs/             # Proyecto NestJS de ejemplo
├── .gitignore
├── LICENSE
└── README.md
```

---

## Solución de Problemas

### SonarQube no inicia

```bash
# Revisar logs
docker compose logs sonarqube

# Corrección común en Linux/macOS — aumentar vm.max_map_count
sudo sysctl -w vm.max_map_count=524288
```

### Error de memoria insuficiente

Agrega al servicio `sonarqube` en `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 2g
```

### El scanner no encuentra archivos

Asegúrate de que `sonar-project.properties` esté en la raíz del proyecto y que todas las rutas sean correctas.

---

## Contribuir

¡Las contribuciones son bienvenidas! Lee [CONTRIBUTING.md](./CONTRIBUTING.md) antes de enviar un pull request.

## Licencia

[MIT](./LICENSE)
