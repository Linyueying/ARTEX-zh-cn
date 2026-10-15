#!/usr/bin/env bash
# =============================================================================
# ARTEX 汉化版 一键部署（Docker）
#
# 在任意一台装了 Docker 的 Linux 服务器上：
#   curl -fsSL https://raw.githubusercontent.com/Linyueying/ARTEX-zh-cn/zh-cn/install-zh.sh | bash
# 或先 clone 再跑：
#   git clone -b zh-cn https://github.com/Linyueying/ARTEX-zh-cn.git
#   cd ARTEX-zh-cn && ./install-zh.sh
#
# 流程：取仓库 → 取汉化镜像 → 生成 .env（随机 Postgres 密码）→ docker compose up -d
#
# 镜像来源两条路，自动选：
#   A) 直接拉预编译镜像（最快；需 GHCR 包为 public，或先 docker login ghcr.io）
#   B) 拉不到就下载 Release 里的预编译二进制，本地秒级构建镜像
#      （不编译 Go/前端，只需拉官方基镜像）
#
# 环境变量（都可选）：
#   ARTEX_DIR=/opt/artex-zh        安装目录（默认 /opt/artex-zh）
#   ARTEX_ZH_IMAGE=...             指定镜像（默认 ghcr.io/linyueying/artex-zh-cn:latest）
#   ARTEX_ZH_TAG=0.3.21-zh         只指定版本标签时的简写
#   ARTEX_ZH_RELEASE=zh-0.3.21     Release 标签（B 路径用）
#   ARTEX_ZH_SKIP_PULL=1           跳过 A 路径，直接走 B
#   ARTEX_PORT=8787                对外端口（默认 8787）
#   ARTEX_PROXY_PORT=8788          流量录制代理端口（默认 = ARTEX_PORT + 1，只绑 127.0.0.1）
#   POSTGRES_PASSWORD=...          自带数据库密码（默认随机生成）
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/Linyueying/ARTEX-zh-cn.git"
REPO_BRANCH="${ARTEX_ZH_BRANCH:-zh-cn}"
DIR="${ARTEX_DIR:-/opt/artex-zh}"
IMAGE="${ARTEX_ZH_IMAGE:-ghcr.io/linyueying/artex-zh-cn:${ARTEX_ZH_TAG:-latest}}"
RELEASE_TAG="${ARTEX_ZH_RELEASE:-zh-0.3.21}"
PORT="${ARTEX_PORT:-8787}"
# 流量录制代理端口：默认 8787+1（同一台机器上跑第二份实例时不会撞车）
PROXY_PORT="${ARTEX_PROXY_PORT:-$((PORT + 1))}"

info() { printf '\033[36m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- 1. 前置检查 ------------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "未找到 docker。先装：curl -fsSL https://get.docker.com | sh"
docker compose version >/dev/null 2>&1 || die "未找到 docker compose 插件（需要 v2）。"
command -v git >/dev/null 2>&1 || die "未找到 git。"
command -v curl >/dev/null 2>&1 || die "未找到 curl。"

# docker-compose.override.yml 里用了 `!override` 标签（整体替换 ports），需 compose >= 2.24.0
CV="$(docker compose version --short 2>/dev/null | tr -d 'v' || true)"
if [ -n "$CV" ] && [ "$(printf '%s\n2.24.0\n' "$CV" | sort -V | head -1)" != "2.24.0" ]; then
  die "docker compose 版本 ${CV} 过旧（需 >= 2.24.0，override 用到 !override 标签）。
    请升级 compose，或删掉 docker-compose.override.yml 里的 ports 段后重试。"
fi

case "$(uname -m)" in
  x86_64|amd64)  ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) die "不支持的架构：$(uname -m)（预编译产物只有 amd64 / arm64）" ;;
esac

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

# ---- 3. 取汉化镜像 ----------------------------------------------------------
ZH_IMAGE=""
if [ "${ARTEX_ZH_SKIP_PULL:-0}" != "1" ] && docker pull "$IMAGE" >/dev/null 2>&1; then
  ok "已拉取预编译镜像：$IMAGE"
  ZH_IMAGE="$IMAGE"
else
  warn "拉取 $IMAGE 失败（可能尚未发布为 public）—— 改用预编译二进制 + 本地构建镜像"
  mkdir -p "dist/${ARCH}"
  BIN_URL="https://github.com/Linyueying/ARTEX-zh-cn/releases/download/${RELEASE_TAG}/artex-0.3.21-zh-linux-${ARCH}"
  info "下载预编译二进制：$BIN_URL"
  curl -fL --retry 3 --retry-delay 2 -o "dist/${ARCH}/artex" "$BIN_URL" \
    || die "下载失败。可改用源码自建：./build-zh.sh（约 7 分钟；内存 ≤2 GiB 先加 swap）"
  chmod +x "dist/${ARCH}/artex"
  ok "二进制已就位（$(du -h "dist/${ARCH}/artex" | cut -f1)）"
  info "本地构建镜像（只替换二进制，秒级）"
  docker build --build-arg "TARGETARCH=${ARCH}" -f Dockerfile.zh -t artex-zh:local . >/dev/null
  ZH_IMAGE="artex-zh:local"
  ok "镜像 artex-zh:local 构建完成"
fi

# ---- 4. 生成 .env -----------------------------------------------------------
if [ ! -f .env ]; then
  umask 077
  cp .env.example .env
  if [ -z "${POSTGRES_PASSWORD:-}" ]; then
    POSTGRES_PASSWORD="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$POSTGRES_PASSWORD" "$ZH_IMAGE" "$PORT" "$PROXY_PORT" <<'PY'
import re, sys, pathlib
pw, image, port, proxy = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
p = pathlib.Path('.env'); s = p.read_text(encoding='utf-8')
s = re.sub(r'(?m)^POSTGRES_PASSWORD=.*$', 'POSTGRES_PASSWORD=' + pw, s)
if re.search(r'(?m)^#? ?ARTEX_ZH_IMAGE=', s):
    s = re.sub(r'(?m)^#? ?ARTEX_ZH_IMAGE=.*$', 'ARTEX_ZH_IMAGE=' + image, s)
else:
    s += '\nARTEX_ZH_IMAGE=' + image + '\n'
if port != '8787' or proxy != '8788':
    s += 'ARTEX_PORT=' + port + '\n'
    s += 'ARTEX_PROXY_PORT=' + proxy + '\n'
p.write_text(s, encoding='utf-8')
PY
  else
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
    sed -i "s|^# ARTEX_ZH_IMAGE=.*|ARTEX_ZH_IMAGE=${ZH_IMAGE}|" .env
    if [ "$PORT" != "8787" ] || [ "$PROXY_PORT" != "8788" ]; then
      printf 'ARTEX_PORT=%s\nARTEX_PROXY_PORT=%s\n' "$PORT" "$PROXY_PORT" >> .env
    fi
  fi
  ok "已生成 .env（Postgres 密码随机，存在 $DIR/.env，权限 600）"
else
  info "复用已有 .env"
fi

# ---- 5. 启动 ----------------------------------------------------------------
info "启动服务（postgres + artex）"
docker compose up -d

info "等待就绪…"
for _ in $(seq 1 30); do
  curl -fsS -m 2 "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1 && break
  sleep 2
done

echo
if curl -fsS -m 3 "http://127.0.0.1:${PORT}/api/health" 2>/dev/null; then
  echo
  ok "ARTEX 汉化版已启动：http://127.0.0.1:${PORT}"
else
  warn "健康检查没通过，看日志：cd $DIR && docker compose logs --tail=50 artex"
fi

cat <<EOF

后续步骤：
  1) 浏览器打开 http://<本机IP>:${PORT}/setup 设置管理员密码（用户名固定 ARTEX）
     —— 公网可达的机器请立刻设置：/api/auth/init 不需要任何凭证。
  2) 配 LLM：页面「系统 → LLM」新建配置档，或填 .env 里的
     ARTEX_LLM_PROVIDER / ARTEX_LLM_MODEL / ARTEX_LLM_BASE_URL / OPENAI_API_KEY。
  3) 常用命令（都在 $DIR 下）：
       docker compose logs -f artex        # 看日志
       ./install-zh.sh                     # 升级（拉代码 → 重建镜像 → 重启）
       docker compose down                 # 停止
  4) HTTPS / 反代：见仓库 README 的「反向代理部署」一节。

注意：${PORT} 默认对所有网卡开放。公网机器建议只绑 127.0.0.1 再上 nginx 反代，
      或在云安全组里限制来源 IP。
EOF
