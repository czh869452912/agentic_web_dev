# 配置指南

所有宿主机命令均在仓库根目录执行。首次启动见 [README](README.md)，证书操作见 [HTTPS 指南](docs/https.md)。

## 服务配置

运行 `./scripts/manage.sh init`（Windows：`.\scripts\manage.ps1 init`）生成 `docker/.env`，或复制 [配置模板](docker/.env.example)。

| 环境变量 | 用途 | 默认行为 |
| --- | --- | --- |
| `GATEWAY_PORT` | 宿主机 HTTPS 端口 | `8443` |
| `CODE_SERVER_PASSWORD` | IDE 及 forwarding 登录密码 | 未设置时回退为 `changeme`；部署前修改 |
| `SUDO_PASSWORD` | 传入 code-server 的 sudo 密码变量 | 未设置时回退为 `changeme` |
| `SERVER_DOMAIN` | Bash `up` 生成证书与显示地址时使用的服务器名称 | 可选；远程证书建议显式执行 `ssl <域名或IP>`，不配置 DNS 或 DSH forwarding |
| `CODE_SERVER_PROXY_DOMAIN` | code-server forwarding 主机模板 | `{{port}}.localhost:<GATEWAY_PORT>` |
| `INTERNAL_API_BASE` | LiteLLM 上游模型接口 | 启用 LiteLLM 时填写 |
| `INTERNAL_API_KEY` | LiteLLM 上游认证 | 启用 LiteLLM 时填写 |
| `LITELLM_MASTER_KEY` | LiteLLM 客户端认证 Key | 启用时设置自己的值 |

管理脚本支持 Compose 与 Docker-only 模式。Linux 使用 `--docker-only`，PowerShell 使用 `-DockerOnly`；两种模式的卷名称可能不同，已有部署应继续使用原模式，避免误接到新的空卷。

## DSH + Univer Office

### 本机启动

在 IDE 集成终端运行 `dsh-web` 并保持终端运行；Ctrl+C 停止。打开终端输出的完整登录链接，而不是仅复制域名。若先出现 code-server 登录页，使用同一 IDE 密码登录，再进入 DSH。

默认入口 `https://3080.localhost:8443/`。DSH 在 Settings → Models 中单独配置模型，工作目录选择 `/workspace`。Office 已安装在 DSH 的 web profile；截图和 PDF 等服务端渲染使用镜像内现代 Chromium。

### 远程访问

示例 `docker/.env`：

```dotenv
GATEWAY_PORT=8443
SERVER_DOMAIN=dev.example
CODE_SERVER_PROXY_DOMAIN={{port}}.dev.example:8443
```

让 `dev.example`（IDE）和 `3080.dev.example`（DSH）解析到同一服务器，并让 HTTPS 证书同时包含这两个名称。使用自签名方案时，配置 `.env` 后显式运行 `ssl dev.example`（见 [证书步骤](docs/https.md#生成自签名证书)），确保两端管理脚本都加入 IDE 名称。内网可用 DNS 或每台客户端的 hosts 文件，例如：

```text
192.168.1.100 dev.example 3080.dev.example
```

修改 `.env` 后重建 code-server 容器，修改证书或 Nginx 配置后重启网关。之后 `dsh-web` 自动输出 `https://3080.dev.example:8443/` 下的登录地址。模板中端口应为浏览器访问的 HTTPS 端口；使用 443 时允许省略 `:443`。

`SERVER_DOMAIN` 单独设置为 IP 不能代替 forwarding 域名。Nginx 统一转给 code-server，后者按子域名转发；不增加 DSH 专用 Nginx 规则，不发布内部 3080/9080。Office 不使用旧 `/dsh/` 或默认 `/proxy/3080/` 入口。

### 启动参数与兼容开关

以下设置在 **IDE 终端内**使用，不是自动从 `docker/.env` 传入的变量：

```bash
dsh-web                                      # 自动根据 forwarding 配置生成地址
dsh-web https://3080.dev.example:8443/         # 可选显式地址，必须匹配 forwarding 域名
DSH_BROWSER_COMPAT=0 dsh-web                   # 本次进程关闭兼容层并移除 Viewer 注入
```

也可设置 `DSH_PUBLIC_URL` 代替位置参数；显式位置参数优先。公开 URL 必须是匹配 forwarding 配置的 HTTPS 根地址，不接受子路径。恢复兼容层时停止 DSH 并正常运行 `dsh-web`。

兼容层在主页面和独立 Viewer 业务模块之前加载，优先补齐缺失 API；每次启动幂等处理当前插件入口，包括已有数据卷和插件升级后的入口。实际浏览器结果及限制见 [兼容性指南](docs/compatibility.md)，维护方法见 [兼容层说明](configs/browser-compat/README.md)。

## OpenCode

在 IDE 终端执行 `opencode`，通过其提供商配置连接模型。自建接口按 [OpenCode 提供商文档](https://opencode.ai/docs/providers/) 配置 Base URL、API Key 和模型 ID。OpenCode GUI 的安装策略见 [扩展说明](EXTENSIONS.md)。

## Kilo Code

打开 `kilocode.kilo-code` 扩展的 Providers 设置，配置提供商和模型；自建 Chat Completions 接口选择 OpenAI Compatible，填写 Base URL、API Key 和模型 ID。界面随上游版本变化，参考 [提供商说明](https://kilo.ai/docs/ai-providers/openai-compatible)。

容器内后端可连接内网模型地址或 `http://llm-gateway:4000/v1`。容器内的 `localhost` 指向容器自身，连接宿主机服务应使用容器可达的宿主机地址。模型及工具调用能力取决于所选提供商。

## 可选 LiteLLM 网关

```bash
cp configs/litellm_config.yaml.example configs/litellm_config.yaml
# 编辑 YOUR_INTERNAL_MODEL 为真实上游模型 ID
# 在 docker/.env 中配置 INTERNAL_API_BASE、INTERNAL_API_KEY、LITELLM_MASTER_KEY
./scripts/manage.sh up --llm
```

Windows 使用 `Copy-Item` 复制模板，运行 `.\scripts\manage.ps1 up -Llm`。

| 设置 | 值 |
| --- | --- |
| 容器内 Base URL | `http://llm-gateway:4000/v1` |
| 外部 HTTPS Base URL | `https://服务器域名:8443/llm/v1` |
| API Key | `.env` 中的 `LITELLM_MASTER_KEY` |
| 客户端模型 ID | `configs/litellm_config.yaml` 中的 `model_name` |

各工具分别保存模型配置。管理脚本不注入智能体专用 API 配置，也没有旧的 `test-api`、`update-config` 命令。

## 数据持久化

| 挂载 | 容器路径 | 内容 |
| --- | --- | --- |
| 宿主机 `workspace/` | code-server `/workspace`、File Browser `/srv` | 项目与办公文件 |
| `dsh-data` 卷 | `/var/lib/dsh` | DSH 配置、会话和插件 |
| `code-extensions` 卷 | `/home/coder/.local/share/code-server/extensions` | 已安装扩展 |
| `code-config` 卷 | `/home/coder/.config/code-server` | code-server 此目录内的配置 |
| `filebrowser-db` 卷 | `/database` | File Browser 数据库 |
| `litellm-cache` 卷（Compose 可选服务） | `/app/.cache` | LiteLLM 缓存 |

Compose 通常给卷名加项目名前缀；Docker-only 使用脚本中的固定名称。备份时以 `docker inspect code-server` 显示的实际挂载为准。

当前 code-server 启动参数将用户数据目录设为 `/home/coder/.local/share/code-server`，其中仅 `extensions` 子目录挂卷；`User` 等其他运行时用户数据不在现有 named volume 覆盖范围。重建前应另行备份所需 IDE/扩展设置，以及各 CLI 实际使用的配置目录，不能把 `code-config` 卷理解为所有智能体设置的完整备份。卸载退役扩展的逻辑本身不删除历史设置。

## 更新已有部署

### 镜像与容器

先备份需要保留的数据、停止正在运行的 DSH，再在宿主机执行：

```bash
./scripts/manage.sh build
./scripts/manage.sh up
docker restart dev-gateway
```

Windows 使用 `.\scripts\manage.ps1 build`、`up`，随后同样执行 `docker restart dev-gateway`。原先使用 Docker-only 的部署继续加对应模式参数；原先启用 LiteLLM 的部署保留 `--llm` / `-Llm`。

`up` 会按镜像和服务配置创建或更新容器；`restart` 只重启现有容器，不替换镜像。重启网关用于加载新 Nginx 配置并刷新上游解析。首次迁移到 forwarding 时还需更新证书中的 DSH 域名，操作见 [HTTPS 指南](docs/https.md)。不要通过删除数据卷完成升级。

DSH、Office、pnpm 的构建参数 `DSH_VERSION`、`DSH_UNIVER_OFFICE_VERSION`、`DSH_PNPM_VERSION` 默认均为 `latest`。普通 `build` 会使用 Docker 缓存；要重新获取最新上游，直接执行：

```bash
docker build --pull --no-cache -f docker/Dockerfile.code-server -t code-server-custom:latest .
```

随后运行 `up` 更新容器。版本和镜像 ID 的已验证快照见 [兼容性指南](docs/compatibility.md#构建结果)。

### 已有插件与扩展卷

新建 `dsh-data` 卷会从镜像填充；已有卷保留原插件版本。升级 Office 时先停止 DSH，在 IDE 终端执行：

```bash
dsh plugin --profile web add dsh-univer-office@latest
dsh-web
```

这一步需要联网；日常启动不重新安装插件。全局 DSH CLI 随容器镜像更新。

扩展 seed 启动时以不覆盖已有文件的方式合并到扩展卷，不代表所有扩展已切换到 seed 最新版本。核对当前实际扩展可运行：

```bash
docker exec code-server code-server --extensions-dir /home/coder/.local/share/code-server/extensions --list-extensions --show-versions
```

镜像不再安装 Claude Code CLI/扩展、Cline 和 Roo Code；启动时通过扩展管理器卸载旧卷中的三个退役扩展。旧专用配置卷不再挂载，不自动删除。

## 故障排除

| 现象 | 检查 |
| --- | --- |
| 扩展页空白、Service Worker 失败 | 证书 SAN 与访问域名一致，客户端已信任；见 [HTTPS 指南](docs/https.md) |
| DSH 无法连接 | `dsh-web` 仍在运行，域名解析、端口、forwarding 模板一致 |
| Office 资源 404 或跳回 IDE | 使用 forwarding 子域名根地址，不使用 `/dsh/`、`/proxy/3080/` |
| 修改 `.env` 后地址没变 | 更新容器；仅 `docker restart` 不会加载新的容器环境变量 |
| 重建后 Office 版本未变 | 检查已有 `dsh-data` 卷中的插件版本，按上文显式升级 |
| Kilo 构建安装失败 | 检查 Open VSX 网络及内置 Code 版本要求；Kilo 是必装扩展 |
| 模型连接失败 | 检查该工具的 URL、Key、模型 ID 以及容器到模型服务的连通性 |

日志：`docker logs code-server`、`docker logs dev-gateway`。DSH 前台日志含进程登录令牌，分享前应脱敏。
