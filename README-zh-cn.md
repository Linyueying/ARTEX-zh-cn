# ARTEX 汉化版

基于 [RuoJi6/ARTEX](https://github.com/RuoJi6/ARTEX) 的简体中文界面版本，锁定上游 **v0.3.21**。

汉化改动在 `zh-cn` 分支（相对上游 `main` 的一个提交，45 个文件）。

---

## 一键部署（推荐）

任意装了 Docker 的 Linux 服务器：

```bash
curl -fsSL https://raw.githubusercontent.com/Linyueying/ARTEX-zh-cn/zh-cn/install-zh.sh | bash
```

脚本会：取仓库 → 生成 `.env`（随机 Postgres 密码）→ 拉预编译汉化镜像 → 启动 →
打印访问地址。默认装到 `/opt/artex-zh`。

可用环境变量微调：

| 变量 | 默认 | 说明 |
|---|---|---|
| `ARTEX_DIR` | `/opt/artex-zh` | 安装目录 |
| `ARTEX_ZH_IMAGE` | `ghcr.io/linyueying/artex-zh-cn:latest` | 汉化镜像 |
| `ARTEX_PORT` | `8787` | 对外端口 |

装完立刻做两件事：
1. 打开 `http://<IP>:8787/setup` 设置管理员密码（用户名固定 `ARTEX`）。
   **公网可达的机器请马上设，`/api/auth/init` 不需要任何凭证。**
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

### 方式三：本地自建镜像

不想依赖 GHCR，或要改代码：

```bash
git clone -b zh-cn https://github.com/Linyueying/ARTEX-zh-cn.git
cd ARTEX-zh-cn
./build-zh.sh          # 前端导出 → go:embed 编译 → 打成本地镜像 artex-zh:local
cp .env.example .env   # 填 POSTGRES_PASSWORD
docker compose up -d   # .env 里不设 ARTEX_ZH_IMAGE 就会用 artex-zh:local
```

`build-zh.sh` 全程在 Docker 里跑（宿主机不需要 Go / Node），约 7 分钟。
**内存小的机器（≤2 GiB）先加 swap**，否则 Next.js 构建会 OOM：

```bash
fallocate -l 4G /swapfile2 && chmod 600 /swapfile2 && mkswap /swapfile2 && swapon /swapfile2
```

### 方式四：非 Docker（单二进制 / systemd）

`build-zh.sh` 产出的是**静态链接**二进制（`CGO_ENABLED=0`，不依赖任何 `.so`），
可以直接裸跑，也可以交叉编译到其他平台：

```bash
# 在装了 Go 1.26.3+ 和 Node 22 的机器上
cd web && npm ci && NEXT_EXPORT=1 npm run build && cd ..
rm -rf server/webui/dist && mkdir -p server/webui && cp -r web/out server/webui/dist
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags embedui -o artex ./cmd/artex
./start.sh          # 用 start.sh 启动（守护 + 一键更新靠它换装）
```

非 Docker 部署需要自己准备：
- **PostgreSQL**（写进 `config.json` 的 `database` 或 `ARTEX_PG_DSN`）
- **工具链**：`nmap` / `ripgrep` / `curl` / `git` / `jq` / `python3` / `node 22` /
  `playwright + chromium` —— 官方镜像里预装了这些，agent 的工具调用依赖它们

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
- 汉化只改界面文案，**不改任何业务逻辑、API 契约与数据库结构** —— 与官方版数据
  完全兼容，可以随时来回切换。
