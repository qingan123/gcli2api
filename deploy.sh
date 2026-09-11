#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${GCLI2API_REPO_URL:-https://github.com/qingan123/gcli2api.git}"
BRANCH="${GCLI2API_BRANCH:-master}"
APP_DIR="${GCLI2API_DIR:-$PWD/gcli2api}"
DATA_DIR="${GCLI2API_DATA_DIR:-$APP_DIR/data}"
IMAGE="${GCLI2API_IMAGE:-gcli2api:local}"
CONTAINER="${GCLI2API_CONTAINER:-gcli2api}"
PORT="${PORT:-7861}"

log() { printf '[gcli2api] %s\n' "$*"; }
fail() { printf '[gcli2api][ERROR] %s\n' "$*" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1"; }

require git
require docker
docker info >/dev/null 2>&1 || fail 'Docker 未运行或当前用户无权限访问 Docker'

if [[ -e "$APP_DIR" && ! -d "$APP_DIR/.git" ]]; then
  fail "目标目录已存在但不是 Git 仓库: $APP_DIR"
fi

if [[ ! -d "$APP_DIR/.git" ]]; then
  mkdir -p "$(dirname "$APP_DIR")"
  log "克隆仓库: $REPO_URL"
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  log "使用现有仓库: $APP_DIR"
fi

cd "$APP_DIR"
mkdir -p "$DATA_DIR/creds"

if [[ ! -f .env ]]; then
  read -r -s -p '请输入管理/API密码（输入隐藏）: ' PASSWORD
  printf '\n'
  [[ -n "$PASSWORD" ]] || fail '密码不能为空'
  umask 077
  printf 'PASSWORD=%s\nPORT=%s\nHOST=0.0.0.0\n' "$PASSWORD" "$PORT" > .env
  unset PASSWORD
  log '.env 已创建并设置为仅所有者可读'
fi

log "构建镜像: $IMAGE"
docker build -t "$IMAGE" .

cat > docker-compose.local.yml <<EOF
services:
  gcli2api:
    image: ${IMAGE}
    container_name: ${CONTAINER}
    restart: unless-stopped
    network_mode: host
    env_file:
      - .env
    volumes:
      - ./data/creds:/app/creds
      - ./data:/app/data
EOF

log '启动服务（保留 data 和 data/creds）'
docker compose -f docker-compose.local.yml up -d --force-recreate
log "部署完成: http://127.0.0.1:${PORT}"
