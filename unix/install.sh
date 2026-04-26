#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"

export KO_REPO_DIR="${repo_dir}"
# shellcheck disable=SC1091
. "${repo_dir}/env/load_env.sh" || cmd_rc=1

printf '\n== prerequisite check ==\n'
for bin in ssh ssh-keygen awk mkdir chmod cp grep mktemp; do
  if command -v "${bin}" >/dev/null 2>&1; then
    printf 'OK | %s\n' "${bin}"
  else
    printf 'FAIL | missing %s\n' "${bin}"
    cmd_rc=1
  fi
done

if command -v step >/dev/null 2>&1; then
  printf 'OK | step\n'
else
  printf 'WARN | missing step; install step-cli before login.\n'
  cmd_rc=1
fi

mkdir -p "${KO_CLIENT_ROOT}" "${KO_STEPPATH}" "${HOME}/.ssh" || cmd_rc=1
chmod 700 "${KO_CLIENT_ROOT}" "${KO_STEPPATH}" "${HOME}/.ssh" 2>/dev/null || cmd_rc=1

"${repo_dir}/scripts/render-config.sh" || cmd_rc=1

if [ -f "${repo_dir}/common/known_hosts" ]; then
  cp "${repo_dir}/common/known_hosts" "${KO_KNOWN_HOSTS}" || cmd_rc=1
  chmod 600 "${KO_KNOWN_HOSTS}" 2>/dev/null || cmd_rc=1
else
  printf 'WARN | common/known_hosts missing; host verification file not installed yet.\n'
  : > "${KO_KNOWN_HOSTS}" || cmd_rc=1
  chmod 600 "${KO_KNOWN_HOSTS}" 2>/dev/null || cmd_rc=1
fi

ssh_user_config="${HOME}/.ssh/config"
include_line="Include ${KO_SSH_CONFIG}"
begin_marker="# BEGIN kaffeerunde SSH onboarding"
end_marker="# END kaffeerunde SSH onboarding"

printf '\n== ssh include ==\n'
if [ "${cmd_rc}" = "0" ]; then
  tmp_config="$(mktemp "${TMPDIR:-/tmp}/kaffee-ssh-config.XXXXXX")"
  backup_config="${ssh_user_config}.bak.$(date -u +%Y%m%dT%H%M%SZ)"

  if [ -f "${ssh_user_config}" ]; then
    cp "${ssh_user_config}" "${backup_config}" || cmd_rc=1
  else
    : > "${backup_config}" || cmd_rc=1
  fi

  if [ "${cmd_rc}" = "0" ]; then
    {
      printf '%s\n' "${begin_marker}"
      printf '%s\n' "${include_line}"
      printf '%s\n' "${end_marker}"
      printf '\n'

      awk -v begin="${begin_marker}" -v end="${end_marker}" -v include="${include_line}" '
        $0 == begin { in_block=1; next }
        $0 == end { in_block=0; next }
        in_block { next }
        $0 == include { next }
        $0 == "# kaffeerunde SSH onboarding" { next }
        { print }
      ' "${backup_config}"
    } > "${tmp_config}" || cmd_rc=1
  fi

  if [ "${cmd_rc}" = "0" ]; then
    cp "${tmp_config}" "${ssh_user_config}" || cmd_rc=1
    chmod 600 "${ssh_user_config}" 2>/dev/null || cmd_rc=1
    rm -f "${tmp_config}"
    printf 'OK | prepended include to user ssh config\n'
    printf 'OK | backup created: %s\n' "${backup_config}"
  else
    printf 'FAIL | could not update user ssh config\n'
  fi
fi

printf '\n== result ==\n'
if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | install completed\n'
  printf 'NEXT | run: ./unix/login.sh\n'
else
  printf 'FAIL | install completed with warnings/failures; review output above\n'
fi

exit "${cmd_rc}"
