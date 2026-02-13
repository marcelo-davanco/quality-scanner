# Quality Gate Local — Guia de Setup

Setup completo para pegar apontamentos **antes do push**, eliminando retrabalho com bots do GitHub (Copilot, Cursor).

## O que cada ferramenta pega

| Ferramenta | O que detecta | Quando roda |
|------------|--------------|-------------|
| **TypeScript (`tsc`)** | Erros de tipo, imports quebrados | Pre-push |
| **ESLint + sonarjs** | Code smells, complexidade, `any`, vars não usadas, segurança | Pre-commit (staged) + Pre-push |
| **Prettier** | Formatação inconsistente | Pre-commit (staged) |
| **Jest** | Testes falhando, cobertura abaixo do threshold | Pre-push |
| **SonarQube** | Bugs, vulnerabilidades, duplicação, cobertura detalhada | Pre-push (se container UP) |

## Setup no projeto real

### 1. Instalar dependências

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

### 2. Copiar arquivos de config

```bash
# Da pasta quality-configs/ para a raiz do projeto:
cp .eslintrc.js        /caminho/do/projeto/
cp .prettierrc         /caminho/do/projeto/
cp .prettierignore     /caminho/do/projeto/
cp .lintstagedrc.json  /caminho/do/projeto/
cp sonar-project.properties /caminho/do/projeto/
```

### 3. Configurar Husky (git hooks)

```bash
cd /caminho/do/projeto

# Inicializar husky
npx husky init

# Pre-commit: formata e lint nos arquivos staged
cp quality-configs/husky-pre-commit .husky/pre-commit

# Pre-push: quality gate completo
cp quality-configs/husky-pre-push .husky/pre-push
cp quality-gate.sh ./

chmod +x .husky/pre-commit .husky/pre-push quality-gate.sh
```

### 4. Adicionar scripts ao package.json

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

## Fluxo de trabalho

```
git add .
git commit -m "feat: ..."
  └─ pre-commit hook
     ├─ prettier --write (auto-formata staged files)
     └─ eslint --fix (auto-corrige o que pode)

git push
  └─ pre-push hook → quality-gate.sh
     ├─ [1/5] tsc --noEmit (compilação)
     ├─ [2/5] eslint (regras sonarjs + security)
     ├─ [3/5] prettier --check (formatação)
     ├─ [4/5] jest --coverage (testes + cobertura)
     └─ [5/5] sonarqube (se container UP)
```

Se qualquer step falhar, o **push é bloqueado** até corrigir.

## Rodar manualmente

```bash
# Quality gate completo
./quality-gate.sh

# Só lint
npm run lint

# Lint + auto-fix
npm run lint:fix

# Só formatação
npm run format:check

# Formatar tudo
npm run format
```

## Regras ESLint alinhadas com SonarQube

O `.eslintrc.js` usa o plugin `eslint-plugin-sonarjs` que replica as mesmas regras do SonarQube:

- **Complexidade cognitiva** — max 15 (mesma do Sonar)
- **Strings duplicadas** — max 3 ocorrências
- **Funções idênticas** — detecta copy/paste
- **`any` explícito** — warning (Copilot bot sempre aponta)
- **Return type explícito** — warning (Copilot bot sempre aponta)
- **Promises não tratadas** — error
- **Imports organizados** — auto-fix com grupos
- **Segurança** — regex unsafe, eval, timing attacks

### Regras relaxadas em testes

Arquivos `*.spec.ts` e `*.test.ts` têm regras mais permissivas (any permitido, sem limite de complexidade, strings duplicadas OK).

## Arquivos nesta pasta

```
quality-configs/
├── .eslintrc.js          # ESLint com sonarjs + security + typescript
├── .prettierrc           # Formatação padrão
├── .prettierignore       # Arquivos ignorados pelo Prettier
├── .lintstagedrc.json    # Config do lint-staged (pre-commit)
├── husky-pre-commit      # Hook: formata + lint nos staged files
├── husky-pre-push        # Hook: quality gate completo
├── sonar-project.properties  # Config SonarQube melhorada
├── devDependencies.json  # Pacotes necessários
└── README.md
```
