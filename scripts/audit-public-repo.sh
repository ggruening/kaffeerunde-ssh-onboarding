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

cd "${repo_dir}" || exit 1

scan_files="$(git ls-files -co --exclude-standard | sort)"

printf '\n== public repo audit: file set ==\n'
printf '%s\n' "${scan_files}" | mask_private

printf '\n== public repo audit: forbidden file names ==\n'
if [ -z "${scan_files}" ]; then
  printf 'FAIL | no candidate files found\n'
  exit 1
fi

if printf '%s\n' "${scan_files}" | grep -E '(^|/)(\.tmp|\.test-homes|env/local\.env\.sh|.*\.local(\.sh)?)$' >/dev/null 2>&1; then
  printf 'FAIL | local/temp/private file appears in candidate file set\n'
  cmd_rc=1
else
  printf 'OK | no local/temp/private files in candidate file set\n'
fi

printf '\n== public repo audit: private local paths ==\n'
if [ -n "${real_home}" ] && grep -R -F "${real_home}" ${scan_files} >/dev/null 2>&1; then
  printf 'FAIL | real HOME path found in candidate files\n'
  grep -R -n -F "${real_home}" ${scan_files} 2>/dev/null | mask_private
  cmd_rc=1
else
  printf 'OK | no real HOME path found in candidate files\n'
fi

if [ -n "${repo_parent}" ] && grep -R -F "${repo_parent}" ${scan_files} >/dev/null 2>&1; then
  printf 'FAIL | real repo parent path found in candidate files\n'
  grep -R -n -F "${repo_parent}" ${scan_files} 2>/dev/null | mask_private
  cmd_rc=1
else
  printf 'OK | no real repo parent path found in candidate files\n'
fi

printf '\n== public repo audit: secret markers ==\n'
secret_hits="$(mktemp "${TMPDIR:-/tmp}/kaffee-secret-hits.XXXXXX")"
secret_filtered="$(mktemp "${TMPDIR:-/tmp}/kaffee-secret-filtered.XXXXXX")"

grep -R -n -E 'BEGIN (OPENSSH|RSA|DSA|EC|ED25519).*PRIVATE KEY|PRIVATE KEY-----|ANSIBLE_VAULT|HCLOUD_TOKEN|HETZNER.*TOKEN|step_ca_runtime_password' ${scan_files} > "${secret_hits}" 2>/dev/null || true

# Erlaubte Treffer: Audit-/Guardrail-Code, der genau diese Marker sucht.
grep -v -E '^(scripts/audit-public-repo\.sh|scripts/generate-known-hosts\.sh|scripts/print-known-hosts-fingerprints\.sh):' "${secret_hits}" > "${secret_filtered}" || true

if [ -s "${secret_filtered}" ]; then
  printf 'FAIL | possible secret marker found\n'
  cat "${secret_filtered}" | mask_private
  cmd_rc=1
else
  printf 'OK | no unexpected secret/private-key markers found\n'
fi

rm -f "${secret_hits}" "${secret_filtered}"

printf '\n== public repo audit: operational details ==\n'
ops_hits="$(mktemp "${TMPDIR:-/tmp}/kaffee-ops-hits.XXXXXX")"
ops_filtered="$(mktemp "${TMPDIR:-/tmp}/kaffee-ops-filtered.XXXXXX")"

grep -R -n -E 'old-kuma|55522|permitopen=|backupserver|backup-server|authorized_keys' ${scan_files} > "${ops_hits}" 2>/dev/null || true

# Erlaubter Treffer: Audit-Code, der diese Marker sucht.
grep -v -E '^scripts/audit-public-repo\.sh:' "${ops_hits}" > "${ops_filtered}" || true

if [ -s "${ops_filtered}" ]; then
  printf 'FAIL | operational detail found that should stay out of public onboarding\n'
  cat "${ops_filtered}" | mask_private
  cmd_rc=1
else
  printf 'OK | no forbidden operational details found\n'
fi

rm -f "${ops_hits}" "${ops_filtered}"

printf '\n== public repo audit: known_hosts ==\n'
if [ -f common/known_hosts ]; then
  known_hosts_lines="$(wc -l < common/known_hosts | tr -d ' ')"
  if [ "${known_hosts_lines}" = "6" ]; then
    printf 'OK | common/known_hosts has 6 lines\n'
  else
    printf 'FAIL | common/known_hosts has %s lines, expected 6\n' "${known_hosts_lines}"
    cmd_rc=1
  fi

  if ssh-keygen -lf common/known_hosts >/dev/null 2>&1; then
    printf 'OK | common/known_hosts fingerprints parse successfully\n'
  else
    printf 'FAIL | common/known_hosts fingerprints do not parse\n'
    cmd_rc=1
  fi
else
  printf 'FAIL | common/known_hosts missing\n'
  cmd_rc=1
fi

printf '\n== public repo audit result ==\n'
if [ "${cmd_rc}" = "0" ]; then
  printf 'OK | public repo audit passed\n'
else
  printf 'FAIL | public repo audit failed\n'
fi

exit "${cmd_rc}"
