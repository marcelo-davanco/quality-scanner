FROM node:18-slim

# Instalar ferramentas de sistema (Debian-based — glibc funciona corretamente com Java NIO)
RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  curl \
  git \
  unzip \
  wget \
  python3 \
  openjdk-17-jre-headless \
  && rm -rf /var/lib/apt/lists/*

# Instalar gitleaks
RUN ARCH=$(uname -m) && \
  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
  GITLEAKS_ARCH="arm64"; \
  else \
  GITLEAKS_ARCH="x64"; \
  fi && \
  wget -q "https://github.com/gitleaks/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_${GITLEAKS_ARCH}.tar.gz" -O /tmp/gitleaks.tar.gz && \
  tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks && \
  rm /tmp/gitleaks.tar.gz && \
  chmod +x /usr/local/bin/gitleaks

# Diretório das configs de qualidade (embutidas no container)
WORKDIR /quality
COPY configs/ /quality/configs/

# Instalar sonar-scanner CLI v5.0.1 (compatível com SQ 9.9, pure-Java)
ENV SONAR_SCANNER_VERSION=5.0.1.3006
RUN wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip" -O /tmp/sonar-scanner.zip && \
  unzip -q /tmp/sonar-scanner.zip -d /opt && \
  mv /opt/sonar-scanner-${SONAR_SCANNER_VERSION} /opt/sonar-scanner && \
  rm /tmp/sonar-scanner.zip && \
  ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

ENV SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV PATH="${SONAR_SCANNER_HOME}/bin:${PATH}"
# JAVA_HOME dinâmico (funciona em arm64 e amd64)
# Criar symlink para que JAVA_HOME funcione em qualquer arquitetura
RUN ln -s $(find /usr/lib/jvm -maxdepth 1 -name 'java-17-openjdk-*' -type d | head -1) /usr/lib/jvm/java-17
ENV JAVA_HOME=/usr/lib/jvm/java-17

# Instalar ferramentas globais de análise
RUN npm install -g \
  eslint@8 \
  @typescript-eslint/eslint-plugin@7 \
  @typescript-eslint/parser@7 \
  eslint-plugin-sonarjs@0.25 \
  eslint-plugin-security@2 \
  eslint-plugin-import@2 \
  eslint-config-prettier@9 \
  prettier@3 \
  typescript@5 \
  ts-jest@29 \
  jest@29 \
  @types/jest@29 \
  knip@5 \
  @stoplight/spectral-cli@6

# Copiar scripts auxiliares
COPY scripts/ /quality/scripts/
RUN chmod +x /quality/scripts/*.sh

# Copiar entrypoint
COPY entrypoint.sh /quality/entrypoint.sh
RUN chmod +x /quality/entrypoint.sh

# Diretório onde o projeto será montado
WORKDIR /project

ENTRYPOINT ["/quality/entrypoint.sh"]
