# Public/non-secret defaults for the kaffeerunde SSH onboarding.
# This file is intended to be safe for a public repository.

: "${KO_PROJECT_PREFIX:=kaffeerunde}"
: "${KO_ADMIN_USER:=ops}"

# Smallstep CA
: "${KO_STEP_CA_URL:=https://serverauth.kaffeerunde.todopc.de}"
: "${KO_STEP_CA_FINGERPRINT:=96fdff658e0508991480ce131a8ed2d89f5e09aecfc41292d6592776c53022b6}"
: "${KO_STEP_PROVISIONER:=ops-ssh-jwk}"

# Public entries
: "${KO_MGMT_PUBLIC_ENTRY:=mgmt.kaffeerunde.todopc.de}"
: "${KO_EGRESS_PUBLIC_ENTRY:=egress.kaffeerunde.todopc.de}"
: "${KO_MAIL_01_EXT_PUBLIC_ENTRY:=mail.gruening.cloud}"

# Private host IPs
: "${KO_AUTH_01_PRIVATE_IP:=10.42.0.3}"
: "${KO_INGRESS_01_PRIVATE_IP:=10.42.0.6}"
: "${KO_APPS_01_PRIVATE_IP:=10.42.0.8}"
: "${KO_APPS_02_EXT_WG_IP:=10.44.0.2}"

# Local client state; can be overridden by environment or env/local.env.sh
: "${KO_CLIENT_ROOT:=${HOME}/.config/${KO_PROJECT_PREFIX}-ssh}"
: "${KO_STEPPATH:=${KO_CLIENT_ROOT}/step}"
: "${KO_SSH_CONFIG:=${KO_CLIENT_ROOT}/config}"
: "${KO_KNOWN_HOSTS:=${KO_CLIENT_ROOT}/known_hosts}"
: "${KO_AGENT_SOCK:=${KO_CLIENT_ROOT}/ssh-agent.sock}"
: "${KO_AGENT_ENV:=${KO_CLIENT_ROOT}/ssh-agent.env}"

export KO_PROJECT_PREFIX
export KO_ADMIN_USER
export KO_STEP_CA_URL
export KO_STEP_CA_FINGERPRINT
export KO_STEP_PROVISIONER
export KO_MGMT_PUBLIC_ENTRY
export KO_EGRESS_PUBLIC_ENTRY
export KO_MAIL_01_EXT_PUBLIC_ENTRY
export KO_AUTH_01_PRIVATE_IP
export KO_INGRESS_01_PRIVATE_IP
export KO_APPS_01_PRIVATE_IP
export KO_APPS_02_EXT_WG_IP
export KO_CLIENT_ROOT
export KO_STEPPATH
export KO_SSH_CONFIG
export KO_KNOWN_HOSTS
export KO_AGENT_SOCK
export KO_AGENT_ENV
