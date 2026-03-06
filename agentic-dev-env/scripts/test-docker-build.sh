#!/bin/bash
# ============================================================
# Docker 镜像构建测试脚本
# 用于验证所有 Dockerfile 是否能正确构建
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"

echo "=========================================="
echo "  Docker 镜像构建测试"
echo "=========================================="
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker 版本:${NC} $(docker --version)"
echo ""

# 测试构建函数
test_build() {
    local name=$1
    local dockerfile=$2
    local context=$3
    local tag=$4

    echo -e "${YELLOW}测试构建: $name${NC}"
    echo "  Dockerfile: $dockerfile"
    echo "  Context: $context"
    echo "  Tag: $tag"
    echo ""

    if docker build -f "$dockerfile" -t "$tag" "$context" 2>&1; then
        echo -e "${GREEN}✓ $name 构建成功${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ $name 构建失败${NC}"
        echo ""
        return 1
    fi
}

# 记录失败数
FAILED=0

# 1. 测试 Claude Code 镜像
echo "------------------------------------------"
if ! test_build \
    "Claude Code" \
    "$DOCKER_DIR/Dockerfile.claude" \
    "$DOCKER_DIR" \
    "agentic-dev-env/claude:latest"; then
    ((FAILED++))
fi

# 2. 测试 Code Server 镜像
echo "------------------------------------------"
if ! test_build \
    "Code Server" \
    "$DOCKER_DIR/Dockerfile.code-server" \
    "$PROJECT_ROOT" \
    "agentic-dev-env/code-server:latest"; then
    ((FAILED++))
fi

# 3. 测试 Embedded Dev 镜像
echo "------------------------------------------"
if ! test_build \
    "Embedded Dev" \
    "$DOCKER_DIR/Dockerfile.embedded" \
    "$DOCKER_DIR" \
    "agentic-dev-env/embedded:latest"; then
    ((FAILED++))
fi

# 4. 测试 docker-compose 配置
echo "------------------------------------------"
echo -e "${YELLOW}测试 docker-compose 配置...${NC}"
cd "$DOCKER_DIR"
if docker-compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ docker-compose.yml 配置有效${NC}"
else
    echo -e "${RED}✗ docker-compose.yml 配置无效${NC}"
    ((FAILED++))
fi
echo ""

# 测试结果汇总
echo "=========================================="
echo "  测试结果汇总"
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}所有测试通过！${NC}"
    echo ""
    echo "构建的镜像:"
    docker images | grep "agentic-dev-env" || true
    exit 0
else
    echo -e "${RED}有 $FAILED 个测试失败${NC}"
    exit 1
fi
