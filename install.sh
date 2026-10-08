#!/usr/bin/env bash
#
# Публичный загрузчик установщика animus.
#
# Запрашивает GitHub-токен, скачивает приватный install.sh из SOURCE_REPO,
# запускает его и удаляет скачанный файл по завершении. Без доступа к
# приватному репозиторию запуск завершается отказом.
#
# Переменные окружения:
#   GITHUB_TOKEN        токен GitHub (иначе берётся из ./<service>/.env или спросит)
#   Остальные параметры запрашиваются при первой настройке установленного сервиса.

set -euo pipefail

SOURCE_REPO="matrixd0t/animus"
BRANCH="master"
API="https://api.github.com"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    GREEN=$'\033[1;32m'
    RED=$'\033[1;31m'
    RESET=$'\033[0m'
else
    GREEN=""
    RED=""
    RESET=""
fi
log() { printf '%s[bootstrap]%s %s\n' "${GREEN}" "${RESET}" "$*"; }
die() { printf '%s[bootstrap]%s %s\n' "${RED}" "${RESET}" "$*" >&2; exit 1; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    printf 'Usage: sudo bash install.sh [--no-tail]\nInstalls into ./<SERVICE_NAME> in the current directory.\n'
    exit 0
fi

[[ ${EUID} -eq 0 ]] || die "запустите от root: sudo bash install.sh"

command -v curl >/dev/null 2>&1 || die "нужен curl (apt-get install -y curl)"

token="${GITHUB_TOKEN:-}"
if [[ -z "${token}" ]]; then
    service="${SERVICE_NAME:-}"
    if [[ -z "${service}" && -f .env ]]; then
        service="$(grep -E '^SERVICE_NAME=' .env 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
    fi
    service="${service:-animus}"
    if [[ "${service}" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
        token="$(grep -E '^GITHUB_TOKEN=' "${service}/.env" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
    fi
fi
if [[ -z "${token}" ]]; then
    [[ -t 0 ]] || die "задайте GITHUB_TOKEN в окружении или запустите установщик в интерактивном терминале"
    printf 'GitHub token (scope repo, ввод скрыт): ' >&2
    read -r -s token
    printf '\n' >&2
fi
[[ -n "${token}" ]] || die "токен не задан"

tmp="$(mktemp)"
self=""
if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    self="$(readlink -f "${BASH_SOURCE[0]}")"
fi
trap 'rm -f "${tmp}"; if [[ -n "${self}" ]]; then rm -f "${self}"; fi' EXIT

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
bash "${tmp}" "$@"
