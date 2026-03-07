#!/bin/bash
# ============================================================
# 内网 Agentic 开发环境 - 管理脚本
# 支持内网 OpenAI 兼容 API 配置
# ============================================================

set -e

# 颜色输出 - 使用 printf 兼容格式
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[0;34m'
NC='\e[0m'

# 颜色输出函数（类似 PowerShell 的 Write-Info/OK/Warn/Fail）
print_info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
print_ok()    { printf "${GREEN}[ OK ]${NC}  %s\n" "$1"; }
print_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
print_fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

# 项目目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"
CONFIGS_DIR="$PROJECT_ROOT/configs"

# 默认环境变量
ENV_FILE="$DOCKER_DIR/.env"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}  Agentic 开发环境管理脚本${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

usage() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  init              初始化环境（创建 .env 文件）"
    echo "  config            配置内网 LLM API"
    echo "  test-api          测试 LLM API 连接"
    echo "  build             构建所有 Docker 镜像"
    echo "  pull              拉取基础镜像"
    echo "  save              保存镜像到 images/ 目录"
    echo "  load              从 images/ 目录加载镜像"
    echo "  up                启动服务"
    echo "  down              停止服务"
    echo "  status            查看服务状态"
    echo "  logs              查看日志"
    echo "  shell <svc>      进入指定服务的 shell"
    echo "  ssl               生成自签名 SSL 证书"
    echo "  clean             清理构建缓存"
    echo "  update-config     更新 API 配置（不重启服务）"
    echo ""
    exit 0
}

check_deps() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 未找到 docker，请先安装 Docker${NC}"
        exit 1
    fi
    # 支持 docker compose (v2) 和 docker-compose (v1)
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        echo -e "${RED}错误: 未找到 docker compose 或 docker-compose${NC}"
        exit 1
    fi
}

init_dirs() {
    mkdir -p "$PROJECT_ROOT/images"
    mkdir -p "$PROJECT_ROOT/models"
    mkdir -p "$PROJECT_ROOT/logs/nginx"
    mkdir -p "$PROJECT_ROOT/workspace"
    mkdir -p "$PROJECT_ROOT/.secrets"
    mkdir -p "$CONFIGS_DIR/ssl"
}

# 初始化环境配置
init_config() {
    echo -e "${YELLOW}初始化环境配置...${NC}"
    
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}配置文件已存在: $ENV_FILE${NC}"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}保留现有配置${NC}"
            return
        fi
    fi
    
    cat > "$ENV_FILE" << EOF
# ========================================
# 基础服务配置
# ========================================
GATEWAY_PORT=8443
CODE_SERVER_PASSWORD=changeme
SUDO_PASSWORD=changeme

# ========================================
# 内网大模型 API 配置（必填）
# ========================================
# OpenAI 兼容的 API 端点，例如：
# - http://10.0.0.100:8000/v1
# - https://llm.company.com/api/v1
LLM_API_URL=

# API 密钥（如果需要）
LLM_API_KEY=

# 模型名称
LLM_MODEL=gpt-4

# 内网 API 服务器 IP（用于 hosts 解析）
# LLM_HOST_IP=10.0.0.100

# ========================================
# Claude Code 配置
# ========================================
CLAUDE_CODE_MODEL=gpt-4
EOF
    
    echo -e "${GREEN}✓ 配置文件已创建: $ENV_FILE${NC}"
    echo -e "${YELLOW}请编辑该文件配置您的内网 LLM API${NC}"
}

# 交互式配置 LLM API
config_api() {
    echo -e "${BLUE}配置内网 LLM API${NC}"
    echo ""
    
    # 读取现有配置
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
    
    echo -e "${YELLOW}请输入内网 LLM API 配置:${NC}"
    echo ""
    
    read -p "API URL [${LLM_API_URL:-http://localhost:8000/v1}]: " api_url
    api_url=${api_url:-${LLM_API_URL:-http://localhost:8000/v1}}
    
    read -p "API Key [${LLM_API_KEY:-}]: " api_key
    api_key=${api_key:-${LLM_API_KEY:-}}
    
    read -p "Model [${LLM_MODEL:-gpt-4}]: " model
    model=${model:-${LLM_MODEL:-gpt-4}}
    
    read -p "API 服务器 IP (可选，用于 hosts 解析): " api_ip
    
    # 更新配置文件
    cat > "$ENV_FILE" << EOF
# ========================================
# 基础服务配置
# ========================================
GATEWAY_PORT=${GATEWAY_PORT:-8443}
CODE_SERVER_PASSWORD=${CODE_SERVER_PASSWORD:-changeme}
SUDO_PASSWORD=${SUDO_PASSWORD:-changeme}

# ========================================
# 内网大模型 API 配置
# ========================================
LLM_API_URL=$api_url
LLM_API_KEY=$api_key
LLM_MODEL=$model
EOF
    
    if [ -n "$api_ip" ]; then
        echo "LLM_HOST_IP=$api_ip" >> "$ENV_FILE"
    fi
    
    echo "" >> "$ENV_FILE"
    echo "# ========================================" >> "$ENV_FILE"
    echo "# Claude Code 配置" >> "$ENV_FILE"
    echo "# ========================================" >> "$ENV_FILE"
    echo "CLAUDE_CODE_MODEL=$model" >> "$ENV_FILE"
    
    echo ""
    echo -e "${GREEN}✓ 配置已保存${NC}"
    echo ""
    echo -e "${BLUE}配置内容:${NC}"
    grep -E "^(LLM|CODE)" "$ENV_FILE" | grep -v PASSWORD || true
}

# 测试 API 连接
test_api() {
    echo -e "${YELLOW}测试 LLM API 连接...${NC}"
    
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}错误: 配置文件不存在，请先运行 init${NC}"
        exit 1
    fi
    
    source "$ENV_FILE"
    
    if [ -z "$LLM_API_URL" ]; then
        echo -e "${RED}错误: LLM_API_URL 未配置${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}API URL: $LLM_API_URL${NC}"
    echo -e "${BLUE}Model: $LLM_MODEL${NC}"
    echo ""
    
    # 测试连接
    echo -e "${YELLOW}测试 API 连通性...${NC}"
    
    # 尝试获取模型列表（OpenAI 兼容 API）
    if curl -s --connect-timeout 10 "$LLM_API_URL/models" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API 连接成功${NC}"
    else
        echo -e "${RED}✗ API 连接失败${NC}"
        echo ""
        echo -e "${YELLOW}可能的原因:${NC}"
        echo "  1. API URL 配置错误"
        echo "  2. 网络不可达（检查防火墙/VPN）"
        echo "  3. API 服务未启动"
        echo ""
        return 1
    fi
    
    # 测试认证（如果配置了 API Key）
    if [ -n "$LLM_API_KEY" ]; then
        echo -e "${YELLOW}测试 API 认证...${NC}"
        
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $LLM_API_KEY" \
            "$LLM_API_URL/models" 2>/dev/null || echo "000")
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✓ API 认证成功${NC}"
        elif [ "$http_code" = "401" ]; then
            echo -e "${RED}✗ API Key 认证失败${NC}"
        else
            echo -e "${YELLOW}? API 返回状态码: $http_code${NC}"
        fi
    fi
    
    # 测试简单生成
    echo ""
    echo -e "${YELLOW}测试模型生成...${NC}"
    
    response=$(curl -s -X POST "$LLM_API_URL/chat/completions" \
        -H "Content-Type: application/json" \
        ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} \
        -d "{
            \"model\": \"$LLM_MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Say 'API test successful'\"}],
            \"max_tokens\": 20
        }" 2>/dev/null || echo "")
    
    if [ -n "$response" ] && echo "$response" | grep -q "content"; then
        echo -e "${GREEN}✓ 模型生成测试成功${NC}"
        echo ""
        echo -e "${BLUE}响应预览:${NC}"
        echo "$response" | head -c 200
        echo "..."
    else
        echo -e "${RED}✗ 模型生成测试失败${NC}"
        echo "响应: $response"
    fi
}

# 更新配置（不重启服务）
update_config() {
    echo -e "${YELLOW}更新 Claude Code 配置...${NC}"
    
    source "$ENV_FILE"
    
    # 更新 claude-web 容器配置
    docker exec claude-web sh -c "
        cat > /root/.claude/settings.json << CONFIG
{
  \"apiUrl\": \"$LLM_API_URL\",
  \"apiKey\": \"$LLM_API_KEY\",
  \"model\": \"$LLM_MODEL\",
  \"maxTokens\": 4096,
  \"temperature\": 0.7,
  \"timeout\": 120
}
CONFIG
    "
    
    echo -e "${GREEN}✓ 配置已更新（无需重启服务）${NC}"
}

gen_ssl() {
    echo -e "${YELLOW}[1/1] 生成自签名 SSL 证书...${NC}"
    
    SSL_DIR="$CONFIGS_DIR/ssl"
    mkdir -p "$SSL_DIR"
    
    openssl genrsa -out "$SSL_DIR/server.key" 2048 2>/dev/null
    openssl req -new \
        -key "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.csr" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=DevOps/OU=Development/CN=dev-server.local" 2>/dev/null
    openssl x509 -req \
        -days 365 \
        -in "$SSL_DIR/server.csr" \
        -signkey "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.crt" 2>/dev/null
    rm "$SSL_DIR/server.csr"
    
    echo -e "${GREEN}✓ SSL 证书已生成: $SSL_DIR/${NC}"
}

pull_images() {
    echo -e "${YELLOW}拉取基础镜像...${NC}"
    
    docker pull nginx:alpine
    docker pull codercom/code-server:4.21.0
    docker pull filebrowser/filebrowser:v2.27.0
    docker pull node:20-slim
    docker pull ubuntu:22.04
    
    echo -e "${GREEN}✓ 基础镜像拉取完成${NC}"
}

build_images() {
    echo -e "${YELLOW}构建自定义镜像...${NC}"

    # code-server context 必须是上级目录（包含 configs/）
    echo -e "${BLUE}[1/2] 构建 Code Server + Claude Code（一体镜像）...${NC}"
    docker build \
        -f "$DOCKER_DIR/Dockerfile.code-server" \
        -t code-server-custom:latest \
        "$PROJECT_ROOT"

    echo -e "${BLUE}[2/2] 构建嵌入式开发环境（完整工具链）...${NC}"
    docker build \
        -f "$DOCKER_DIR/Dockerfile.embedded" \
        -t embedded-dev-env:latest \
        "$PROJECT_ROOT"

    echo -e "${GREEN}✓ 所有镜像构建完成${NC}"
}

save_images() {
    echo -e "${YELLOW}保存镜像...${NC}"
    
    mkdir -p "$PROJECT_ROOT/images"
    cd "$PROJECT_ROOT/images"
    
    declare -a images=(
        "nginx:alpine"
        "codercom/code-server:4.21.0"
        "filebrowser/filebrowser:v2.27.0"
        "node:20-slim"
        "ubuntu:22.04"
        "code-server-custom:latest"
        "claude-web:latest"
        "embedded-dev-env:latest"
    )
    
    for img in "${images[@]}"; do
        filename=$(echo "$img" | tr '/:' '_').tar
        echo -e "  保存 $img → $filename"
        docker save "$img" > "$filename"
    done
    
    echo -e "${GREEN}✓ 镜像已保存${NC}"
}

load_images() {
    echo -e "${YELLOW}加载镜像...${NC}"
    
    if [ ! -d "$PROJECT_ROOT/images" ]; then
        echo -e "${RED}错误: 镜像目录不存在${NC}"
        exit 1
    fi
    
    cd "$PROJECT_ROOT/images"
    for tarfile in *.tar; do
        if [ -f "$tarfile" ]; then
            echo -e "  加载 $tarfile"
            docker load < "$tarfile"
        fi
    done
    
    echo -e "${GREEN}✓ 镜像已加载${NC}"
}

start_services() {
    echo -e "${YELLOW}启动服务...${NC}"

    cd "$DOCKER_DIR"

    if [ ! -f .env ]; then
        echo -e "${RED}错误: .env 文件不存在${NC}"
        echo -e "${YELLOW}请运行: $0 init${NC}"
        exit 1
    fi

    # 自动生成 SSL 证书（如果不存在）
    if [ ! -f "$CONFIGS_DIR/ssl/server.crt" ]; then
        echo -e "${YELLOW}SSL 证书不存在，自动生成...${NC}"
        gen_ssl
    fi

    # 检查 API 配置
    source .env
    if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$ANTHROPIC_BASE_URL" ]; then
        echo -e "${YELLOW}警告: ANTHROPIC_API_KEY 和 ANTHROPIC_BASE_URL 均未配置${NC}"
        echo -e "${YELLOW}Claude Code 启动后需要手动运行 'claude' 完成登录${NC}"
    fi

    mkdir -p "$PROJECT_ROOT/logs/nginx"

    $DOCKER_COMPOSE up -d
    
    echo ""
    echo -e "${GREEN}✓ 服务已启动${NC}"
    echo ""
    echo -e "访问地址:"
    echo -e "  ${BLUE}https://localhost:${GATEWAY_PORT:-8443}/${NC}          - VS Code"
    echo -e "  ${BLUE}https://localhost:${GATEWAY_PORT:-8443}/claude/${NC}   - Claude Code"
    echo -e "  ${BLUE}https://localhost:${GATEWAY_PORT:-8443}/files/${NC}   - 文件管理"
    echo ""
    echo -e "默认密码: ${CODE_SERVER_PASSWORD:-changeme}"
}

stop_services() {
    echo -e "${YELLOW}停止服务...${NC}"
    cd "$DOCKER_DIR"
    $DOCKER_COMPOSE down
    echo -e "${GREEN}✓ 服务已停止${NC}"
}

show_status() {
    cd "$DOCKER_DIR"
    $DOCKER_COMPOSE ps
}

show_logs() {
    cd "$DOCKER_DIR"
    if [ -z "$1" ]; then
        $DOCKER_COMPOSE logs -f --tail=100
    else
        $DOCKER_COMPOSE logs -f --tail=100 "$1"
    fi
}

enter_shell() {
    local service="$1"
    if [ -z "$service" ]; then
        echo -e "${RED}错误: 请指定服务名${NC}"
        echo "可用服务: code-server, claude-web, embedded-dev"
        exit 1
    fi
    
    cd "$DOCKER_DIR"
    $DOCKER_COMPOSE exec "$service" /bin/bash
}

clean() {
    echo -e "${YELLOW}清理构建缓存...${NC}"
    docker system prune -f
    echo -e "${GREEN}✓ 清理完成${NC}"
}

main() {
    check_deps
    init_dirs
    
    case "${1:-}" in
        init)
            init_config
            ;;
        config)
            config_api
            ;;
        test-api)
            test_api
            ;;
        update-config)
            update_config
            ;;
        build)
            build_images
            ;;
        pull)
            pull_images
            ;;
        save)
            save_images
            ;;
        load)
            load_images
            ;;
        up|start)
            start_services
            ;;
        down|stop)
            stop_services
            ;;
        status|ps)
            show_status
            ;;
        logs)
            show_logs "$2"
            ;;
        shell)
            enter_shell "$2"
            ;;
        ssl)
            gen_ssl
            ;;
        clean)
            clean
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
