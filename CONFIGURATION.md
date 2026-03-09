# 配置指南

## 快速配置步骤

### 1. 初始化

```bash
./scripts/manage.sh init      # Linux/macOS
.\scripts\manage.ps1 init     # Windows
```

这会创建 `docker/.env` 文件。

### 2. 配置 API

编辑 `docker/.env`：

```bash
# ---- 服务访问 ----
GATEWAY_PORT=8443
CODE_SERVER_PASSWORD=YourSecurePassword
SUDO_PASSWORD=YourSudoPassword

# ---- Claude Code API ----
ANTHROPIC_API_KEY=
ANTHROPIC_BASE_URL=
```

### 3. 启动

```bash
./scripts/manage.sh up
# 会自动生成 SSL 证书（如果不存在）
```

---

## Claude Code API 配置详解

Claude Code CLI（`@anthropic-ai/claude-code`）使用 **Anthropic 专有协议**，核心端点为：

```
POST /v1/messages
```

这与 OpenAI 兼容格式（`POST /v1/chat/completions`）不同。

### 方案 A：Anthropic 官方 API（有公网访问）

```bash
ANTHROPIC_API_KEY=sk-ant-api03-...
ANTHROPIC_BASE_URL=          # 留空，使用默认 https://api.anthropic.com
```

### 方案 B：内网 Anthropic 格式代理

适用于将 Anthropic API 请求转发到内网大模型的场景（如通过 LiteLLM、one-api 等代理工具）：

```bash
ANTHROPIC_API_KEY=your-proxy-key
ANTHROPIC_BASE_URL=http://10.0.0.100:8000
```

**注意**：代理必须支持 Anthropic 消息格式，即实现 `POST /v1/messages` 接口。

代理工具推荐：
- [LiteLLM Proxy](https://docs.litellm.ai/docs/proxy/quick_start)（支持将 Anthropic 格式转发到任意模型）
- [one-api](https://github.com/songquanpeng/one-api)

### 方案 C：LiteLLM 统一网关（内网 OpenAI 兼容 API）

内网只有 OpenAI 兼容 API 时，通过内置 LiteLLM 进行协议转换。同时暴露 Anthropic 格式供 Claude Code 使用，OpenAI 格式供 Cline / Roo Code 使用，统一 API key 无需单独登录。

```bash
# 1. 创建 LiteLLM 配置
cp configs/litellm_config.yaml.example configs/litellm_config.yaml
# 编辑：替换 YOUR_INTERNAL_MODEL、INTERNAL_API_BASE、INTERNAL_API_KEY

# 2. docker/.env
ANTHROPIC_BASE_URL=http://llm-gateway:4000   # code-server 容器内直连（推荐）
ANTHROPIC_API_KEY=sk-devenv                  # 与 LITELLM_MASTER_KEY 相同
LITELLM_MASTER_KEY=sk-devenv
INTERNAL_API_BASE=http://10.0.0.100:8000
INTERNAL_API_KEY=your-internal-key

# 3. 启动
./scripts/manage.sh up --llm
```

Cline / Roo Code 插件配置（使用 nginx 代理外部访问）：
- Base URL：`https://<host>:8443/llm/v1`
- API Key：`sk-devenv`

### 方案 D：不预配置（交互式登录）

不填任何 API 配置，启动服务后在 VS Code 终端执行：

```bash
claude
```

按提示完成 Anthropic 账户登录（需要公网访问 claude.ai）。

---

## 配置生效方式

API 配置通过环境变量注入 code-server 容器，容器启动脚本 `/opt/entrypoint.sh` 自动将其写入 `/root/.claude/settings.json`（容器以 root 身份运行）。

查看当前配置：

```bash
# 在 VS Code 终端中
claude config get

# 或直接查看文件
cat /root/.claude/settings.json
```

修改配置后需重启服务：

```bash
./scripts/manage.sh down
./scripts/manage.sh up
```

---

## 常见场景

### 场景 1：LiteLLM 代理转发到 DeepSeek

```bash
# LiteLLM 配置（proxy_config.yaml）
model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: your-deepseek-key

# docker/.env
ANTHROPIC_API_KEY=any-string
ANTHROPIC_BASE_URL=http://10.0.0.50:4000
```

### 场景 2：Anthropic 官方 API（直连）

```bash
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxx
# ANTHROPIC_BASE_URL 留空
```

### 场景 3：内网无外网访问

必须有一个实现 Anthropic `/v1/messages` 协议的内网服务，或使用 LiteLLM 之类的转换层。

---

## 故障排除

### Claude Code 无法使用

1. **检查容器内环境变量**
   ```bash
   docker exec code-server bash -c "echo $ANTHROPIC_API_KEY && echo $ANTHROPIC_BASE_URL"
   ```

2. **检查配置文件**
   ```bash
   docker exec code-server cat /root/.claude/settings.json
   ```

3. **手动测试 API**（在容器终端）
   ```bash
   claude config get
   claude "hello"
   ```

### VS Code 无法访问

1. **检查 SSL 证书**
   ```bash
   ls configs/ssl/
   ```
   如果不存在：`./scripts/manage.sh ssl`

2. **检查 gateway 日志**
   ```bash
   docker logs dev-gateway
   ```

3. **检查 code-server 状态**
   ```bash
   docker logs code-server
   ```

---

## 安全注意事项

1. **不要提交 `.env` 文件**（已在 `.gitignore` 中）
2. **生产环境修改默认密码**：`CODE_SERVER_PASSWORD`
3. **IP 白名单**（可选）：在 `configs/nginx.conf` 的 server 块中添加
   ```nginx
   allow 10.0.0.0/8;
   deny all;
   ```
4. **HTTPS 证书**：自签名证书仅适合内网使用，生产环境建议替换为正式证书

---

## 参考

- [Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code)
- [Anthropic API 参考](https://docs.anthropic.com/en/api/messages)
- [LiteLLM Proxy 文档](https://docs.litellm.ai/docs/proxy/quick_start)
