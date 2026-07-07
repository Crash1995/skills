#!/usr/bin/env bash
set -Eeuo pipefail

YES="0"
HERMES_USER="hermes"
HERMES_HOME_DIR="/home/hermes/.hermes"
HOME_EXPLICIT="0"
WORKSPACE="/srv/hermes-workspace"
INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
SKIP_INSTALL="0"
SKIP_SYSTEMD="0"

usage() {
  cat <<'EOF'
Usage: bootstrap_no_docker.sh --yes [options]

Idempotent clean-VPS bootstrap for Hermes without Docker.
Run as root. Does not print secrets and does not configure Telegram tokens.

Options:
  --yes                  Required. Confirms server changes.
  --user USER            Hermes Linux user. Default: hermes.
  --workspace PATH       Workspace path. Default: /srv/hermes-workspace.
  --home PATH            Hermes home/config path. Default: /home/USER/.hermes.
  --install-url URL      Hermes install script URL.
  --skip-install         Do not run Hermes installer.
  --skip-systemd         Do not install/refresh hermes-gateway.service.
  -h, --help             Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes) YES="1"; shift ;;
    --user) HERMES_USER="${2:?missing user}"; shift 2 ;;
    --workspace) WORKSPACE="${2:?missing workspace}"; shift 2 ;;
    --home) HERMES_HOME_DIR="${2:?missing home}"; HOME_EXPLICIT="1"; shift 2 ;;
    --install-url) INSTALL_URL="${2:?missing install url}"; shift 2 ;;
    --skip-install) SKIP_INSTALL="1"; shift ;;
    --skip-systemd) SKIP_SYSTEMD="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ "$YES" != "1" ]; then
  echo "Refusing to change server without --yes." >&2
  usage
  exit 3
fi

if [ "$(id -u)" != "0" ]; then
  echo "Run as root." >&2
  exit 1
fi

if [ "$HOME_EXPLICIT" != "1" ]; then
  HERMES_HOME_DIR="/home/${HERMES_USER}/.hermes"
fi

case "$WORKSPACE" in
  /srv/*) ;;
  *) echo "Refusing workspace outside /srv by default: $WORKSPACE" >&2; exit 2 ;;
esac

HERMES_BIN="/home/${HERMES_USER}/.local/bin/hermes"

run() {
  printf '$ %s\n' "$*"
  "$@"
}

run_as_hermes() {
  su -s /bin/bash - "$HERMES_USER" -c "$*"
}

echo "BOOTSTRAP_NO_DOCKER_START"

if ! id "$HERMES_USER" >/dev/null 2>&1; then
  run useradd --create-home --shell /bin/bash "$HERMES_USER"
fi

run mkdir -p "$HERMES_HOME_DIR" "$WORKSPACE" "$HERMES_HOME_DIR/cache/documents"
run chown -R "$HERMES_USER:$HERMES_USER" "$HERMES_HOME_DIR" "$WORKSPACE"
run chmod 700 "$HERMES_HOME_DIR"

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  run apt-get update
  run apt-get install -y ca-certificates curl git python3 python3-venv sudo xz-utils
else
  echo "WARN APT_UNAVAILABLE install prerequisites manually if installer fails"
fi

if [ "$SKIP_INSTALL" != "1" ]; then
  if [ -x "$HERMES_BIN" ]; then
    echo "OK HERMES_ALREADY_INSTALLED"
  else
    run_as_hermes "curl -fsSL '$INSTALL_URL' -o /tmp/hermes-install.sh"
    run_as_hermes "bash /tmp/hermes-install.sh --skip-browser"
  fi
fi

if [ ! -x "$HERMES_BIN" ]; then
  echo "FAIL HERMES_NOT_INSTALLED_AFTER_BOOTSTRAP" >&2
  exit 1
fi

run_as_hermes "'$HERMES_BIN' config set terminal.backend local"
run_as_hermes "'$HERMES_BIN' config set terminal.cwd '$WORKSPACE'"
run_as_hermes "'$HERMES_BIN' config set terminal.env_passthrough '[]'"
run_as_hermes "'$HERMES_BIN' config set approvals.mode smart"
run_as_hermes "'$HERMES_BIN' config set approvals.cron_mode deny"

if [ ! -f "$HERMES_HOME_DIR/.env.example" ]; then
  cat > "$HERMES_HOME_DIR/.env.example" <<'EOF'
TELEGRAM_BOT_TOKEN=
TELEGRAM_ALLOWED_USERS=
GATEWAY_ALLOW_ALL_USERS=false
EOF
  run chown "$HERMES_USER:$HERMES_USER" "$HERMES_HOME_DIR/.env.example"
  run chmod 600 "$HERMES_HOME_DIR/.env.example"
fi

if [ "$SKIP_SYSTEMD" != "1" ]; then
  HOME="/home/$HERMES_USER" USER="$HERMES_USER" LOGNAME="$HERMES_USER" HERMES_HOME="$HERMES_HOME_DIR" \
    "$HERMES_BIN" gateway restart --system
fi

"$HERMES_BIN" --version || true
"$HERMES_BIN" config check || true
systemctl is-active hermes-gateway || true

cat <<EOF
BOOTSTRAP_NO_DOCKER_DONE
NEXT:
- complete OpenAI Codex OAuth as user $HERMES_USER
- add Telegram token/user allowlist only if Telegram gateway is needed
- run scripts/fast_doctor.sh
EOF
