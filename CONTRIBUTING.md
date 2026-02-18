# Contributing to Quality Scanner

Thank you for your interest in contributing! This document explains how to get started.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/quality-scanner.git`
3. Create a feature branch: `git checkout -b feat/my-feature`
4. Make your changes
5. Run the local quality gate: `./quality-gate.sh`
6. Commit and push: `git push origin feat/my-feature`
7. Open a Pull Request against `main`

## Development Setup

```bash
# Copy environment template
cp .env.example .env

# Start SonarQube
docker compose up -d

# Build the scanner image
docker build -t quality-scanner:latest ./scanner/
```

## Project Structure

```text
quality-scanner/
├── scanner/
│   ├── Dockerfile          # Scanner container image
│   ├── entrypoint.sh       # Main 10-step pipeline
│   ├── configs/            # Centralized tool configs (ESLint, Prettier, etc.)
│   ├── scripts/            # Step scripts (swagger-lint, infra-scan)
│   └── test/               # Test scripts and fixtures
├── quality-gate.sh         # Local pre-push checks
├── scan.sh                 # Docker scanner wrapper
└── run-sonar.sh            # Standalone SonarQube script
```

## Adding a New Analysis Step

1. Create a script in `scanner/scripts/` if the step is complex
2. Add the step to `scanner/entrypoint.sh` following the existing pattern
3. Add a corresponding step to `quality-gate.sh` for local runs
4. Add fixtures and a test script in `scanner/test/`
5. Document the step in `README.md` and `scanner/configs/README.md`

## Running Tests

```bash
# API Lint tests
bash scanner/test/test-api-lint.sh

# Infra Scan tests
bash scanner/test/test-infra-scan.sh
```

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat: add new analysis step
fix: correct severity threshold logic
docs: update README with new env vars
chore: bump scanner image dependencies
```

## Reporting Issues

Please open an issue with:

- A clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or screenshots

## Code Style

- Shell scripts: follow existing patterns (POSIX-compatible where possible, `set -e`)
- Comments and messages: **English only**
- Keep steps self-contained and idempotent

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).
