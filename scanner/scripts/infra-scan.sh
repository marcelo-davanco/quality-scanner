#!/bin/bash
# ============================================================
# Infra Scan — Infrastructure Security (IaC and Containers)
# Quality Scanner Step 10
# Uses Trivy to scan Dockerfiles, docker-compose, and K8s manifests
# ============================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────
# Colors (inherited from entrypoint, defined here as fallback)
# ──────────────────────────────────────────────────────────
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# ──────────────────────────────────────────────────────────
# Parameters
# ──────────────────────────────────────────────────────────
PROJECT_DIR="${1:-/project}"
REPORTS_DIR="${2:-/reports}"
CONFIGS_DIR="${3:-/quality/configs}"

INFRA_SCAN_SEVERITY="${INFRA_SCAN_SEVERITY:-HIGH}"
SCAN_DOCKERFILE="${SCAN_DOCKERFILE:-true}"
SCAN_K8S="${SCAN_K8S:-true}"
SCAN_COMPOSE="${SCAN_COMPOSE:-true}"

# ──────────────────────────────────────────────────────────
# IaC file detection in the project
# Returns a list of found files by type
# ──────────────────────────────────────────────────────────
detect_dockerfiles() {
  local project_dir="$1"
  find "${project_dir}" \
    -maxdepth 4 \
    -type f \
    \( -name "Dockerfile" -o -name "Dockerfile.*" -o -name "*.dockerfile" \) \
    ! -path "*/node_modules/*" \
    ! -path "*/.next/*" \
    ! -path "*/coverage/*" \
    ! -path "*/.git/*" \
    ! -path "*/scanner/test/fixtures/*" \
    2>/dev/null || true
}

detect_compose_files() {
  local project_dir="$1"
  find "${project_dir}" \
    -maxdepth 4 \
    -type f \
    \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \
       -o -name "docker-compose.*.yml" -o -name "docker-compose.*.yaml" \
       -o -name "compose.yml" -o -name "compose.yaml" \) \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -path "*/scanner/test/fixtures/*" \
    2>/dev/null || true
}

detect_k8s_manifests() {
  local project_dir="$1"

  # Common K8s directories
  local k8s_dirs=("k8s" "kubernetes" "manifests" "deploy" "deployments" "helm" "charts" ".k8s")
  local found_files=""

  for dir in "${k8s_dirs[@]}"; do
    if [ -d "${project_dir}/${dir}" ]; then
      local files
      files=$(find "${project_dir}/${dir}" \
        -maxdepth 4 \
        -type f \
        \( -name "*.yaml" -o -name "*.yml" \) \
        ! -path "*/node_modules/*" \
        2>/dev/null || true)
      if [ -n "${files}" ]; then
        found_files="${found_files}${files}"$'\n'
      fi
    fi
  done

  # Search for files with typical K8s names at the root
  local root_k8s
  root_k8s=$(find "${project_dir}" \
    -maxdepth 2 \
    -type f \
    \( -name "deployment.yaml" -o -name "deployment.yml" \
       -o -name "service.yaml" -o -name "service.yml" \
       -o -name "ingress.yaml" -o -name "ingress.yml" \
       -o -name "configmap.yaml" -o -name "configmap.yml" \
       -o -name "statefulset.yaml" -o -name "statefulset.yml" \
       -o -name "daemonset.yaml" -o -name "daemonset.yml" \
       -o -name "cronjob.yaml" -o -name "cronjob.yml" \
       -o -name "pod.yaml" -o -name "pod.yml" \
       -o -name "namespace.yaml" -o -name "namespace.yml" \
       -o -name "networkpolicy.yaml" -o -name "networkpolicy.yml" \) \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -path "*/scanner/test/fixtures/*" \
    2>/dev/null || true)

  if [ -n "${root_k8s}" ]; then
    found_files="${found_files}${root_k8s}"$'\n'
  fi

  # Deduplicate and remove empty lines
  echo "${found_files}" | sort -u | grep -v '^$' || true
}

# ──────────────────────────────────────────────────────────
# Trivy execution for a scan type
# Args: <scan_type> <file_or_dir> <output_file>
# scan_type: config (for misconfig scanning)
# ──────────────────────────────────────────────────────────
run_trivy_scan() {
  local target="$1"
  local output_file="$2"
  local scan_label="$3"

  trivy config "${target}" \
    --severity "${INFRA_SCAN_SEVERITY},CRITICAL" \
    --format json \
    --output "${output_file}" \
    --quiet \
    2>/dev/null || true

  # If no output file was generated, create an empty one
  if [ ! -f "${output_file}" ]; then
    echo '{"Results":null}' > "${output_file}"
  fi
}

# ──────────────────────────────────────────────────────────
# Trivy result processing
# Generates standardized JSON for the dashboard
# ──────────────────────────────────────────────────────────
process_trivy_results() {
  local raw_files="$1"
  local severity_threshold="$2"

  python3 -c "
import json, sys, glob, os

severity_threshold = '${severity_threshold}'
severity_order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'UNKNOWN': 4}
threshold_level = severity_order.get(severity_threshold, 1)

raw_files = '''${raw_files}'''.strip().split('\n')
raw_files = [f.strip() for f in raw_files if f.strip()]

all_findings = []
counts = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
by_type = {}  # dockerfile, kubernetes, compose

for raw_file in raw_files:
    if not os.path.exists(raw_file):
        continue
    try:
        data = json.load(open(raw_file))
    except:
        continue

    results = data.get('Results', []) or []
    for result in results:
        target = result.get('Target', '')
        result_type = result.get('Type', 'unknown')
        misconfigs = result.get('Misconfigurations', []) or []

        # Classify scan type
        scan_type = 'other'
        target_lower = target.lower()
        if 'dockerfile' in target_lower or result_type == 'dockerfile':
            scan_type = 'dockerfile'
        elif any(k in target_lower for k in ['deployment', 'service', 'ingress', 'pod', 'statefulset', 'daemonset', 'cronjob', 'configmap', 'namespace', 'networkpolicy']):
            scan_type = 'kubernetes'
        elif 'compose' in target_lower:
            scan_type = 'compose'
        elif result_type in ('kubernetes', 'helm'):
            scan_type = 'kubernetes'

        if scan_type not in by_type:
            by_type[scan_type] = {'type': scan_type, 'count': 0, 'findings': []}

        for mc in misconfigs:
            sev = mc.get('Severity', 'UNKNOWN')
            counts[sev] = counts.get(sev, 0) + 1
            by_type[scan_type]['count'] += 1

            finding = {
                'id': mc.get('ID', ''),
                'avdid': mc.get('AVDID', ''),
                'title': mc.get('Title', ''),
                'description': mc.get('Description', '')[:300],
                'severity': sev,
                'resolution': mc.get('Resolution', '')[:300],
                'target': target.replace('/project/', ''),
                'type': scan_type,
                'references': mc.get('References', [])[:3],
                'status': mc.get('Status', 'FAIL')
            }
            all_findings.append(finding)
            if len(by_type[scan_type]['findings']) < 20:
                by_type[scan_type]['findings'].append(finding)

# Sort by severity
all_findings.sort(key=lambda x: severity_order.get(x['severity'], 4))

# Determine blocking findings
blocking_count = sum(
    1 for f in all_findings
    if f['status'] == 'FAIL' and severity_order.get(f['severity'], 4) <= threshold_level
)

result = {
    'totalFindings': len(all_findings),
    'blockingFindings': blocking_count,
    'counts': counts,
    'severityThreshold': severity_threshold,
    'byType': list(by_type.values()),
    'findings': all_findings[:50]
}

print(json.dumps(result))
" 2>/dev/null || echo '{"totalFindings":0,"blockingFindings":0,"counts":{"CRITICAL":0,"HIGH":0,"MEDIUM":0,"LOW":0},"severityThreshold":"HIGH","byType":[],"findings":[]}'
}

# ──────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────
main() {
  local raw_files=""
  local has_iac_files=false
  local scan_count=0

  # ── Scan Dockerfiles ──
  if [ "${SCAN_DOCKERFILE}" = "true" ]; then
    local dockerfiles
    dockerfiles=$(detect_dockerfiles "${PROJECT_DIR}")

    if [ -n "${dockerfiles}" ]; then
      has_iac_files=true
      local df_count
      df_count=$(echo "${dockerfiles}" | wc -l | tr -d ' ')
      echo -e "${CYAN}    Dockerfiles found: ${df_count}${NC}" >&2

      while IFS= read -r dockerfile; do
        [ -z "${dockerfile}" ] && continue
        scan_count=$((scan_count + 1))
        local output_file="${REPORTS_DIR}/trivy_dockerfile_${scan_count}.json"
        local df_name
        df_name=$(echo "${dockerfile}" | sed "s|${PROJECT_DIR}/||")
        echo -e "${CYAN}    Scanning: ${df_name}${NC}" >&2
        run_trivy_scan "${dockerfile}" "${output_file}" "Dockerfile"
        raw_files="${raw_files}${output_file}"$'\n'
      done <<< "${dockerfiles}"
    fi
  fi

  # ── Scan docker-compose ──
  if [ "${SCAN_COMPOSE}" = "true" ]; then
    local compose_files
    compose_files=$(detect_compose_files "${PROJECT_DIR}")

    if [ -n "${compose_files}" ]; then
      has_iac_files=true
      local cf_count
      cf_count=$(echo "${compose_files}" | wc -l | tr -d ' ')
      echo -e "${CYAN}    Compose files found: ${cf_count}${NC}" >&2

      while IFS= read -r compose_file; do
        [ -z "${compose_file}" ] && continue
        scan_count=$((scan_count + 1))
        local output_file="${REPORTS_DIR}/trivy_compose_${scan_count}.json"
        local cf_name
        cf_name=$(echo "${compose_file}" | sed "s|${PROJECT_DIR}/||")
        echo -e "${CYAN}    Scanning: ${cf_name}${NC}" >&2
        run_trivy_scan "${compose_file}" "${output_file}" "docker-compose"
        raw_files="${raw_files}${output_file}"$'\n'
      done <<< "${compose_files}"
    fi
  fi

  # ── Scan K8s manifests ──
  if [ "${SCAN_K8S}" = "true" ]; then
    local k8s_files
    k8s_files=$(detect_k8s_manifests "${PROJECT_DIR}")

    if [ -n "${k8s_files}" ]; then
      has_iac_files=true
      local kf_count
      kf_count=$(echo "${k8s_files}" | wc -l | tr -d ' ')
      echo -e "${CYAN}    K8s manifests found: ${kf_count}${NC}" >&2

      while IFS= read -r k8s_file; do
        [ -z "${k8s_file}" ] && continue
        scan_count=$((scan_count + 1))
        local output_file="${REPORTS_DIR}/trivy_k8s_${scan_count}.json"
        local kf_name
        kf_name=$(echo "${k8s_file}" | sed "s|${PROJECT_DIR}/||")
        echo -e "${CYAN}    Scanning: ${kf_name}${NC}" >&2
        run_trivy_scan "${k8s_file}" "${output_file}" "kubernetes"
        raw_files="${raw_files}${output_file}"$'\n'
      done <<< "${k8s_files}"
    fi
  fi

  # ── No IaC files found ──
  if [ "${has_iac_files}" = "false" ]; then
    echo "NO_IAC_FILES"
    return 0
  fi

  # ── Process results ──
  local result
  result=$(process_trivy_results "${raw_files}" "${INFRA_SCAN_SEVERITY}")

  # Extract counters
  local total_findings blocking_findings
  total_findings=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['totalFindings'])" 2>/dev/null || echo "0")
  blocking_findings=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['blockingFindings'])" 2>/dev/null || echo "0")

  local critical high medium low
  critical=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['counts']['CRITICAL'])" 2>/dev/null || echo "0")
  high=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['counts']['HIGH'])" 2>/dev/null || echo "0")
  medium=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['counts']['MEDIUM'])" 2>/dev/null || echo "0")
  low=$(echo "${result}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['counts']['LOW'])" 2>/dev/null || echo "0")

  # Determine status
  local status="pass"
  local summary=""

  if [ "${blocking_findings}" -gt 0 ]; then
    status="fail"
    summary="${blocking_findings} blocking finding(s) — ${critical} critical, ${high} high, ${medium} medium"
  elif [ "${total_findings}" -gt 0 ]; then
    status="warn"
    summary="${total_findings} finding(s) — ${critical} critical, ${high} high, ${medium} medium, ${low} low"
  else
    summary="Infrastructure is secure — no findings"
  fi

  # Output format: STATUS|SUMMARY|DETAILS_JSON
  echo "${status}|${summary}|${result}"

  # Clean up raw files
  rm -f "${REPORTS_DIR}"/trivy_*.json
}

main
