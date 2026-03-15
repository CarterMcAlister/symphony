#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${SYMPHONY_REPO_URL:-https://github.com/CarterMcAlister/symphony.git}"
REPO_REF="${SYMPHONY_REPO_REF:-main}"
SERVICE_NAME="${SYMPHONY_SERVICE_NAME:-symphony}"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER:-}}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[setup-server] %s\n' "$*"
}

die() {
  printf '[setup-server] error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    need_cmd sudo
    sudo "$@"
  fi
}

run_target() {
  local cmd="$1"

  if [[ "$(id -un)" == "${TARGET_USER}" ]]; then
    HOME="${TARGET_HOME}" bash -lc "${cmd}"
  else
    need_cmd sudo
    sudo -H -u "${TARGET_USER}" env HOME="${TARGET_HOME}" bash -lc "${cmd}"
  fi
}

ensure_supported_platform() {
  [[ "$(uname -s)" == "Linux" ]] || die "this script only supports Linux"
  [[ -r /etc/os-release ]] || die "missing /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release

  local family="${ID_LIKE:-} ${ID:-}"
  [[ "${family}" =~ (debian|ubuntu) ]] || die "this script currently supports Debian/Ubuntu servers"
  [[ "$(dpkg --print-architecture)" == "amd64" ]] || die "google chrome install in this script requires amd64"
}

resolve_target_user() {
  [[ -n "${TARGET_USER}" ]] || die "TARGET_USER is not set"
  [[ "${TARGET_USER}" != "root" ]] || die "run this as a non-root user or set TARGET_USER to the login user"

  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  [[ -n "${TARGET_HOME}" ]] || die "could not resolve home directory for ${TARGET_USER}"

  TARGET_REPO_DIR="${TARGET_REPO_DIR:-${TARGET_HOME}/symphony}"
  TARGET_APP_DIR="${TARGET_REPO_DIR}/elixir"
  TARGET_MISE_BIN="${TARGET_HOME}/.local/bin/mise"
  TARGET_AGENT_SLACK_BIN="${TARGET_HOME}/.local/bin/agent-slack"
  SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
}

install_apt_prereqs() {
  log "installing apt prerequisites"
  run_root apt-get update
  run_root apt-get install -y ca-certificates curl git gpg lsb-release unzip xz-utils
}

install_mise() {
  if run_target "test -x '${TARGET_MISE_BIN}'"; then
    log "mise already installed"
    return
  fi

  log "installing mise"
  run_target "curl -fsSL https://mise.jdx.dev/install.sh | sh"
}

configure_shell_path() {
  log "configuring shell PATH for ${TARGET_USER}"
  run_target "mkdir -p '${TARGET_HOME}/.local/bin'"
  run_target "touch '${TARGET_HOME}/.bashrc' '${TARGET_HOME}/.zshrc'"
  run_target "grep -Fqx 'export PATH=\"\$HOME/.local/bin:\$PATH\"' '${TARGET_HOME}/.bashrc' || printf '\nexport PATH=\"\$HOME/.local/bin:\$PATH\"\n' >> '${TARGET_HOME}/.bashrc'"
  run_target "grep -Fqx 'export PATH=\"\$HOME/.local/bin:\$PATH\"' '${TARGET_HOME}/.zshrc' || printf '\nexport PATH=\"\$HOME/.local/bin:\$PATH\"\n' >> '${TARGET_HOME}/.zshrc'"
  run_target "grep -Fqx 'eval \"\$(mise activate bash)\"' '${TARGET_HOME}/.bashrc' || printf 'eval \"\$(mise activate bash)\"\n' >> '${TARGET_HOME}/.bashrc'"
  run_target "grep -Fqx 'eval \"\$(mise activate zsh)\"' '${TARGET_HOME}/.zshrc' || printf 'eval \"\$(mise activate zsh)\"\n' >> '${TARGET_HOME}/.zshrc'"
}

install_gh() {
  if command -v gh >/dev/null 2>&1; then
    log "gh already installed"
    return
  fi

  log "installing gh"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | run_root dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none
  run_root chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  printf 'deb [arch=%s signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
    "$(dpkg --print-architecture)" \
    | run_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  run_root apt-get update
  run_root apt-get install -y gh
}

install_railway() {
  if run_target "command -v railway >/dev/null 2>&1"; then
    log "railway already installed"
    return
  fi

  log "installing railway cli"
  run_target "bash <(curl -fsSL cli.new)"
}

install_chrome() {
  if command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
    log "google chrome already installed"
    return
  fi

  log "installing google chrome"
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | run_root gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
  printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main\n' \
    | run_root tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  run_root apt-get update
  run_root apt-get install -y google-chrome-stable
}

install_agent_slack() {
  if run_target "test -x '${TARGET_AGENT_SLACK_BIN}' || command -v agent-slack >/dev/null 2>&1"; then
    log "agent-slack already installed"
    return
  fi

  log "installing agent-slack cli"
  run_target "curl -fsSL https://raw.githubusercontent.com/stablyai/agent-slack/main/install.sh | sh"
}

clone_repo() {
  if run_target "test -d '${TARGET_REPO_DIR}/.git'"; then
    log "repo already exists at ${TARGET_REPO_DIR}; updating checkout"
    run_target "git -C '${TARGET_REPO_DIR}' fetch --all --prune"
    run_target "git -C '${TARGET_REPO_DIR}' checkout '${REPO_REF}'"
    run_target "git -C '${TARGET_REPO_DIR}' pull --ff-only origin '${REPO_REF}'"
    return
  fi

  log "cloning ${REPO_URL} to ${TARGET_REPO_DIR}"
  run_target "git clone --branch '${REPO_REF}' --single-branch '${REPO_URL}' '${TARGET_REPO_DIR}'"
}

sync_local_env() {
  local source_env="${SCRIPT_DIR}/elixir/.env"

  if [[ ! -f "${source_env}" ]]; then
    return
  fi

  if run_target "test -f '${TARGET_APP_DIR}/.env'"; then
    log "target .env already exists; leaving it unchanged"
    return
  fi

  log "copying local elixir/.env into cloned repo"
  run_root install -o "${TARGET_USER}" -g "$(id -gn "${TARGET_USER}")" -m 600 "${source_env}" "${TARGET_APP_DIR}/.env"
}

bootstrap_repo() {
  log "bootstrapping elixir app with mise"
  run_target "cd '${TARGET_APP_DIR}' && '${TARGET_MISE_BIN}' trust"
  run_target "cd '${TARGET_APP_DIR}' && '${TARGET_MISE_BIN}' install"
  run_target "cd '${TARGET_APP_DIR}' && '${TARGET_MISE_BIN}' exec -- mix local.hex --force"
  run_target "cd '${TARGET_APP_DIR}' && '${TARGET_MISE_BIN}' exec -- mix local.rebar --force"
  run_target "cd '${TARGET_APP_DIR}' && '${TARGET_MISE_BIN}' exec -- mix setup"
  run_target "cd '${TARGET_APP_DIR}' && '${TARGET_MISE_BIN}' exec -- mix build"
}

install_systemd_unit() {
  log "installing systemd unit ${SERVICE_NAME}.service"

  local unit
  unit=$(cat <<EOF
[Unit]
Description=Symphony Orchestrator
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${TARGET_USER}
WorkingDirectory=${TARGET_APP_DIR}
Environment=HOME=${TARGET_HOME}
Environment=PATH=${TARGET_HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-${TARGET_APP_DIR}/.env
ExecStart=${TARGET_MISE_BIN} exec -- ./bin/symphony ./WORKFLOW.md
Restart=always
RestartSec=5
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF
)

  printf '%s\n' "${unit}" | run_root tee "${SYSTEMD_UNIT}" >/dev/null
  run_root systemctl daemon-reload
  run_root systemctl enable --now "${SERVICE_NAME}.service"
}

verify_service() {
  log "verifying service state"
  run_root systemctl --no-pager --full status "${SERVICE_NAME}.service" || die "service failed to start"
}

main() {
  ensure_supported_platform
  resolve_target_user
  install_apt_prereqs
  install_mise
  configure_shell_path
  install_gh
  install_railway
  install_chrome
  install_agent_slack
  clone_repo
  sync_local_env
  bootstrap_repo
  install_systemd_unit
  verify_service
  log "setup complete"
}

main "$@"
