#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_PATH="${PROJECT_DIR}/swiftlint.yml"
REPO_DIR="${PROJECT_DIR}/Tools/SwiftLint"
SWIFTLINT_BINARY="${REPO_DIR}/.build/release/swiftlint"
REQUIRED_TAG="0.62.1"
REMOTE_URL="https://github.com/realm/SwiftLint.git"

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint --config "${CONFIG_PATH}"
  exit 0
fi

mkdir -p "${PROJECT_DIR}/Tools"

if [ ! -d "${REPO_DIR}" ]; then
  git clone --branch "${REQUIRED_TAG}" --depth 1 "${REMOTE_URL}" "${REPO_DIR}"
else
  git -C "${REPO_DIR}" fetch --tags --depth 1 origin "${REQUIRED_TAG}"
  git -C "${REPO_DIR}" checkout --quiet "${REQUIRED_TAG}"
fi

swift build --package-path "${REPO_DIR}" --configuration release --target swiftlint
"${SWIFTLINT_BINARY}" --config "${CONFIG_PATH}"
