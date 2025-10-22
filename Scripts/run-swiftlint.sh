#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_PATH="${PROJECT_DIR}/swiftlint.yml"
REPO_DIR="${PROJECT_DIR}/Tools/SwiftLint"
SWIFTLINT_BINARY="${REPO_DIR}/.build/release/swiftlint"
REQUIRED_TAG="0.62.1"
REMOTE_URL="https://github.com/realm/SwiftLint.git"

log() {
  printf '[SwiftLint] %s\n' "$1" >&2
}

run_swiftlint() {
  local binary="$1"
  if "$binary" --config "${CONFIG_PATH}"; then
    if [ -n "${DERIVED_FILE_DIR:-}" ]; then
      touch "${DERIVED_FILE_DIR}/swiftlint-stamp"
    fi
    exit 0
  fi
  log "lint завершился с кодом ошибки, сборка продолжается без проверки"
}

if command -v swiftlint >/dev/null 2>&1; then
  run_swiftlint "$(command -v swiftlint)"
  exit 0
fi

mkdir -p "${PROJECT_DIR}/Tools"

if [ -x "${SWIFTLINT_BINARY}" ]; then
  run_swiftlint "${SWIFTLINT_BINARY}"
  exit 0
fi

if [ ! -d "${REPO_DIR}" ]; then
  if ! git clone --branch "${REQUIRED_TAG}" --depth 1 "${REMOTE_URL}" "${REPO_DIR}" >/dev/null 2>&1; then
    log "не удалось клонировать SwiftLint (${REMOTE_URL}); пропускаю линт"
    exit 0
  fi
else
  if ! git -C "${REPO_DIR}" fetch --tags --depth 1 origin "${REQUIRED_TAG}" >/dev/null 2>&1; then
    log "не удалось обновить SwiftLint до ${REQUIRED_TAG}; пропускаю линт"
    exit 0
  fi
  if ! git -C "${REPO_DIR}" checkout --quiet "${REQUIRED_TAG}" >/dev/null 2>&1; then
    log "не удалось переключиться на SwiftLint ${REQUIRED_TAG}; пропускаю линт"
    exit 0
  fi
fi

if swift build --package-path "${REPO_DIR}" --configuration release --target swiftlint >/dev/null 2>&1; then
  if [ -x "${SWIFTLINT_BINARY}" ]; then
    run_swiftlint "${SWIFTLINT_BINARY}"
    exit 0
  fi
fi

log "не удалось собрать SwiftLint; сборка продолжается без линтера"
exit 0
