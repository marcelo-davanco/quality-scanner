# SonarQube Community Branch Plugin

Suporte a análise de **branches** e **Pull Requests** no SonarQube Community Edition, via integração com o [`sonarqube-community-branch-plugin`](https://github.com/mc1arke/sonarqube-community-branch-plugin).

---

## Como funciona

O plugin é embutido em uma imagem Docker customizada, publicada automaticamente no GitHub Container Registry via CI. Nenhum build local é necessário para usar.

```text
sonarqube/Dockerfile
    └── FROM sonarqube:25.10.0.114319-community (oficial SonarSource)
        └── plugin 25.10.0 instalado no layer da imagem
                │
    GitHub Actions (.github/workflows/sonarqube-image.yml)
                │
                └── ghcr.io/marcelo-davanco/sonarqube-with-community-branch-plugin
                            │
                └── docker-compose.yml  ←  docker compose up -d sonarqube db
```

---

## Uso

### 1. Configurar `.env`

```bash
cp .env.example .env
```

O `SONAR_IMAGE` já aponta para a imagem publicada:

```bash
SONAR_IMAGE=ghcr.io/marcelo-davanco/sonarqube-with-community-branch-plugin:latest
```

Para fixar uma versão específica (recomendado em produção):

```bash
SONAR_IMAGE=ghcr.io/marcelo-davanco/sonarqube-with-community-branch-plugin:25.10.0
```

### 2. Subir o SonarQube

```bash
docker compose up -d sonarqube db
```

### 3. Analisar uma branch

```bash
SONAR_BRANCH_NAME=feature/minha-feature ./scan.sh /caminho/do/projeto
```

### 4. Analisar um Pull Request

```bash
SONAR_PR_KEY=42 \
SONAR_PR_BRANCH=feature/minha-feature \
SONAR_PR_BASE=main \
./scan.sh /caminho/do/projeto
```

> **Atenção:** nunca defina `SONAR_BRANCH_NAME` e `SONAR_PR_KEY` ao mesmo tempo.

---

## Variáveis de ambiente

| Variável | Descrição | Exemplo |
| --- | --- | --- |
| `SONAR_IMAGE` | Imagem do SonarQube com o plugin | `ghcr.io/marcelo-davanco/sonarqube-with-community-branch-plugin:25.10.0` |
| `SONAR_BRANCH_NAME` | Nome da branch a analisar | `feature/my-feature` |
| `SONAR_PR_KEY` | ID do Pull Request | `42` |
| `SONAR_PR_BRANCH` | Branch de origem do PR | `feature/my-feature` |
| `SONAR_PR_BASE` | Branch de destino do PR | `main` |
| `SONAR_SCM_REVISION` | SHA do commit (obrigatório para GitHub PRs) | `abc123def` |

---

## Atualizar o plugin

Quando uma nova versão for lançada em [releases](https://github.com/mc1arke/sonarqube-community-branch-plugin/releases):

1. Atualizar `ARG SONARQUBE_VERSION` e `ARG PLUGIN_VERSION` em `sonarqube/Dockerfile`
2. Atualizar `SONARQUBE_VERSION`, `SONAR_PLUGIN_VERSION` e `SONAR_IMAGE` em `.env.example`
3. Fazer push em `main` — o CI publica a nova imagem automaticamente

> A versão **major.minor** do plugin deve coincidir com a versão do SonarQube base.

---

## Configuração inicial no SonarQube UI

Após subir pela primeira vez, acessar `http://localhost:9000` e configurar:

- **`Administration > Configuration > General > Server base URL`** — URL pública do servidor
- **`Administration > Configuration > Pull Request > Images base URL`** — se o servidor não tiver acesso externo, usar:

  ```text
  https://raw.githubusercontent.com/mc1arke/sonarqube-community-branch-plugin/master/src/main/resources/static
  ```

- **`Administration > DevOps Platform Integrations`** — para PR decoration (comentários automáticos no GitHub/GitLab/Bitbucket)

---

## Requisitos de sistema

- Docker com mínimo **4GB de RAM** disponível (SonarQube 25.x)
- Acesso ao GHCR para pull da imagem (público após primeira publicação)
