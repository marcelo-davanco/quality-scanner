FROM node:18-slim

# Install system tools (Debian-based — glibc works correctly with Java NIO)
RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  curl \
  git \
  unzip \
  wget \
  python3 \
  openjdk-17-jre-headless \
  && rm -rf /var/lib/apt/lists/*

# Install gitleaks
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

# Install Trivy (infrastructure security scanner)
# Supports: Dockerfile, docker-compose, K8s manifests, Terraform, image vulnerabilities
ENV TRIVY_VERSION=0.58.2
RUN ARCH=$(uname -m) && \
  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
  TRIVY_ARCH="ARM64"; \
  else \
  TRIVY_ARCH="64bit"; \
  fi && \
  wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" -O /tmp/trivy.tar.gz && \
  tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy && \
  rm /tmp/trivy.tar.gz && \
  chmod +x /usr/local/bin/trivy

# Quality configs directory (bundled into the container)
WORKDIR /quality
COPY configs/ /quality/configs/

# Install sonar-scanner CLI v5.0.1 (compatible with SQ 9.9, pure-Java)
ENV SONAR_SCANNER_VERSION=5.0.1.3006
RUN wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip" -O /tmp/sonar-scanner.zip && \
  unzip -q /tmp/sonar-scanner.zip -d /opt && \
  mv /opt/sonar-scanner-${SONAR_SCANNER_VERSION} /opt/sonar-scanner && \
  rm /tmp/sonar-scanner.zip && \
  ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

ENV SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV PATH="${SONAR_SCANNER_HOME}/bin:${PATH}"
# Dynamic JAVA_HOME (works on arm64 and amd64)
# Create symlink so JAVA_HOME works on any architecture
RUN ln -s $(find /usr/lib/jvm -maxdepth 1 -name 'java-17-openjdk-*' -type d | head -1) /usr/lib/jvm/java-17
ENV JAVA_HOME=/usr/lib/jvm/java-17

# Install global analysis tools
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

# Copy helper scripts
COPY scripts/ /quality/scripts/
RUN chmod +x /quality/scripts/*.sh

# Copy entrypoint
COPY entrypoint.sh /quality/entrypoint.sh
RUN chmod +x /quality/entrypoint.sh

# Directory where the project will be mounted
WORKDIR /project

ENTRYPOINT ["/quality/entrypoint.sh"]
