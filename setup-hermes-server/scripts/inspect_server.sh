#!/usr/bin/env bash
set -Eeuo pipefail

INCLUDE_DOCKER=0
for arg in "$@"; do
  case "$arg" in
    --include-docker) INCLUDE_DOCKER=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

section() {
  printf '\n=== %s ===\n' "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@" 2>&1 || true
}

run_sh() {
  printf '$ %s\n' "$*"
  sh -c "$*" 2>&1 || true
}

section "identity"
run whoami
run id
run pwd

section "os and resources"
run_sh 'lsb_release -a 2>/dev/null || cat /etc/os-release'
run uname -a
run free -h
run df -h

section "network listeners"
run ss -tulpn

section "vpn services"
run_sh "systemctl list-units '*wg*' '*openvpn*' '*vpn*' --no-pager"
run wg show

section "firewall snapshot"
run ufw status verbose
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  run_sh 'sudo iptables-save | sed -n "1,180p"'
  run_sh 'sudo nft list ruleset | sed -n "1,220p"'
else
  echo "sudo unavailable without password; skipping iptables-save/nft ruleset"
fi

if [ "$INCLUDE_DOCKER" = "1" ]; then
  section "docker"
  run docker info
  run docker ps
  run docker network ls
fi

section "hermes"
HERMES_BIN="${HERMES_BIN:-/home/hermes/.local/bin/hermes}"
if [ -x "$HERMES_BIN" ]; then
  run "$HERMES_BIN" --version
  run "$HERMES_BIN" profile list
  run "$HERMES_BIN" gateway status
else
  echo "Hermes binary not found at $HERMES_BIN"
  run_sh 'command -v hermes || true'
fi

section "systemd unit"
run systemctl status hermes-gateway --no-pager -l
run systemctl cat hermes-gateway

section "notes"
echo "Read-only inspection complete."
echo "No .env files, API keys, bot tokens, or private key contents were printed."
