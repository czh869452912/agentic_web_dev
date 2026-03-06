# Docker 构建测试报告 v2

## 测试环境
- 主机：Windows 11 Pro + Docker Desktop (v25.0.3，daemon 未运行，执行静态分析)
- 分析时间：2026-03-06

---

## 一、目标可行性评估

**目标**: 单一端口 VSCode Web + Claude Code agentic 嵌入式开发

**结论: 架构方向完全可行，原始代码存在 6 个关键缺陷已修复**

---

## 二、原始问题清单

### P1 (严重) claude-web 容器无 agentic 能力 ✅ 已修复
`docker/Dockerfile.claude` 只是一个静态 HTML 信息页，说"请去终端运行 claude"。
整个 `claude-web` 服务毫无价值。

**修复**: 将 Claude Code CLI 直接安装进 code-server 容器，删除 claude-web 服务。
用户在 VS Code 集成终端里直接运行 `claude` 命令。

### P2 (严重) embedded-dev 与 code-server 完全隔离 ⚠️ 部分修复
code-server 容器没有 ARM GCC、OpenOCD 等工具，这些在 embedded-dev 容器里。
用户在 VS Code 终端里根本用不到这些工具。

**本次修复**: 在 Dockerfile.code-server 里加入了常用嵌入式工具（ARM GCC 13.2、
clang-tidy、cppcheck、OpenOCD 等），覆盖主要开发场景。

**未完全解决**: embedded-dev 容器的完整工具链（QEMU、Unity Test、Rust 嵌入式等）
仍然独立。可通过 `docker exec embedded-dev <cmd>` 访问，或后续添加 SSH 连接方案。

### P3 (严重) Gateway 健康检查端口错误 ✅ 已修复
```yaml
# 修复前（永远失败）
test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]

# 修复后
test: ["CMD-SHELL", "wget -q --no-check-certificate --spider https://localhost:8443/health || exit 1"]
```

### P4 (严重) manage.sh 构建 code-server 时 build context 错误 ✅ 已修复
```bash
# 修复前（context=docker/，找不到 configs/vsix/）
docker build -f Dockerfile.code-server -t code-server-custom:latest .

# 修复后（context=项目根目录）
docker build -f "$DOCKER_DIR/Dockerfile.code-server" -t code-server-custom:latest "$PROJECT_ROOT"
```

### P5 (中等) Nginx proxy_pass 变量无效 ✅ 已修复
```nginx
# 修复前（nginx 不允许在 proxy_pass 中直接用 $1 变量）
location ~ ^/proxy/(\d+)/(.*)$ {
    proxy_pass http://code_server:$1/$2;  # 500 错误

# 修复后：整个 location 已移除（code-server 自身处理端口转发）
```

### P6 (中等) Claude Code API 协议误标注 ✅ 已修复
`@anthropic-ai/claude-code` 使用 Anthropic 专有协议（`POST /v1/messages`），
不是 OpenAI 兼容格式（`POST /v1/chat/completions`）。

原始代码使用 `LLM_API_URL` + OpenAI 格式描述，实际上行不通。

**修复**: 环境变量改为 `ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL`（官方支持），
.env.example 明确说明三种使用方案（官方 API / 兼容 Anthropic 协议的内网代理 / 交互式登录）。

### P7 (中等) SSL 证书缺失导致冷启动失败 ✅ 已修复
`configs/ssl/` 不在 git 中，nginx 启动时立即报错。

**修复**: `start_services` 函数自动检查并调用 `gen_ssl`。

### P8 (轻微) docker-compose v1 命令 ✅ 已修复
```bash
# 修复前
docker-compose up -d  # Docker v25+ 可能不存在

# 修复后：自动检测
if docker compose version; then DOCKER_COMPOSE="docker compose"
elif command -v docker-compose; then DOCKER_COMPOSE="docker-compose"
```

### P9 (轻微) xmake 不在 Ubuntu 22.04 标准源 ⚠️ 未修复（Dockerfile.embedded）
需要添加 xmake 官方 PPA 或使用安装脚本，否则构建时会报 404。

### P10 (轻微) dot2tex 包不存在 ⚠️ 未修复（Dockerfile.embedded）
Ubuntu 22.04 标准源没有 `dot2tex`，构建会报错。

---

## 三、修复后的架构

```
用户浏览器
    ↓ HTTPS:8443
Nginx gateway（单一入口）
    ├── /          → code-server:8080（VSCode Web）
    │                  内置：Claude Code CLI + ARM GCC + clang + cppcheck 等
    │                  用户在 VS Code 终端运行：claude
    ├── /files/    → filebrowser:8080（文件管理）
    └── /health    → 200 OK（健康检查）

embedded-dev（后台运行，共享 /workspace）
    完整工具链：QEMU, Unity Test, Rust 嵌入式, probe-rs 等
    访问方式：docker exec embedded-dev <cmd>
```

---

## 四、使用流程（修复后）

```bash
# 1. 初始化
./scripts/manage.sh init

# 2. 配置 API（编辑 docker/.env）
cp docker/.env.example docker/.env
# 填入 ANTHROPIC_API_KEY 或 ANTHROPIC_BASE_URL

# 3. 构建镜像（需要网络访问 ARM 工具链和 npm）
./scripts/manage.sh build

# 4. 启动（自动生成 SSL 证书）
./scripts/manage.sh up

# 5. 访问
# https://localhost:8443  →  VS Code Web
# 在 VS Code 终端运行 claude 开始 agentic 开发
```

---

## 五、待完成（未来优化）

1. **Dockerfile.embedded 修复**: 移除 `xmake`（或改用安装脚本）和 `dot2tex`
2. **embedded-dev 集成**: 考虑在 code-server 中添加 Remote SSH 扩展连接 embedded-dev
3. **实际构建测试**: 需要在 Docker daemon 运行的 Linux 环境中验证镜像构建
4. **镜像体积优化**: code-server 镜像含 ARM 工具链后预计 5-8GB，可考虑按需拆分
