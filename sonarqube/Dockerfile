# ============================================================
# SonarQube + Community Branch Plugin
#
# Builds a custom SonarQube image with the community-branch-plugin
# embedded at build time. No runtime dependency on third-party images.
#
# To update the plugin:
#   1. Change PLUGIN_VERSION below (must match major.minor of SONARQUBE_VERSION)
#   2. Change SONARQUBE_VERSION to the matching SonarQube release
#   3. Rebuild: docker compose build sonarqube
#
# Plugin releases: https://github.com/mc1arke/sonarqube-community-branch-plugin/releases
# ============================================================

ARG SONARQUBE_VERSION=25.10.0.114319-community

FROM sonarqube:${SONARQUBE_VERSION}

ARG PLUGIN_VERSION=25.10.0

ENV PLUGIN_VERSION=${PLUGIN_VERSION}

USER root

RUN set -eux; \
     apt-get update -qq && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/*; \
     \
     PLUGIN_JAR="sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar"; \
     BASE_URL="https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/${PLUGIN_VERSION}"; \
     \
     echo "Downloading Community Branch Plugin ${PLUGIN_VERSION} JAR..."; \
     wget -q "${BASE_URL}/${PLUGIN_JAR}" \
     -O "/opt/sonarqube/extensions/plugins/${PLUGIN_JAR}"; \
     chown sonarqube:root "/opt/sonarqube/extensions/plugins/${PLUGIN_JAR}"; \
     chmod 640 "/opt/sonarqube/extensions/plugins/${PLUGIN_JAR}"; \
     \
     echo "Downloading modified SonarQube webapp..."; \
     wget -q "${BASE_URL}/sonarqube-webapp.zip" \
     -O /tmp/sonarqube-webapp.zip; \
     chmod -R 770 /opt/sonarqube/web && rm -rf /opt/sonarqube/web/*; \
     unzip -q /tmp/sonarqube-webapp.zip -d /opt/sonarqube/web; \
     rm -f /tmp/sonarqube-webapp.zip; \
     chown -R sonarqube:root /opt/sonarqube/web; \
     chmod -R 550 /opt/sonarqube/web; \
     \
     echo "Plugin installed successfully."

USER sonarqube

ENV SONAR_WEB_JAVAADDITIONALOPTS="-javaagent:./extensions/plugins/sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar=web"
ENV SONAR_CE_JAVAADDITIONALOPTS="-javaagent:./extensions/plugins/sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar=ce"
