#!/usr/bin/env sh
cmd_rc=0

repo_dir="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
repo_parent="$(dirname "${repo_dir}")"
real_home="${HOME}"

mask_private() {
  sed \
    -e "s#${real_home}#<home>#g" \
    -e "s#${repo_parent}#<repos>#g" \
    -e 's/[[:alnum:]_.+-][[:alnum:]_.+-]*@[[:alnum:]_.-][[:alnum:]_.-]*/<redacted-email>/g'
}

run_ssh_masked() {
  host="$1"
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/kaffee-ssh-test.XXXXXX")"

  ssh -o BatchMode=yes "${host}" \
    'printf "OK | host=%s user=%s\n" "$(hostname)" "$(whoami)"' \
    > "${tmp_out}" 2>&1

  ssh_rc=$?
  cat "${tmp_out}" | mask_private
  rm -f "${tmp_out}"

  return "${ssh_rc}"
}

for host in \
  kaffeerunde-mgmt-01 \
  kaffeerunde-egress-01 \
  kaffeerunde-auth-01 \
  kaffeerunde-ingress-01 \
  kaffeerunde-apps-01 \
  kaffeerunde-apps-02-ext
do
  printf '\n== ssh test: %s ==\n' "${host}"
  run_ssh_masked "${host}"
  host_rc=$?

  if [ "${host_rc}" = "0" ]; then
    printf 'OK | %s reachable\n' "${host}"
  else
    printf 'FAIL | %s failed with rc=%s\n' "${host}" "${host_rc}"
    cmd_rc=1
  fi
done

printf '\n== result ==\n'
if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | all onboarding SSH aliases work\n'
else
  printf 'FAIL | at least one onboarding SSH alias failed\n'
fi

exit "${cmd_rc}"
