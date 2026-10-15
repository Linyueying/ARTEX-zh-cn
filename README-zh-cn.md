# ARTEX 汉化版

基于 [RuoJi6/ARTEX](https://github.com/RuoJi6/ARTEX) 的简体中文界面版本，锁定上游 **v0.3.21**。

汉化改动在 `zh-cn` 分支：相对上游 `main` 的一个提交，45 个文件。
**只改界面文案与 4 行日志，不改任何业务逻辑、API 契约与数据库结构** ——
与官方版数据完全兼容，可随时来回切换。

---

## 一键部署（推荐）

任意一台装了 Docker 的 Linux 服务器：

```bash
curl -fsSL https://raw.githubusercontent.com/Linyueying/ARTEX-zh-cn/zh-cn/install-zh.sh | bash
```

默认装到 `/opt/artex-zh`。脚本按顺序尝试两条取镜像的路：

| | 路径 | 耗时 | 前提 |
|---|---|---|---|
| **A** | 直接拉预编译镜像 `ghcr.io/linyueying/artex-zh-cn:latest` | 快 | GHCR 包需为 public（或先 `docker login ghcr.io`） |
| **B** | 下载 [Releases](https://github.com/Linyueying/ARTEX-zh-cn/releases) 里的预编译二进制，本地秒级打成镜像 | ~1 分钟 | 能拉到官方基镜像 `ruoji6/artex` |

A 失败会自动落到 B，**不需要 Go / Node，也不重新编译**。

可用环境变量微调：

| 变量 | 默认 | 说明 |
|---|---|---|
| `ARTEX_DIR` | `/opt/artex-zh` | 安装目录 |
| `ARTEX_ZH_IMAGE` | `ghcr.io/linyueying/artex-zh-cn:latest` | 汉化镜像 |
| `ARTEX_ZH_RELEASE` | `zh-0.3.21` | Release 标签（B 路径用） |
| `ARTEX_ZH_SKIP_PULL` | 空 | 设 `1` 跳过 A 路径，直接走 B |
| `ARTEX_PORT` | `8787` | 对外端口 |
| `ARTEX_PROXY_PORT` | `ARTEX_PORT + 1` | 流量录制代理端口（只绑 `127.0.0.1`） |
| `POSTGRES_PASSWORD` | 随机 | 数据库密码 |

装完立刻做两件事：
1. 打开 `http://<IP>:8787/setup` 设置管理员密码（用户名固定 `ARTEX`）。
   **公网可达的机器请马上设 —— `/api/auth/init` 不需要任何凭证。**
2. 配 LLM：页面「系统 → LLM」新建配置档，或填 `.env` 里的
   `ARTEX_LLM_PROVIDER` / `ARTEX_LLM_MODEL` / `ARTEX_LLM_BASE_URL` / `OPENAI_API_KEY`。

---

## 其他部署方式

### 方式二：手动用预编译镜像

```bash
git clone -b zh-cn https://github.com/Linyueying/ARTEX-zh-cn.git
cd ARTEX-zh-cn
cp .env.example .env
# 改 POSTGRES_PASSWORD，并加上：
#   ARTEX_ZH_IMAGE=ghcr.io/linyueying/artex-zh-cn:latest
docker compose up -d
```

`docker-compose.override.yml` 会把 `artex` 服务指向 `ARTEX_ZH_IMAGE`，
其余（postgres、端口、卷）沿用上游的 `docker-compose.yml`。
`ARTEX_ZH_IMAGE` 留空则用本地构建的 `artex-zh:local`。

### 方式三：本地自建镜像

要改代码、或不想依赖任何 registry：

```bash
git clone -b zh-cn https://github.com/Linyueying/ARTEX-zh-cn.git
cd ARTEX-zh-cn
./build-zh.sh          # 前端导出 → go:embed 编译 → 打成本地镜像 artex-zh:local
cp .env.example .env   # 填 POSTGRES_PASSWORD
docker compose up -d
```

`build-zh.sh` 全程在 Docker 里跑（宿主机不需要 Go / Node），约 7 分钟。
**内存小的机器（≤2 GiB）先加 swap**，否则 Next.js 构建会 OOM：

```bash
fallocate -l 4G /swapfile2 && chmod 600 /swapfile2 && mkswap /swapfile2 && swapon /swapfile2
```

### 方式四：非 Docker（单二进制 / systemd）

直接用 [Releases](https://github.com/Linyueying/ARTEX-zh-cn/releases) 里的
`artex-0.3.21-zh-linux-amd64.zip`（或 `-arm64`）：

```bash
unzip artex-0.3.21-zh-linux-amd64.zip && cd artex-0.3.21-zh-linux-amd64
cp config.example.json config.json    # 填 PostgreSQL 连接
./start.sh                            # → http://localhost:8787
```

二进制是**静态链接**的（`CGO_ENABLED=0`），不依赖任何共享库。
用 `start.sh` / `start.bat` 启动，别直接跑 `./artex` —— 守护脚本负责进程退出后重新
拉起，页面上那个「一键更新」靠它完成换装。

非 Docker 部署需要自己准备：
- **PostgreSQL**（写进 `config.json` 的 `database`，或用环境变量 `ARTEX_PG_DSN`）
- **工具链**：`nmap` / `ripgrep` / `curl` / `git` / `jq` / `python3` / `node 22` /
  `playwright + chromium` —— 官方镜像里预装了这些，agent 的工具调用依赖它们

要交叉编译其他平台（macOS / Windows / arm64）：

```bash
cd web && npm ci && NEXT_EXPORT=1 npm run build && cd ..
rm -rf server/webui/dist && mkdir -p server/webui && cp -r web/out server/webui/dist
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -tags embedui -o artex ./cmd/artex
```

---

## 汉化了什么

**前端 39 个文件**：偏好设置面板、shadcn 基础组件（分页 / 轮播 / 命令面板 /
对话框 / 侧边栏 / 加载态 / 滚动按钮 / 面包屑）、404 与兜底页、侧边栏搜索、
系统页零星字段（Model / Profile / Tokens / OK / Error / HTTP Basic Auth /
license 等）；日期选择器改用 `date-fns` 的 zh-CN locale（原来输出英文月份）；
`<html lang="en">` 改为 `zh-CN`；全库「API Key」统一为「API 密钥」。

**后端 4 行日志**（会显示在「日志」页）：启动监听 / 关闭 / 录制代理 / 引擎未配置。

**故意保留英文**：`LLM` / `Agent` / `Skill` / `MCP` / `Worker` / `Token` / `Webhook`、
品牌名（Anthropic / OpenAI / DeepSeek / Tavily / Telegram / Docker）、工具名
（Bash / Edit / Write / WebFetch）、正则与 API 参数。这些在上游自己的中文文案里
就是这么用的（侧边栏本来就是「LLM」「Agent」「Skill」），硬译反而更乱。

---

## 与上游同步

```bash
git remote add upstream https://github.com/RuoJi6/ARTEX.git   # 首次
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout zh-cn && git rebase main                          # 或 merge
./build-zh.sh && docker compose up -d --force-recreate artex
```

上游改了前端文案的话 `rebase` 可能有冲突，按语义合一下即可。

---

## 回滚成官方版

```bash
rm docker-compose.override.yml
docker compose up -d --force-recreate artex
```

或者直接用上游镜像：`ARTEX_IMAGE=ruoji6/artex docker compose up -d`。

---

## 说明

- 上游 [Autumn-27/ARTEX](https://github.com/Autumn-27/ARTEX) 已不可访问（404），
  本仓库基于仍在维护的二开版 [RuoJi6/ARTEX](https://github.com/RuoJi6/ARTEX)。
- 许可证跟随上游 **AGPL-3.0**。
- Docker 镜像基于官方镜像按 **digest 钉死**（`Dockerfile.zh` 里的
  `ruoji6/artex:latest@sha256:5c550744…`），避免上游把 `latest` 指向新版本后
  重建出「新运行时 + 旧二进制」的错配镜像。
