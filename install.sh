#!/usr/bin/env bash
#
# Публичный загрузчик установщика animus.
#
# Запрашивает GitHub-токен, скачивает приватный install.sh из SOURCE_REPO,
# запускает его и удаляет скачанный файл по завершении. Без доступа к
# приватному репозиторию запуск завершается отказом.
#
# Переменные окружения:
#   ANIMUS_SOURCE_REPO  owner/repo приватного репозитория (matrixd0t/animus)
#   ANIMUS_BRANCH       ветка (master)
#   GITHUB_TOKEN        токен GitHub (иначе спросит)

set -euo pipefail

SOURCE_REPO="${ANIMUS_SOURCE_REPO:-matrixd0t/animus}"
BRANCH="${ANIMUS_BRANCH:-master}"
API="https://api.github.com"

log() { printf '\033[1;32m[bootstrap]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "запустите от root: sudo bash install.sh"

command -v curl >/dev/null 2>&1 || die "нужен curl (apt-get install -y curl)"

token="${GITHUB_TOKEN:-}"
if [[ -z "${token}" ]]; then
    printf 'GitHub token (scope repo, ввод скрыт): ' >&2
    read -r -s token
    printf '\n' >&2
fi
[[ -n "${token}" ]] || die "токен не задан"

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

log "проверяю доступ к ${SOURCE_REPO}"
if ! curl -fsSL \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.github.raw" \
        "${API}/repos/${SOURCE_REPO}/contents/install.sh?ref=${BRANCH}" \
        -o "${tmp}"; then
    die "нет доступа к ${SOURCE_REPO} (${BRANCH}) — проверьте токен и права"
fi

[[ -s "${tmp}" ]] || die "получен пустой install.sh"

log "запускаю ${SOURCE_REPO}@${BRANCH}/install.sh (временный файл будет удалён после завершения)"
export GITHUB_TOKEN="${token}"
bash "${tmp}"
