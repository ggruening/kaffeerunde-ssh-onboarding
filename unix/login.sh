#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"

export KO_REPO_DIR="${repo_dir}"
# shellcheck disable=SC1091
. "${repo_dir}/env/load_env.sh" || cmd_rc=1

for bin in step ssh-agent ssh-add; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    printf 'FAIL | missing %s\n' "${bin}"
    cmd_rc=1
  fi
done

mkdir -p "${KO_CLIENT_ROOT}" "${KO_STEPPATH}" || cmd_rc=1
chmod 700 "${KO_CLIENT_ROOT}" "${KO_STEPPATH}" 2>/dev/null || cmd_rc=1

agent_ok=0

if [ -S "${KO_AGENT_SOCK}" ]; then
  SSH_AUTH_SOCK="${KO_AGENT_SOCK}" ssh-add -l >/dev/null 2>&1
  agent_probe_rc=$?
  if [ "${agent_probe_rc}" = "0" ] || [ "${agent_probe_rc}" = "1" ]; then
    agent_ok=1
  fi
fi

if [ "${cmd_rc}" = "0" ] && [ "${agent_ok}" != "1" ]; then
  rm -f "${KO_AGENT_SOCK}" "${KO_AGENT_ENV}" 2>/dev/null || true
  ssh-agent -a "${KO_AGENT_SOCK}" > "${KO_AGENT_ENV}" || cmd_rc=1
  chmod 600 "${KO_AGENT_ENV}" 2>/dev/null || cmd_rc=1
fi

if [ "${cmd_rc}" = "0" ]; then
  export SSH_AUTH_SOCK="${KO_AGENT_SOCK}"
  export STEPPATH="${KO_STEPPATH}"

  if [ ! -f "${STEPPATH}/config/defaults.json" ]; then
    step ca bootstrap \
      --ca-url "${KO_STEP_CA_URL}" \
      --fingerprint "${KO_STEP_CA_FINGERPRINT}" || cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  step ssh login "${KO_ADMIN_USER}" \
    --provisioner "${KO_STEP_PROVISIONER}" || cmd_rc=1
fi

printf '\n== loaded identities in dedicated agent ==\n'
if [ "${cmd_rc}" = "0" ]; then
  SSH_AUTH_SOCK="${KO_AGENT_SOCK}" ssh-add -l || cmd_rc=1
fi

printf '\n== result ==\n'
if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | login completed\n'
  printf 'NEXT | ssh "%s-apps-01"\n' "${KO_PROJECT_PREFIX}"
else
  printf 'FAIL | login failed\n'
fi

exit "${cmd_rc}"
