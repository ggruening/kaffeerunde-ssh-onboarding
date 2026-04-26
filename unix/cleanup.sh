#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"

export KO_REPO_DIR="${repo_dir}"
# shellcheck disable=SC1091
. "${repo_dir}/env/load_env.sh" || cmd_rc=1

printf 'INFO | cleanup target: %s\n' "${KO_CLIENT_ROOT}"

if [ -f "${KO_AGENT_ENV}" ]; then
  agent_pid="$(sed -n 's/^SSH_AGENT_PID=\([0-9][0-9]*\); export SSH_AGENT_PID;$/\1/p' "${KO_AGENT_ENV}" | tail -n 1)"
  if [ -n "${agent_pid}" ]; then
    kill "${agent_pid}" >/dev/null 2>&1 || true
  fi
fi

case "${KO_CLIENT_ROOT:-}" in
  ""|"/"|"/home"|"/Users")
    printf 'FAIL | refusing unsafe cleanup target: %s\n' "${KO_CLIENT_ROOT:-<empty>}"
    cmd_rc=1
    ;;
  *)
    if [ -d "${KO_CLIENT_ROOT}" ]; then
      rm -rf "${KO_CLIENT_ROOT}" || cmd_rc=1
    else
      printf 'OK | nothing to remove\n'
    fi
    ;;
esac

if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | cleanup completed\n'
else
  printf 'FAIL | cleanup failed\n'
fi

exit "${cmd_rc}"
