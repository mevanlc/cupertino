#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${REPO_ROOT}/Packages"
LOCAL_BIN="${CUPERTINO_BIN:-}"

DOCS_REPO="${CUPERTINO_DOCS_REPO:-${REPO_ROOT}/../cupertino-docs}"
BASE_LINK="${CUPERTINO_BASE_DIR:-${HOME}/.cupertino}"
SEARCH_DB="${BASE_LINK}/search.db"
SAMPLES_DB="${BASE_LINK}/samples.db"
SAMPLE_CODE_DIR="${BASE_LINK}/sample-code"

CODEX_CONFIG="${HOME}/.codex/config.toml"
CLAUDE_HOME_CONFIG="${HOME}/.claude/home-dotclaude.json"
CLAUDE_USER_CONFIG="${HOME}/.claude/.claude.json"
CLAUDE_DESKTOP_CONFIG="${HOME}/Library/Application Support/Claude/claude_desktop_config.json"

FORCE_BUILD="${CUPERTINO_FORCE_BUILD:-0}"
FORCE_REINDEX="${CUPERTINO_FORCE_REINDEX:-0}"

HAD_WARNING=0
HAD_VERIFY_FAILURE=0

log() {
  printf '[setup] %s\n' "$*"
}

warn() {
  printf '[setup] warning: %s\n' "$*" >&2
  HAD_WARNING=1
}

fail() {
  printf '[setup] error: %s\n' "$*" >&2
  exit 1
}

note_verify_failure() {
  printf '[setup] verify-fail: %s\n' "$*" >&2
  HAD_VERIFY_FAILURE=1
}

backup_path() {
  local path="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  mv "$path" "${path}.backup.${ts}"
}

ensure_dir_exists() {
  local path="$1"
  local label="$2"
  [[ -d "$path" ]] || fail "${label} not found: ${path}"
}

ensure_symlink() {
  local link_path="$1"
  local target_path="$2"

  if [[ -L "$link_path" ]]; then
    local current_target
    current_target="$(readlink "$link_path")"
    if [[ "$current_target" == "$target_path" ]]; then
      log "symlink ok: ${link_path} -> ${target_path}"
      return
    fi
    warn "updating symlink: ${link_path} -> ${current_target}"
    ln -sfn "$target_path" "$link_path"
    log "symlink updated: ${link_path} -> ${target_path}"
    return
  fi

  if [[ -e "$link_path" ]]; then
    warn "${link_path} exists and is not a symlink; backing it up before linking"
    backup_path "$link_path"
  fi

  ln -sfn "$target_path" "$link_path"
  log "symlink created: ${link_path} -> ${target_path}"
}

resolve_binary_path() {
  local bin_dir

  if [[ -n "$LOCAL_BIN" && -x "$LOCAL_BIN" ]]; then
    return
  fi

  bin_dir="$(
    cd "$PACKAGES_DIR"
    swift build -c release --show-bin-path
  )"

  if [[ -x "${bin_dir}/cupertino" ]]; then
    LOCAL_BIN="${bin_dir}/cupertino"
    return
  fi

  if [[ -x "${PACKAGES_DIR}/.build/release/cupertino" ]]; then
    LOCAL_BIN="${PACKAGES_DIR}/.build/release/cupertino"
    return
  fi

  LOCAL_BIN="${bin_dir}/cupertino"
}

ensure_binary() {
  ensure_dir_exists "$PACKAGES_DIR" "Packages directory"
  resolve_binary_path

  if [[ ! -x "$LOCAL_BIN" || "$FORCE_BUILD" == "1" ]]; then
    log "building Cupertino release binary"
    (
      cd "$PACKAGES_DIR"
      swift build -c release --product cupertino
    )
    resolve_binary_path
  else
    log "release binary present: ${LOCAL_BIN}"
  fi

  [[ -x "$LOCAL_BIN" ]] || fail "release binary not found after build: ${LOCAL_BIN}"
}

ensure_search_db() {
  if [[ -s "$SEARCH_DB" && "$FORCE_REINDEX" != "1" ]]; then
    log "search database present: ${SEARCH_DB}"
    return
  fi

  log "building documentation search database"
  "$LOCAL_BIN" save --base-dir "$BASE_LINK" --search-db "$SEARCH_DB"
  [[ -s "$SEARCH_DB" ]] || fail "search database was not created: ${SEARCH_DB}"
}

ensure_samples_db() {
  if [[ ! -d "$SAMPLE_CODE_DIR" ]]; then
    warn "sample-code directory not found at ${SAMPLE_CODE_DIR}; skipping samples.db"
    return
  fi

  if [[ -s "$SAMPLES_DB" && "$FORCE_REINDEX" != "1" ]]; then
    log "samples database present: ${SAMPLES_DB}"
    return
  fi

  log "building sample-code database"
  "$LOCAL_BIN" index --sample-code-dir "$SAMPLE_CODE_DIR" --database "$SAMPLES_DB"
  [[ -s "$SAMPLES_DB" ]] || fail "samples database was not created: ${SAMPLES_DB}"
}

verify_codex_mcp() {
  if [[ ! -f "$CODEX_CONFIG" ]]; then
    note_verify_failure "Codex config missing: ${CODEX_CONFIG}"
    print_codex_snippet
    return
  fi

  if rg -q '^\[mcp_servers\.cupertino\]$' "$CODEX_CONFIG"; then
    log "Codex MCP entry found in ${CODEX_CONFIG}"
    return
  fi

  note_verify_failure "Codex MCP entry missing from ${CODEX_CONFIG}"
  print_codex_snippet
}

verify_claude_file() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  rg -q '"cupertino"\s*:' "$file"
}

verify_claude_mcp() {
  if verify_claude_file "$CLAUDE_HOME_CONFIG"; then
    log "Claude Code MCP entry found in ${CLAUDE_HOME_CONFIG}"
    return
  fi

  if verify_claude_file "$CLAUDE_USER_CONFIG"; then
    log "Claude Code MCP entry found in ${CLAUDE_USER_CONFIG}"
    return
  fi

  if verify_claude_file "$CLAUDE_DESKTOP_CONFIG"; then
    log "Claude MCP entry found in ${CLAUDE_DESKTOP_CONFIG}"
    return
  fi

  note_verify_failure "Claude MCP entry not found in ~/.claude or Claude Desktop config"
  print_claude_snippet
}

print_codex_snippet() {
  cat <<EOF

Add this to ${CODEX_CONFIG}:

[mcp_servers.cupertino]
command = "${LOCAL_BIN}"
args = ["serve"]

EOF
}

print_claude_snippet() {
  cat <<EOF

Add this to one of:
  - ${CLAUDE_HOME_CONFIG}
  - ${CLAUDE_USER_CONFIG}
  - ${CLAUDE_DESKTOP_CONFIG}

{
  "mcpServers": {
    "cupertino": {
      "command": "${LOCAL_BIN}",
      "args": ["serve"]
    }
  }
}

Or register it with Claude Code:
  claude mcp add cupertino --scope user -- "${LOCAL_BIN}"

EOF
}

print_summary() {
  log "summary"
  printf '  repo: %s\n' "$REPO_ROOT"
  printf '  docs repo: %s\n' "$DOCS_REPO"
  printf '  base link: %s\n' "$BASE_LINK"
  printf '  binary: %s\n' "$LOCAL_BIN"
  printf '  search db: %s\n' "$SEARCH_DB"
  printf '  samples db: %s\n' "$SAMPLES_DB"
}

main() {
  log "starting Cupertino local setup"

  ensure_dir_exists "$REPO_ROOT" "repo root"
  ensure_dir_exists "$DOCS_REPO" "docs repo"

  ensure_symlink "$BASE_LINK" "$DOCS_REPO"
  ensure_binary
  ensure_search_db
  ensure_samples_db
  verify_codex_mcp
  verify_claude_mcp
  print_summary

  if [[ "$HAD_VERIFY_FAILURE" == "1" ]]; then
    fail "local data is ready, but one or more MCP client registrations are missing"
  fi

  if [[ "$HAD_WARNING" == "1" ]]; then
    log "completed with warnings"
    exit 0
  fi

  log "setup complete"
}

main "$@"
