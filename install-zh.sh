#!/usr/bin/env bash
# =============================================================================
# ARTEX 汉化版 一键部署（Docker）
#
# 在任意一台装了 Docker 的 Linux 服务器上：
#   curl -fsSL https://raw.githubusercontent.com/Linyueying/ARTEX-zh-cn/zh-cn/install-zh.sh | bash
# 或者先 clone 再跑：
#   git clone -b zh-cn https://github.com/Linyueying/ARTEX-zh-cn.git && cd ARTEX-zh-cn && ./install-zh.sh
#
# 它做的事：取仓库 → 生成 .env（随机 Postgres 密码）→ 指向预编译汉化镜像 →
#           docker compose up -d → 打印访问地址与后续步骤。
#
# 环境变量（都可选）：
#   ARTEX_DIR=/opt/artex-zh        安装目录（默认 /opt/artex-zh）
#   ARTEX_ZH_IMAGE=...             汉化镜像（默认 ghcr.io/linyueying/artex-zh-cn:latest）
#   ARTEX_ZH_TAG=0.3.21-zh         只指定版本号时的简写
#   ARTEX_PORT=8787                对外端口（默认 8787）
#   POSTGRES_PASSWORD=...          自带数据库密码（默认随机生成）
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/Linyueying/ARTEX-zh-cn.git"
REPO_BRANCH="${ARTEX_ZH_BRANCH:-zh-cn}"
DIR="${ARTEX_DIR:-/opt/artex-zh}"
IMAGE="${ARTEX_ZH_IMAGE:-ghcr.io/linyueying/artex-zh-cn:${ARTEX_ZH_TAG:-latest}}"
PORT="${ARTEX_PORT:-8787}"

info() { printf '\033[36m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- 1. 前置检查 ------------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "未找到 docker。先装：curl -fsSL https://get.docker.com | sh"
docker compose version >/dev/null 2>&1 || die "未找到 docker compose 插件（需要 v2）。"
command -v git >/dev/null 2>&1 || die "未找到 git。"

# ---- 2. 取仓库 --------------------------------------------------------------
if [ -f "$DIR/docker-compose.yml" ]; then
  info "目录已存在，更新代码：$DIR"
  git -C "$DIR" fetch --quiet origin "$REPO_BRANCH"
  git -C "$DIR" checkout --quiet "$REPO_BRANCH"
  git -C "$DIR" merge --ff-only --quiet "origin/$REPO_BRANCH" || warn "本地有改动，跳过快进合并"
else
  info "克隆仓库到 $DIR"
  mkdir -p "$(dirname "$DIR")"
  git clone --quiet -b "$REPO_BRANCH" "$REPO_URL" "$DIR"
fi
cd "$DIR"

# ---- 3. 生成 .env -----------------------------------------------------------
if [ ! -f .env ]; then
  umask 077
  cp .env.example .env
  if [ -z "${POSTGRES_PASSWORD:-}" ]; then
    POSTGRES_PASSWORD="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
  fi
  # 用 python/sed 皆可；这里统一走 python3 缺失时的 sed 兜底
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$POSTGRES_PASSWORD" "$IMAGE" <<'PY'
import re, sys, pathlib
pw, image = sys.argv[1], sys.argv[2]
p = pathlib.Path('.env'); s = p.read_text(encoding='utf-8')
s = re.sub(r'(?m)^POSTGRES_PASSWORD=.*$', 'POSTGRES_PASSWORD=' + pw, s)
if re.search(r'(?m)^ARTEX_ZH_IMAGE=', s):
    s = re.sub(r'(?m)^ARTEX_ZH_IMAGE=.*$', 'ARTEX_ZH_IMAGE=' + image, s)
else:
    s = s.replace('# ARTEX_ZH_IMAGE=ghcr.io/linyueying/artex-zh-cn:latest',
                  'ARTEX_ZH_IMAGE=' + image)
p.write_text(s, encoding='utf-8')
PY
  else
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
    sed -i "s|^# ARTEX_ZH_IMAGE=.*|ARTEX_ZH_IMAGE=${IMAGE}|" .env
  fi
  ok "已生成 .env（Postgres 密码为随机值，保存在 $DIR/.env，权限 600）"
else
  info "复用已有 .env"
fi

# 端口可用 ARTEX_PORT 覆盖
if [ "$PORT" != "8787" ]; then
  grep -q '^ARTEX_PORT=' .env 2>/dev/null && sed -i "s|^ARTEX_PORT=.*|ARTEX_PORT=${PORT}|" .env || echo "ARTEX_PORT=${PORT}" >> .env
fi

# ---- 4. 拉镜像并启动 --------------------------------------------------------
info "拉取汉化镜像：$IMAGE"
if ! docker pull "$IMAGE"; then
  die "拉取失败。若提示 denied/unauthorized，说明镜像不是公开的——请到 GitHub 仓库的 Packages 页面把包设为 public，或先 docker login ghcr.io。"
fi

info "启动服务（postgres + artex）"
docker compose up -d

# ---- 5. 等待就绪并汇报 ------------------------------------------------------
info "等待就绪…"
for i in $(seq 1 30); do
  if curl -fsS -m 2 "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then break; fi
  sleep 2
done

echo
if curl -fsS -m 3 "http://127.0.0.1:${PORT}/api/health" 2>/dev/null; then
  echo
  ok "ARTEX 汉化版已启动：http://127.0.0.1:${PORT}"
else
  warn "健康检查没通过，看看日志：cd $DIR && docker compose logs --tail=50 artex"
fi

cat <<EOF

后续步骤：
  1) 浏览器打开 http://<本机IP>:${PORT}/setup 设置管理员密码（用户名固定 ARTEX）
     —— 公网可达的机器请立刻设置，/api/auth/init 不需要凭证。
  2) 配置 LLM：页面「系统 → LLM」新建配置档，或用 .env 里的
     ARTEX_LLM_PROVIDER / ARTEX_LLM_MODEL / ARTEX_LLM_BASE_URL / OPENAI_API_KEY。
  3) 常用命令（都在 $DIR 下）：
       docker compose logs -f artex      # 看日志
       docker compose pull artex && docker compose up -d artex   # 升级
       docker compose down               # 停止
  4) 反代 / HTTPS：见仓库 README 的「反向代理部署」一节。

注意：${PORT} 默认对所有网卡开放。公网机器建议只绑 127.0.0.1 并加 nginx 反代，
      或在云安全组里限制来源 IP。
EOF
