#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"
repo_parent="$(dirname "${repo_dir}")"

real_home="${HOME}"
real_client_root="${real_home}/.config/kaffeerunde-ssh"

mask_private() {
  sed \
    -e "s#${real_home}#<home>#g" \
    -e "s#${repo_parent}#<repos>#g" \
    -e 's/[[:alnum:]_.+-][[:alnum:]_.+-]*@[[:alnum:]_.-][[:alnum:]_.-]*/<redacted-email>/g'
}

tmp_base="${TMPDIR:-/tmp}"
test_root="$(mktemp -d "${tmp_base%/}/kaffeerunde-ssh-onboarding-empty-home.XXXXXX")"
test_home="${test_root}/home"
test_client_root="${test_home}/.config/kaffeerunde-ssh"
test_steppath="${test_client_root}/step"
test_ssh_config="${test_client_root}/config"
test_known_hosts="${test_client_root}/known_hosts"
test_agent_sock="${test_client_root}/ssh-agent.sock"
test_agent_env="${test_client_root}/ssh-agent.env"

mkdir -p "${test_home}" || cmd_rc=1

printf 'TEST_HOME=%s\n' "${test_home}" | mask_private

# env -i verhindert, dass exportierte KO_*-Variablen aus der echten
# Arbeitsshell in den Empty-Home-Test hineinlecken.
if [ "${cmd_rc}" = "0" ]; then
  env -i \
    HOME="${test_home}" \
    PATH="${PATH}" \
    KO_REPO_DIR="${repo_dir}" \
    KO_CLIENT_ROOT="${test_client_root}" \
    KO_STEPPATH="${test_steppath}" \
    KO_SSH_CONFIG="${test_ssh_config}" \
    KO_KNOWN_HOSTS="${test_known_hosts}" \
    KO_AGENT_SOCK="${test_agent_sock}" \
    KO_AGENT_ENV="${test_agent_env}" \
    "${repo_dir}/unix/install.sh" 2>&1 | mask_private

  install_rc=$?
  if [ "${install_rc}" != "0" ]; then
    cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  env -i \
    HOME="${test_home}" \
    PATH="${PATH}" \
    KO_REPO_DIR="${repo_dir}" \
    KO_CLIENT_ROOT="${test_client_root}" \
    KO_STEPPATH="${test_steppath}" \
    KO_SSH_CONFIG="${test_ssh_config}" \
    KO_KNOWN_HOSTS="${test_known_hosts}" \
    KO_AGENT_SOCK="${test_agent_sock}" \
    KO_AGENT_ENV="${test_agent_env}" \
    "${repo_dir}/scripts/render-config.sh" 2>&1 | mask_private

  render_rc=$?
  if [ "${render_rc}" != "0" ]; then
    cmd_rc=1
  fi
fi

printf '\n== generated files ==\n'
find "${test_root}" -maxdepth 6 -type f -print 2>/dev/null | sort | mask_private

printf '\n== rendered ssh config ==\n'
if [ -f "${test_ssh_config}" ]; then
  sed \
    -e "s#${test_home}#<test-home>#g" \
    -e "s#${real_home}#<home>#g" \
    -e 's/[[:alnum:]_.+-][[:alnum:]_.+-]*@[[:alnum:]_.-][[:alnum:]_.-]*/<redacted-email>/g' \
    "${test_ssh_config}"
else
  printf 'WARN | rendered config missing\n'
  cmd_rc=1
fi

printf '\n== isolation checks ==\n'

if grep -R "${real_client_root}" "${test_root}" >/dev/null 2>&1; then
  printf 'FAIL | real client root leaked into test files\n'
  cmd_rc=1
else
  printf 'OK | real client root not found in test files\n'
fi

if [ -f "${test_ssh_config}" ] && grep -F "${test_known_hosts}" "${test_ssh_config}" >/dev/null 2>&1; then
  printf 'OK | rendered config points to isolated known_hosts\n'
else
  printf 'FAIL | rendered config does not point to isolated known_hosts\n'
  cmd_rc=1
fi

if [ -f "${test_known_hosts}" ]; then
  printf 'OK | isolated known_hosts exists\n'
else
  printf 'FAIL | isolated known_hosts missing\n'
  cmd_rc=1
fi

if [ -f "${test_home}/.ssh/config" ] && grep -F "Include ${test_ssh_config}" "${test_home}/.ssh/config" >/dev/null 2>&1; then
  printf 'OK | user ssh config includes onboarding config\n'
else
  printf 'FAIL | user ssh config does not include onboarding config\n'
  cmd_rc=1
fi

if [ -f "${test_ssh_config}" ] && grep -F "IdentityAgent ${test_agent_sock}" "${test_ssh_config}" >/dev/null 2>&1; then
  printf 'OK | rendered config points to isolated agent socket\n'
else
  printf 'FAIL | rendered config does not point to isolated agent socket\n'
  cmd_rc=1
fi

ssh_g_output="${test_root}/ssh-g-apps-01.txt"
if ssh -G -F "${test_home}/.ssh/config" kaffeerunde-apps-01 > "${ssh_g_output}" 2>/dev/null; then
  printf 'OK | ssh parses installed include config\n'

  if grep -Fx 'user ops' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G uses onboarding user\n'
  else
    printf 'FAIL | ssh -G does not use onboarding user\n'
    cmd_rc=1
  fi

  if grep -Fx 'hostname 10.42.0.8' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G uses apps private IP\n'
  else
    printf 'FAIL | ssh -G does not use apps private IP\n'
    cmd_rc=1
  fi

  if grep -Fx 'stricthostkeychecking true' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G uses strict hostkey checking\n'
  else
    printf 'FAIL | ssh -G does not use strict hostkey checking\n'
    cmd_rc=1
  fi

  if grep -Fx 'updatehostkeys false' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G disables hostkey auto-update\n'
  else
    printf 'FAIL | ssh -G does not disable hostkey auto-update\n'
    cmd_rc=1
  fi

  if grep -Fx 'identityfile none' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G disables default identity files\n'
  else
    printf 'FAIL | ssh -G does not disable default identity files\n'
    cmd_rc=1
  fi

  if grep -Fx 'preferredauthentications publickey' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G uses publickey-only preferred auth\n'
  else
    printf 'FAIL | ssh -G does not prefer only publickey auth\n'
    cmd_rc=1
  fi

  if grep -Fx 'passwordauthentication no' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G disables password auth\n'
  else
    printf 'FAIL | ssh -G does not disable password auth\n'
    cmd_rc=1
  fi

  if grep -Fx 'kbdinteractiveauthentication no' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G disables keyboard-interactive auth\n'
  else
    printf 'FAIL | ssh -G does not disable keyboard-interactive auth\n'
    cmd_rc=1
  fi

  if grep -Fx 'identitiesonly no' "${ssh_g_output}" >/dev/null 2>&1; then
    printf 'OK | ssh -G allows dedicated agent identities\n'
  else
    printf 'FAIL | ssh -G may still block dedicated agent identities\n'
    cmd_rc=1
  fi
else
  printf 'FAIL | ssh cannot parse installed include config\n'
  cmd_rc=1
fi

printf '\n== cleanup test root ==\n'
case "${test_root}" in
  /tmp/kaffeerunde-ssh-onboarding-empty-home.*|/var/tmp/kaffeerunde-ssh-onboarding-empty-home.*)
    rm -rf "${test_root}" && printf 'OK | removed temporary test root\n' || cmd_rc=1
    ;;
  *)
    printf 'WARN | leaving unexpected test root in place: %s\n' "${test_root}" | mask_private
    ;;
esac

printf '\n== result ==\n'
if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | empty-home install/render test completed\n'
else
  printf 'FAIL | empty-home install/render test failed\n'
fi

exit "${cmd_rc}"
