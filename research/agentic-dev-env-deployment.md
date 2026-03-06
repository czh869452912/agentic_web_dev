# 内网 Agentic 云开发环境部署方案

## 需求概述
- **Code Server**: Web 版 VS Code
- **Claude Code**: AI 编程助手（含 VS Code 插件）
- **C 语言嵌入式开发环境**: ARM 交叉编译工具链
- **私有化大模型**: 内网部署的 LLM
- **严格限制**: 所有流量必须通过单一端口
- **离线环境**: Docker 镜像导入后无法联网

---

## 核心架构挑战

### 1. 单端口多服务路由

内网的严格端口控制策略要求所有服务共享一个对外端口。解决方案是使用 **Subpath-based Reverse Proxy**（基于子路径的反向代理）。

```
用户请求 → 唯一端口(如 8443) → Nginx/Traefik → 服务分发

https://dev-server:8443/           → Code Server (VS Code Web)
https://dev-server:8443/claude/    → Claude Code Web Interface  
https://dev-server:8443/api/llm/   → 私有化 LLM API
https://dev-server:8443/proxy/8080 → 其他开发服务端口代理
```

### 2. 服务组件映射

| 路径 | 服务 | 内部端口 | 说明 |
|------|------|----------|------|
| `/` | Code Server | 8080 | 主 IDE 界面 |
| `/claude/` | Claude Code | 3000 | AI 助手 Web UI |
| `/api/llm/` | LLM API Proxy | 11434 | Ollama/vLLM 接口 |
| `/proxy/<port>/` | Dynamic Proxy | - | Code Server 内置端口代理 |

---

## 方案一: Nginx + Subpath 路由 (推荐)

### 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker 容器                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Nginx Reverse Proxy (Port 8443)              │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │   │
│  │  │  Code Server│  │Claude Code  │  │  LLM API (Ollama)│   │   │
│  │  │   :8080     │  │   :3000     │  │     :11434      │   │   │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘   │   │
│  │         │                │                   │            │   │
│  │         └────────────────┴───────────────────┘            │   │
│  │                          │                                │   │
│  │                    location / {...}                       │   │
│  │                    location /claude/ {...}                │   │
│  │                    location /api/llm/ {...}               │   │
│  └──────────────────────────┬────────────────────────────────┘   │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                         单一端口 8443
```

### Docker Compose 配置

```yaml
version: '3.8'

services:
  # 主入口：Nginx 反向代理
  gateway:
    image: nginx:alpine
    container_name: dev-gateway
    ports:
      - "8443:8443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro  # 内网自签名证书
    depends_on:
      - code-server
      - claude-web
      - ollama
    networks:
      - devnet

  # Code Server (VS Code Web)
  code-server:
    image: codercom/code-server:latest
    container_name: code-server
    environment:
      - PASSWORD=${CODE_PASSWORD}
      - SUDO_PASSWORD=${SUDO_PASSWORD}
    volumes:
      - ./workspace:/home/coder/workspace
      - ./extensions:/home/coder/.local/share/code-server/extensions
      - ./config:/home/coder/.config
    # 不暴露端口，只通过 Nginx 访问
    networks:
      - devnet
    command: --bind-addr 0.0.0.0:8080 --disable-telemetry --disable-update-check

  # Claude Code Web 界面
  claude-web:
    image: node:20-slim
    container_name: claude-web
    environment:
      - OLLAMA_HOST=http://ollama:11434
      - CLAUDE_CODE_API_URL=http://ollama:11434/v1
    volumes:
      - ./workspace:/workspace
      - ./claude-config:/root/.claude
    working_dir: /app
    # Claude Code CLI 或 Web UI
    command: >
      sh -c "npm install -g @anthropic-ai/claude-code && 
             claude-code --web --port 3000 --host 0.0.0.0"
    networks:
      - devnet

  # 私有化大模型 (Ollama)
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ./ollama-models:/root/.ollama
    # 预加载的模型需要在镜像构建时或导入前准备好
    networks:
      - devnet
    # GPU 支持（如果内网机器有 GPU）
    # runtime: nvidia
    # environment:
    #   - NVIDIA_VISIBLE_DEVICES=all

  # C 嵌入式开发环境
  embedded-dev:
    image: embedded-dev-env:latest  # 自定义镜像，见下文
    container_name: embedded-dev
    volumes:
      - ./workspace:/workspace
      - ./toolchains:/opt/toolchains
    working_dir: /workspace
    # 作为辅助容器，不直接对外暴露
    networks:
      - devnet
    # 预装工具链：ARM GCC, OpenOCD, QEMU, GDB

networks:
  devnet:
    internal: true  # 仅内部通信
```

### Nginx 配置 (nginx.conf)

```nginx
# 注意：这是关键配置，处理 WebSocket 和 subpath 路由

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 关键：大文件上传支持（VS Code 可能上传大文件）
    client_max_body_size 100M;
    
    # WebSocket 超时设置
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;

    # 上游服务定义
    upstream code_server {
        server code-server:8080;
    }

    upstream claude_web {
        server claude-web:3000;
    }

    upstream ollama_api {
        server ollama:11434;
    }

    server {
        listen 8443 ssl http2;
        server_name _;  # 接受任意 Host

        # 内网自签名证书
        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;

        # ========== Code Server (主 IDE) ==========
        location / {
            proxy_pass http://code_server/;
            proxy_http_version 1.1;
            
            # WebSocket 支持（VS Code 需要）
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # 禁用缓存
            proxy_cache_bypass $http_upgrade;
        }

        # ========== Claude Code Web ==========
        location /claude/ {
            proxy_pass http://claude_web/;
            proxy_http_version 1.1;
            
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Prefix /claude;
            
            # 重写 Location header（处理重定向）
            proxy_redirect / /claude/;
        }

        # ========== LLM API (Ollama) ==========
        location /api/llm/ {
            # 去掉 /api/llm 前缀再转发
            rewrite ^/api/llm/(.*) /$1 break;
            
            proxy_pass http://ollama_api/;
            proxy_http_version 1.1;
            
            # Ollama 流式响应需要
            proxy_buffering off;
            proxy_cache off;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            # CORS 头（如果前端需要）
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
        }

        # 健康检查
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

---

## 方案二: Traefik + PathPrefix (更现代的方案)

如果团队熟悉 Traefik，这是更"云原生"的选择：

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    command:
      - "--api.insecure=true"  # 仅内网使用
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.websecure.address=:8443"
      - "--serversTransport.insecureSkipVerify=true"
    ports:
      - "8443:8443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - devnet

  code-server:
    image: codercom/code-server:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.codeserver.rule=PathPrefix(`/`)"
      - "traefik.http.routers.codeserver.entrypoints=websecure"
      - "traefik.http.services.codeserver.loadbalancer.server.port=8080"
      # WebSocket 支持
      - "traefik.http.routers.codeserver.middlewares=codeserver-stripprefix"
    networks:
      - devnet

  # 其他服务类似配置...

networks:
  devnet:
```

---

## 关键组件详解

### 1. Code Server 配置

Code Server 原生支持通过 subpath 运行，但需要设置：

```bash
# 启动参数
--proxy-domain dev-server.company.local
# 或通过环境变量
export VSCODE_PROXY_URI="https://dev-server:8443/proxy/{{port}}"
```

### 2. Claude Code 私有化部署

Claude Code 本身是一个 Node.js CLI 工具，**可以通过配置连接到自托管模型**：

```bash
# 配置 Claude Code 使用本地 Ollama
claude config set apiUrl http://ollama:11434/v1
claude config set model qwen2.5-coder:32b  # 或其他内网模型
```

**注意**: Claude Code 需要支持 **Tool Calling** 的模型才能正常使用文件编辑等功能。推荐模型：
- `qwen2.5-coder:32b` (通义千问，支持工具调用)
- `deepseek-coder-v2` (DeepSeek)
- 通过 Ollama 运行的 GPT-OSS-20B-claude-code 微调版本

### 3. VS Code Claude 插件离线安装

VS Code 插件可以通过 `.vsix` 文件离线安装：

1. 在外网下载插件：
   ```bash
   # 使用 vsce 或直接从 OpenVSX 下载
   wget https://open-vsx.org/api/anthropic/claude-code-extension/version/file/anthropic.claude-code-extension-version.vsix
   ```

2. 内网安装：
   - 打开 Code Server
   - Extensions → Install from VSIX

### 4. C 嵌入式开发环境镜像

```dockerfile
# Dockerfile.embedded
FROM ubuntu:22.04

# 基础工具
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    gdb \
    gdb-multiarch \
    qemu-user-static \
    qemu-system-arm \
    openocd \
    stlink-tools \
    libusb-1.0-0-dev \
    minicom \
    && rm -rf /var/lib/apt/lists/*

# ARM GCC Toolchain (预下载并 COPY 进去)
COPY toolchains/gcc-arm-none-eabi-13.2.rel1-x86_64-arm-none-eabi.tar.xz /tmp/
RUN tar -xf /tmp/gcc-arm-none-eabi-*.tar.xz -C /opt/ && \
    rm /tmp/gcc-arm-none-eabi-*.tar.xz

ENV PATH="/opt/gcc-arm-none-eabi-13.2.Rel1/bin:${PATH}"

# 常用嵌入式库 (预下载)
COPY libs/STM32CubeF4 /opt/STM32CubeF4
COPY libs/cmsis /opt/cmsis

# OpenOCD 配置
COPY openocd-configs /usr/share/openocd/scripts/board

WORKDIR /workspace
```

---

## 离线部署流程

由于内网无法联网，需要在外网环境准备好所有镜像：

```bash
# ========== 外网机器准备 ==========

# 1. 创建专用网络
docker network create devnet

# 2. 拉取基础镜像
docker pull codercom/code-server:latest
docker pull ollama/ollama:latest
docker pull nginx:alpine

# 3. 构建自定义镜像
docker build -t embedded-dev-env:latest -f Dockerfile.embedded .

# 4. 准备 Ollama 模型（在外网下载）
docker run -d -v ollama-models:/root/.ollama ollama/ollama
# 拉取需要的模型
docker exec <container> ollama pull qwen2.5-coder:32b
docker exec <container> ollama pull deepseek-coder-v2:16b

# 5. 保存镜像
docker save codercom/code-server:latest > images/code-server.tar
docker save ollama/ollama:latest > images/ollama.tar
docker save nginx:alpine > images/nginx.tar
docker save embedded-dev-env:latest > images/embedded-dev.tar

# 6. 保存模型数据
tar czvf ollama-models.tar.gz /var/lib/docker/volumes/ollama-models/_data

# 7. 打包所有文件
# - docker-compose.yml
# - nginx.conf
# - images/*.tar
# - ollama-models.tar.gz
# - 证书文件
# - VS Code 插件 .vsix 文件

# ========== 内网部署 ==========

# 1. 加载镜像
docker load < images/code-server.tar
docker load < images/ollama.tar
docker load < images/nginx.tar
docker load < images/embedded-dev.tar

# 2. 恢复模型数据
tar xzvf ollama-models.tar.gz -C /opt/ollama-models/

# 3. 启动服务
docker-compose up -d
```

---

## 模型选择建议

由于完全离线，需要提前下载模型。推荐方案：

| 用途 | 模型 | 大小 | 量化 |
|------|------|------|------|
| 代码补全 | Qwen2.5-Coder-14B | ~9GB | Q4_K_M |
| 复杂任务 | Qwen2.5-Coder-32B | ~20GB | Q4_K_M |
| 轻量级 | DeepSeek-Coder-V2-Lite | ~3GB | Q4_K_M |

**关键**: 模型必须支持 **Function Calling / Tool Use**，否则 Claude Code 无法正常编辑文件。

---

## 备选方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| **Nginx Subpath** | 简单稳定，文档丰富 | 配置较繁琐 |
| **Traefik** | 自动服务发现，现代化 | 学习曲线陡峭 |
| **Code Server 内置代理** | 无需额外组件 | 功能有限 |
| **SSH 隧道** | 极简 | 需要多个隧道 |

---

## 风险与注意事项

1. **WebSocket 支持**: VS Code 重度依赖 WebSocket，Nginx 配置必须正确处理 Upgrade 头

2. **路径重写**: Subpath 部署最大的坑是前端资源路径问题，可能需要 `proxy_redirect` 调整

3. **模型能力**: 不是所有本地模型都支持工具调用，必须验证 Claude Code 的兼容性

4. **存储**: Ollama 模型体积大（10-30GB），确保内网存储充足

5. **GPU**: 如果没有 GPU，大模型推理会很慢，可考虑 CPU 优化的量化版本

---

## 推荐的 POC 步骤

1. **Phase 1**: 先部署 Nginx + Code Server，验证单端口访问
2. **Phase 2**: 接入 Ollama + 小模型，验证 API 代理
3. **Phase 3**: 配置 Claude Code 连接本地模型
4. **Phase 4**: 添加嵌入式开发工具链
5. **Phase 5**: 完整离线打包测试

---

*调研完成时间: 2026-03-05*
*参考: Claude Code 官方文档、Code Server 文档、Ollama 部署指南、Traefik 官方文档*
