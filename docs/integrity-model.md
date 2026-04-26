# Integrity model

This repository is intended to be public but integrity-critical.

Threats:

- malicious changes to install/login scripts
- replacement of known_hosts material
- replacement of CA URL or CA fingerprint
- SSH config manipulation that redirects ProxyJump
- hidden secret exfiltration in shell or PowerShell scripts

Rules:

- no secrets in this repository
- no curl-pipe-shell as the preferred installation method
- review scripts before running them on foreign machines
- keep scripts small and readable
- generated trust material must be reproducible
- protect the public Git repository before publishing
- prefer signed commits/tags for released versions
