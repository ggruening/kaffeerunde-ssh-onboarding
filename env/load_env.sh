# shellcheck shell=sh
# Load public defaults plus optional local overrides.
#
# Works in:
# - scripts that export KO_REPO_DIR before sourcing
# - bash when sourced
# - zsh when sourced
# - POSIX sh fallback from repository root

ko_source_path=""

if [ -n "${BASH_SOURCE:-}" ]; then
  ko_source_path="${BASH_SOURCE}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  # zsh: path of the file currently being sourced
  ko_source_path="${(%):-%x}"
fi

if [ -n "${ko_source_path}" ] && [ -f "${ko_source_path}" ]; then
  ko_env_dir="$(cd "$(dirname "${ko_source_path}")" 2>/dev/null && pwd)"
  ko_repo_dir="$(cd "${ko_env_dir}/.." 2>/dev/null && pwd)"
elif [ -n "${KO_REPO_DIR:-}" ] && [ -f "${KO_REPO_DIR}/env/defaults.env.sh" ]; then
  ko_repo_dir="${KO_REPO_DIR}"
  ko_env_dir="${ko_repo_dir}/env"
elif [ -f "$(pwd)/env/defaults.env.sh" ]; then
  ko_repo_dir="$(pwd)"
  ko_env_dir="${ko_repo_dir}/env"
else
  printf 'FAIL | cannot determine onboarding repo dir for env/load_env.sh\n' >&2
  return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1091
. "${ko_env_dir}/defaults.env.sh"

if [ -f "${ko_env_dir}/local.env.sh" ]; then
  # shellcheck disable=SC1091
  . "${ko_env_dir}/local.env.sh"
fi

export KO_REPO_DIR="${ko_repo_dir}"

ko_require_public_env() {
  ko_missing=0

  for ko_name in \
    KO_PROJECT_PREFIX \
    KO_ADMIN_USER \
    KO_STEP_CA_URL \
    KO_STEP_CA_FINGERPRINT \
    KO_STEP_PROVISIONER \
    KO_MGMT_PUBLIC_ENTRY \
    KO_EGRESS_PUBLIC_ENTRY \
    KO_AUTH_01_PRIVATE_IP \
    KO_INGRESS_01_PRIVATE_IP \
    KO_APPS_01_PRIVATE_IP
  do
    eval "ko_value=\${${ko_name}:-}"
    if [ -z "${ko_value}" ]; then
      printf 'MISSING | %s\n' "${ko_name}"
      ko_missing=1
    fi
  done

  return "${ko_missing}"
}

ko_print_env_summary() {
  printf 'KO_REPO_DIR=%s\n' "${KO_REPO_DIR}"
  printf 'KO_PROJECT_PREFIX=%s\n' "${KO_PROJECT_PREFIX}"
  printf 'KO_ADMIN_USER=%s\n' "${KO_ADMIN_USER}"
  printf 'KO_STEP_CA_URL=%s\n' "${KO_STEP_CA_URL}"
  printf 'KO_STEP_CA_FINGERPRINT=%s\n' "${KO_STEP_CA_FINGERPRINT}"
  printf 'KO_STEP_PROVISIONER=%s\n' "${KO_STEP_PROVISIONER}"
  printf 'KO_MGMT_PUBLIC_ENTRY=%s\n' "${KO_MGMT_PUBLIC_ENTRY}"
  printf 'KO_EGRESS_PUBLIC_ENTRY=%s\n' "${KO_EGRESS_PUBLIC_ENTRY}"
  printf 'KO_AUTH_01_PRIVATE_IP=%s\n' "${KO_AUTH_01_PRIVATE_IP}"
  printf 'KO_INGRESS_01_PRIVATE_IP=%s\n' "${KO_INGRESS_01_PRIVATE_IP}"
  printf 'KO_APPS_01_PRIVATE_IP=%s\n' "${KO_APPS_01_PRIVATE_IP}"
  printf 'KO_CLIENT_ROOT=%s\n' "${KO_CLIENT_ROOT}"
  printf 'KO_STEPPATH=%s\n' "${KO_STEPPATH}"
  printf 'KO_SSH_CONFIG=%s\n' "${KO_SSH_CONFIG}"
  printf 'KO_KNOWN_HOSTS=%s\n' "${KO_KNOWN_HOSTS}"
  printf 'KO_AGENT_SOCK=%s\n' "${KO_AGENT_SOCK}"
  printf 'KO_AGENT_ENV=%s\n' "${KO_AGENT_ENV}"
}
