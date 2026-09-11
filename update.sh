#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${GCLI2API_REPO_URL:-https://github.com/qingan123/gcli2api.git}"
BRANCH="${GCLI2API_BRANCH:-master}"
APP_DIR="${GCLI2API_DIR:-$PWD/gcli2api}"
COMPOSE_FILE="$APP_DIR/docker-compose.local.yml"

log() { printf '[gcli2api-update] %s\n' "$*"; }
fail() { printf '[gcli2api-update][ERROR] %s\n' "$*" >&2; exit 1; }
command -v git >/dev/null 2>&1 || fail '缺少 git'
command -v docker >/dev/null 2>&1 || fail '缺少 docker'
docker info >/dev/null 2>&1 || fail 'Docker 未运行或当前用户无权限访问 Docker'
[[ -d "$APP_DIR/.git" ]] || fail "找不到仓库: $APP_DIR"
[[ -f "$APP_DIR/.env" ]] || fail "找不到 .env，已停止以保护配置"
[[ -f "$COMPOSE_FILE" ]] || fail "找不到部署文件: $COMPOSE_FILE"

cd "$APP_DIR"
old_commit=$(git rev-parse HEAD)
log "同步 $REPO_URL [$BRANCH]"
git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REPO_URL"
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"
new_commit=$(git rev-parse HEAD)

# The deployment compose file is generated locally and intentionally preserved.
log "重新构建项目镜像"
docker compose -f "$COMPOSE_FILE" build
docker compose -f "$COMPOSE_FILE" up -d --force-recreate

log "更新完成"
log "旧提交: $old_commit"
log "新提交: $new_commit"
log 'data、data/creds 和 .env 保留未动'
