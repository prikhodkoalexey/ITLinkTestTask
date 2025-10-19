#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SOURCE="${REPO_ROOT}/githooks/pre-commit"
HOOK_TARGET="${REPO_ROOT}/.git/hooks/pre-commit"

if [ ! -f "${HOOK_SOURCE}" ]; then
  echo "Не найден шаблон pre-commit: ${HOOK_SOURCE}" >&2
  exit 1
fi

echo "Устанавливаю pre-commit hook..."
mkdir -p "${REPO_ROOT}/.git/hooks"
if [ -f "${HOOK_TARGET}" ] || [ -L "${HOOK_TARGET}" ]; then
  rm -f "${HOOK_TARGET}"
fi
ln -s "${HOOK_SOURCE}" "${HOOK_TARGET}"
chmod +x "${HOOK_SOURCE}" "${HOOK_TARGET}"
echo "Готово: pre-commit теперь ссылается на ${HOOK_SOURCE}" 
