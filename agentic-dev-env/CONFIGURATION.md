# Agentic 开发环境 - 配置指南

## 快速配置步骤

### 1. 初始化配置

```bash
./scripts/manage.sh init
```

这会创建 `docker/.env` 文件。

### 2. 配置内网 LLM API

编辑 `docker/.env`：

```bash
# ========================================
# 必填项
# ========================================

# 内网 OpenAI 兼容 API 端点
# 示例：
#   - http://10.0.0.100:8000/v1
#   - https://llm-api.company.com/v1
#   - http://gpu-server.internal:8080/v1
LLM_API_URL=http://your-llm-server:8000/v1

# API 密钥（如果内网 API 需要认证）
LLM_API_KEY=your-api-key-here

# 模型名称（根据内网 API 支持的模型填写）
# 常见选项：gpt-4, gpt-4-turbo, gpt-3.5-turbo, qwen-max, deepseek-chat
LLM_MODEL=gpt-4

# ========================================
# 可选项
# ========================================

# 内网 API 服务器 IP（用于 hosts 解析，如果域名解析有问题）
# LLM_HOST_IP=10.0.0.100

# Code Server 访问密码
CODE_SERVER_PASSWORD=changeme

# 网关端口（默认 8443）
GATEWAY_PORT=8443
```

### 3. 测试连接

```bash
./scripts/manage.sh test-api
```

### 4. 启动服务

```bash
./scripts/manage.sh up
```

---

## API 格式要求

### 支持的端点

你的内网 API 需要支持以下 OpenAI 兼容端点：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v1/models` | GET | 列出可用模型 |
| `/v1/chat/completions` | POST | 聊天完成 |
| `/v1/completions` | POST | 文本完成（可选） |

### 认证方式

支持以下认证方式：

1. **Bearer Token**（推荐）
   ```
   Authorization: Bearer your-api-key
   ```

2. **无认证**（内网互信环境）
   留空 `LLM_API_KEY` 即可

---

## 常见配置场景

### 场景 1：内网 vLLM 部署

```bash
LLM_API_URL=http://10.0.0.50:8000/v1
LLM_API_KEY=sk-internal-key
LLM_MODEL=deepseek-coder-33b
```

### 场景 2：公司统一 LLM 网关

```bash
LLM_API_URL=https://llm-gateway.company.com/api/v1
LLM_API_KEY=company-api-key
LLM_MODEL=gpt-4
```

### 场景 3：本地 Ollama（开发测试）

```bash
LLM_API_URL=http://host.docker.internal:11434/v1
LLM_API_KEY=
LLM_MODEL=llama2:13b
```

---

## 故障排除

### API 连接失败

1. **检查网络连通性**
   ```bash
   # 从宿主机测试
   curl $LLM_API_URL/models
   
   # 从容器测试
   docker exec claude-web curl $LLM_API_URL/models
   ```

2. **检查 API 格式**
   ```bash
   curl -X POST $LLM_API_URL/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $LLM_API_KEY" \
     -d '{"model":"gpt-4","messages":[{"role":"user","content":"test"}]}'
   ```

3. **查看容器日志**
   ```bash
   docker logs claude-web
   ```

### Claude Code 无法使用

1. **检查配置是否正确注入**
   ```bash
   docker exec claude-web cat /root/.claude/settings.json
   ```

2. **更新配置（不重启）**
   ```bash
   ./scripts/manage.sh update-config
   ```

3. **手动配置**
   ```bash
   docker exec -it claude-web bash
   claude config set apiUrl http://your-api/v1
   claude config set apiKey your-key
   claude config set model gpt-4
   ```

---

## 安全注意事项

1. **不要在版本控制中提交 `.env` 文件**
   ```bash
   # 确保 .gitignore 包含
echo "docker/.env" >> .gitignore
   ```

2. **使用只读 API Key**（如果内网 API 支持权限控制）

3. **限制服务访问范围**
   - 在 nginx.conf 中添加 IP 白名单
   - 使用防火墙限制 8443 端口访问

---

## 高级配置

### 自定义 API Header

如果需要自定义请求头，编辑容器内的配置：

```bash
docker exec claude-web cat > /root/.claude/settings.json << 'EOF'
{
  "apiUrl": "http://your-api/v1",
  "apiKey": "your-key",
  "model": "gpt-4",
  "customHeaders": {
    "X-Custom-Header": "value"
  }
}
EOF
```

### 多模型配置

Claude Code 支持在运行时切换模型：

```bash
claude config set model gpt-4-turbo
# 或
claude --model deepseek-coder ./file.c
```

---

## 参考

- [OpenAI API 文档](https://platform.openai.com/docs/api-reference)
- [Claude Code 文档](https://docs.anthropic.com/claude-code)
- [vLLM 部署指南](https://docs.vllm.ai/)
