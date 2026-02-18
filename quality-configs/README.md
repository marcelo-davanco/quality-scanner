# Local Quality Gate — Setup Guide

Complete setup to catch issues **before pushing**, eliminating rework from GitHub bots (Copilot, Cursor).

## What each tool catches

| Tool | What it detects | When it runs |
|------|----------------|--------------|
| **TypeScript (`tsc`)** | Type errors, broken imports | Pre-push |
| **ESLint + sonarjs** | Code smells, complexity, `any`, unused vars, security | Pre-commit (staged) + Pre-push |
| **Prettier** | Inconsistent formatting | Pre-commit (staged) |
| **Jest** | Failing tests, coverage below threshold | Pre-push |
| **SonarQube** | Bugs, vulnerabilities, duplication, detailed coverage | Pre-push (if container is UP) |

## Setup in your project

### 1. Install dependencies

```bash
npm install -D \
  eslint \
  @typescript-eslint/eslint-plugin \
  @typescript-eslint/parser \
  eslint-plugin-sonarjs \
  eslint-plugin-security \
  eslint-plugin-import \
  eslint-config-prettier \
  prettier \
  husky \
  lint-staged
```

### 2. Copy config files

```bash
# From the quality-configs/ folder to your project root:
cp .eslintrc.js        /path/to/project/
cp .prettierrc         /path/to/project/
cp .prettierignore     /path/to/project/
cp .lintstagedrc.json  /path/to/project/
cp sonar-project.properties /path/to/project/
```

### 3. Configure Husky (git hooks)

```bash
cd /path/to/project

# Initialize husky
npx husky init

# Pre-commit: format and lint staged files
cp quality-configs/husky-pre-commit .husky/pre-commit

# Pre-push: full quality gate
cp quality-configs/husky-pre-push .husky/pre-push
cp quality-gate.sh ./

chmod +x .husky/pre-commit .husky/pre-push quality-gate.sh
```

### 4. Add scripts to package.json

```json
{
  "scripts": {
    "lint": "eslint 'src/**/*.ts' --max-warnings 0",
    "lint:fix": "eslint 'src/**/*.ts' --fix",
    "format": "prettier --write 'src/**/*.ts'",
    "format:check": "prettier --check 'src/**/*.ts'",
    "quality": "./quality-gate.sh"
  }
}
```

## Workflow

```text
git add .
git commit -m "feat: ..."
  └─ pre-commit hook
     ├─ prettier --write (auto-formats staged files)
     └─ eslint --fix (auto-fixes what it can)

git push
  └─ pre-push hook → quality-gate.sh
     ├─ [1/5] tsc --noEmit (compilation)
     ├─ [2/5] eslint (sonarjs + security rules)
     ├─ [3/5] prettier --check (formatting)
     ├─ [4/5] jest --coverage (tests + coverage)
     └─ [5/5] sonarqube (if container is UP)
```

If any step fails, the **push is blocked** until fixed.

## Run manually

```bash
# Full quality gate
./quality-gate.sh

# Lint only
npm run lint

# Lint + auto-fix
npm run lint:fix

# Check formatting only
npm run format:check

# Format everything
npm run format
```

## ESLint rules aligned with SonarQube

The `.eslintrc.js` uses `eslint-plugin-sonarjs` which replicates the same rules as SonarQube:

- **Cognitive complexity** — max 15 (same as Sonar)
- **Duplicate strings** — max 3 occurrences
- **Identical functions** — detects copy/paste
- **Explicit `any`** — warning (commonly flagged by Copilot bot)
- **Explicit return type** — warning (commonly flagged by Copilot bot)
- **Unhandled promises** — error
- **Organized imports** — auto-fix with groups
- **Security** — unsafe regex, eval, timing attacks

### Relaxed rules in tests

Files matching `*.spec.ts` and `*.test.ts` have more permissive rules (any allowed, no complexity limit, duplicate strings OK).

## Files in this folder

```text
quality-configs/
├── .eslintrc.js          # ESLint with sonarjs + security + typescript
├── .prettierrc           # Standard formatting config
├── .prettierignore       # Files ignored by Prettier
├── .lintstagedrc.json    # lint-staged config (pre-commit)
├── husky-pre-commit      # Hook: format + lint staged files
├── husky-pre-push        # Hook: full quality gate
├── sonar-project.properties  # Improved SonarQube config
├── devDependencies.json  # Required packages
└── README.md
```
