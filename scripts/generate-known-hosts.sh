#!/usr/bin/env sh
cmd_rc=0

script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
repo_dir="$(cd "${script_dir}/.." 2>/dev/null && pwd)"
repo_parent="$(dirname "${repo_dir}")"

mask_private() {
  sed \
    -e "s#${HOME}#<home>#g" \
    -e "s#${repo_parent}#<repos>#g" \
    -e 's/[[:alnum:]_.+-][[:alnum:]_.+-]*@[[:alnum:]_.-][[:alnum:]_.-]*/<redacted-email>/g'
}

export KO_REPO_DIR="${repo_dir}"
# shellcheck disable=SC1091
. "${repo_dir}/env/load_env.sh" || cmd_rc=1

tmp_dir="${repo_dir}/.tmp/known-hosts-$(date -u +%Y%m%dT%H%M%SZ)"
candidate="${tmp_dir}/known_hosts.candidate"
fingerprints="${tmp_dir}/known_hosts.fingerprints"

mkdir -p "${tmp_dir}" || cmd_rc=1
: > "${candidate}" || cmd_rc=1

extract_ed25519_key() {
  awk '$1 == "ssh-ed25519" { print $1 " " $2; found=1; exit } END { if (!found) exit 1 }'
}

add_known_host_line() {
  names="$1"
  key_material="$2"

  if [ -z "${key_material}" ]; then
    printf 'FAIL | empty key material for %s\n' "${names}" | mask_private
    cmd_rc=1
    return
  fi

  printf '%s %s\n' "${names}" "${key_material}" >> "${candidate}" || cmd_rc=1
}

printf '\n== fetch host keys over authenticated SSH ==\n' | mask_private
printf 'INFO | this uses your existing trusted admin SSH path, not unauthenticated ssh-keyscan\n'

if [ "${cmd_rc}" = "0" ]; then
  mgmt_key="$(
    ssh -o BatchMode=yes "${KO_ADMIN_USER}@${KO_MGMT_PUBLIC_ENTRY}" \
      'cat /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null | extract_ed25519_key
  )"
  if [ "$?" = "0" ]; then
    add_known_host_line "${KO_PROJECT_PREFIX}-mgmt-01,${KO_MGMT_PUBLIC_ENTRY}" "${mgmt_key}"
    printf 'OK | fetched %s-mgmt-01 host key\n' "${KO_PROJECT_PREFIX}" | mask_private
  else
    printf 'FAIL | could not fetch mgmt host key over authenticated SSH\n' | mask_private
    cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  egress_key="$(
    ssh -o BatchMode=yes "${KO_ADMIN_USER}@${KO_EGRESS_PUBLIC_ENTRY}" \
      'cat /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null | extract_ed25519_key
  )"
  if [ "$?" = "0" ]; then
    add_known_host_line "${KO_PROJECT_PREFIX}-egress-01,${KO_EGRESS_PUBLIC_ENTRY}" "${egress_key}"
    printf 'OK | fetched %s-egress-01 host key\n' "${KO_PROJECT_PREFIX}" | mask_private
  else
    printf 'FAIL | could not fetch egress host key over authenticated SSH\n' | mask_private
    cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  auth_key="$(
    ssh -o BatchMode=yes -J "${KO_ADMIN_USER}@${KO_MGMT_PUBLIC_ENTRY}" \
      "${KO_ADMIN_USER}@${KO_AUTH_01_PRIVATE_IP}" \
      'cat /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null | extract_ed25519_key
  )"
  if [ "$?" = "0" ]; then
    add_known_host_line "${KO_PROJECT_PREFIX}-auth-01,${KO_AUTH_01_PRIVATE_IP}" "${auth_key}"
    printf 'OK | fetched %s-auth-01 host key\n' "${KO_PROJECT_PREFIX}" | mask_private
  else
    printf 'FAIL | could not fetch auth host key over authenticated SSH jump\n' | mask_private
    cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  ingress_key="$(
    ssh -o BatchMode=yes -J "${KO_ADMIN_USER}@${KO_MGMT_PUBLIC_ENTRY}" \
      "${KO_ADMIN_USER}@${KO_INGRESS_01_PRIVATE_IP}" \
      'cat /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null | extract_ed25519_key
  )"
  if [ "$?" = "0" ]; then
    add_known_host_line "${KO_PROJECT_PREFIX}-ingress-01,${KO_INGRESS_01_PRIVATE_IP}" "${ingress_key}"
    printf 'OK | fetched %s-ingress-01 host key\n' "${KO_PROJECT_PREFIX}" | mask_private
  else
    printf 'FAIL | could not fetch ingress host key over authenticated SSH jump\n' | mask_private
    cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  apps_key="$(
    ssh -o BatchMode=yes -J "${KO_ADMIN_USER}@${KO_MGMT_PUBLIC_ENTRY}" \
      "${KO_ADMIN_USER}@${KO_APPS_01_PRIVATE_IP}" \
      'cat /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null | extract_ed25519_key
  )"
  if [ "$?" = "0" ]; then
    add_known_host_line "${KO_PROJECT_PREFIX}-apps-01,${KO_APPS_01_PRIVATE_IP}" "${apps_key}"
    printf 'OK | fetched %s-apps-01 host key\n' "${KO_PROJECT_PREFIX}" | mask_private
  else
    printf 'FAIL | could not fetch apps host key over authenticated SSH jump\n' | mask_private
    cmd_rc=1
  fi
fi

printf '\n== candidate validation ==\n' | mask_private
if [ "${cmd_rc}" = "0" ]; then
  if grep -E 'PRIVATE KEY|BEGIN OPENSSH PRIVATE KEY|BEGIN .* PRIVATE KEY' "${candidate}" >/dev/null 2>&1; then
    printf 'FAIL | candidate appears to contain private key material\n'
    cmd_rc=1
  else
    printf 'OK | no private key marker found in candidate\n'
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  line_count="$(wc -l < "${candidate}" | tr -d ' ')"
  if [ "${line_count}" = "5" ]; then
    printf 'OK | candidate contains 5 host key lines\n'
  else
    printf 'FAIL | candidate contains %s lines, expected 5\n' "${line_count}"
    cmd_rc=1
  fi
fi

if [ "${cmd_rc}" = "0" ]; then
  ssh-keygen -lf "${candidate}" > "${fingerprints}" || cmd_rc=1
fi

printf '\n== fingerprints ==\n'
if [ -f "${fingerprints}" ]; then
  cat "${fingerprints}" | mask_private
fi

printf '\n== diff against current common/known_hosts ==\n' | mask_private
if [ -f "${repo_dir}/common/known_hosts" ]; then
  diff -u "${repo_dir}/common/known_hosts" "${candidate}" 2>&1 | mask_private || true
else
  printf 'INFO | common/known_hosts does not exist yet\n'
fi

printf '\n== result ==\n' | mask_private
if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | candidate created: %s\n' "${candidate}" | mask_private
  printf 'INFO | review fingerprints above\n'
  printf 'INFO | to accept this candidate, run:\n'
  printf 'cp "%s" "%s"\n' "${candidate}" "${repo_dir}/common/known_hosts" | mask_private
else
  printf 'FAIL | known_hosts candidate generation failed\n'
fi

exit "${cmd_rc}"
