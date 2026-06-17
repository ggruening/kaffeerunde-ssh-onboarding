#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"

export KO_REPO_DIR="${repo_dir}"
# shellcheck disable=SC1091
. "${repo_dir}/env/load_env.sh" || cmd_rc=1

if ! ko_require_public_env; then
  printf 'FAIL | Missing required public env values.\n'
  cmd_rc=1
fi

mkdir -p "${KO_CLIENT_ROOT}" || cmd_rc=1

if [ "${cmd_rc}" = "0" ]; then
  awk '
    {
      line = $0
      gsub(/\$\{KO_PROJECT_PREFIX\}/, ENVIRON["KO_PROJECT_PREFIX"], line)
      gsub(/\$\{KO_ADMIN_USER\}/, ENVIRON["KO_ADMIN_USER"], line)
      gsub(/\$\{KO_MGMT_PUBLIC_ENTRY\}/, ENVIRON["KO_MGMT_PUBLIC_ENTRY"], line)
      gsub(/\$\{KO_EGRESS_PUBLIC_ENTRY\}/, ENVIRON["KO_EGRESS_PUBLIC_ENTRY"], line)
      gsub(/\$\{KO_MAIL_01_EXT_PUBLIC_ENTRY\}/, ENVIRON["KO_MAIL_01_EXT_PUBLIC_ENTRY"], line)
      gsub(/\$\{KO_AUTH_01_PRIVATE_IP\}/, ENVIRON["KO_AUTH_01_PRIVATE_IP"], line)
      gsub(/\$\{KO_INGRESS_01_PRIVATE_IP\}/, ENVIRON["KO_INGRESS_01_PRIVATE_IP"], line)
      gsub(/\$\{KO_APPS_01_PRIVATE_IP\}/, ENVIRON["KO_APPS_01_PRIVATE_IP"], line)
      gsub(/\$\{KO_APPS_02_EXT_WG_IP\}/, ENVIRON["KO_APPS_02_EXT_WG_IP"], line)
      gsub(/\$\{KO_KNOWN_HOSTS\}/, ENVIRON["KO_KNOWN_HOSTS"], line)
      gsub(/\$\{KO_AGENT_SOCK\}/, ENVIRON["KO_AGENT_SOCK"], line)
      print line
    }
  ' "${repo_dir}/common/ssh_config.template" > "${KO_SSH_CONFIG}" || cmd_rc=1
fi

if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | rendered SSH config: %s\n' "${KO_SSH_CONFIG}"
else
  printf 'FAIL | render-config failed\n'
fi

exit "${cmd_rc}"
