#!/usr/bin/env bash
set -uo pipefail

# Health check for the intended private apps-02-ext admin path:
# local -> kaffeerunde-mgmt-01 -> ingress-01 private IP -> apps-02-ext WireGuard IP.
# This intentionally does not test or enable public-direct SSH to apps-02-ext.

KO_PROJECT_PREFIX="${KO_PROJECT_PREFIX:-kaffeerunde}"
KO_ADMIN_USER="${KO_ADMIN_USER:-ops}"
KO_INGRESS_01_PRIVATE_IP="${KO_INGRESS_01_PRIVATE_IP:-10.42.0.6}"
KO_APPS_02_EXT_WG_IP="${KO_APPS_02_EXT_WG_IP:-10.44.0.2}"
MGMT_ALIAS="${KO_PROJECT_PREFIX}-mgmt-01"
APPS02_ALIAS="${KO_PROJECT_PREFIX}-apps-02-ext"

timed() {
  local title="$1"; shift
  printf '\n===== %s =====\n' "$title"
  set +e
  timeout --foreground --kill-after=3s 25s "$@"
  local rc=$?
  set -e
  if [ "$rc" = 124 ]; then
    echo 'TIMEOUT'
  fi
  printf '[rc=%s]\n' "$rc"
  return 0
}

printf 'START-COPY-HERE: onboarding-check-apps02-ssh-path\n'
printf '\n===== context =====\n'
printf 'mgmt_alias=%s\n' "$MGMT_ALIAS"
printf 'ingress_private=%s\n' "$KO_INGRESS_01_PRIVATE_IP"
printf 'apps02_wg=%s\n' "$KO_APPS_02_EXT_WG_IP"

timed 'A local -> mgmt-01' \
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$MGMT_ALIAS" 'printf "OK-mgmt\n"; hostname'

timed 'B local -> mgmt-01 -> ingress-01' \
  ssh -o BatchMode=yes -o ConnectTimeout=8 -J "$MGMT_ALIAS" "${KO_ADMIN_USER}@${KO_INGRESS_01_PRIVATE_IP}" 'printf "OK-ingress\n"; hostname'

timed 'C ingress-01 -> apps-02-ext tcp/22' \
  ssh -o BatchMode=yes -o ConnectTimeout=8 -J "$MGMT_ALIAS" "${KO_ADMIN_USER}@${KO_INGRESS_01_PRIVATE_IP}" "python3 - <<PY
import socket
host='${KO_APPS_02_EXT_WG_IP}'
s=socket.create_connection((host,22),timeout=6)
s.settimeout(6)
print('OK tcp %s:22 banner=%s' % (host, s.recv(128).decode('ascii','replace').strip()))
s.close()
PY"

timed 'D local -> apps-02-ext alias' \
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$APPS02_ALIAS" 'printf "OK-apps02-alias\n"; hostname'

printf '\n===== interpretation =====\n'
echo '- All rc=0 means the onboarding SSH aliases match the private apps-02-ext target path.'
echo '- If A fails, unlock/fix your local SSH agent first.'
echo '- If B fails, inspect mgmt-01 -> ingress-01 access.'
echo '- If C fails, inspect wg-ext-apps/routing/firewall from ingress-01 to apps-02-ext.'
echo '- If D fails while A/B/C work, inspect apps-02-ext alias hostkey/auth.'
printf 'END-COPY-HERE: onboarding-check-apps02-ssh-path\n'
