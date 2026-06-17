#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"

known_hosts="${repo_dir}/common/known_hosts"

if [ ! -f "${known_hosts}" ]; then
  printf 'FAIL | common/known_hosts missing\n'
  exit 1
fi

line_count="$(wc -l < "${known_hosts}" | tr -d ' ')"
if [ "${line_count}" != "7" ]; then
  printf 'FAIL | common/known_hosts has %s lines, expected 7\n' "${line_count}"
  cmd_rc=1
fi

if grep -E 'PRIVATE KEY|BEGIN OPENSSH PRIVATE KEY|BEGIN .* PRIVATE KEY' "${known_hosts}" >/dev/null 2>&1; then
  printf 'FAIL | common/known_hosts appears to contain private key material\n'
  cmd_rc=1
fi

if [ "${cmd_rc}" = "0" ]; then
  ssh-keygen -lf "${known_hosts}" || cmd_rc=1
fi

exit "${cmd_rc}"
