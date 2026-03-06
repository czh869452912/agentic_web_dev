#!/bin/bash
set -e

# ---- 配置 Claude Code ----
# 容器以 root 运行，Claude Code 读取 /root/.claude/settings.json
CLAUDE_DIR="/root/.claude"
mkdir -p "$CLAUDE_DIR"

if [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$ANTHROPIC_BASE_URL" ]; then
    cat > "$CLAUDE_DIR/settings.json" <<CONFIG_EOF
{
  "env": {
    "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY:-}",
    "ANTHROPIC_BASE_URL": "${ANTHROPIC_BASE_URL:-}",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "8192"
  }
}
CONFIG_EOF
    echo "[entrypoint] Claude Code configured: ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-<default Anthropic>}"
else
    echo "[entrypoint] No API config found, Claude Code will use interactive login"
fi

# ---- 验证 claude CLI 是否存在 ----
if command -v claude >/dev/null 2>&1; then
    echo "[entrypoint] claude CLI found at: $(which claude)"
else
    echo "[entrypoint] WARNING: claude CLI not found in PATH"
fi

# ---- 启动 code-server ----
exec dumb-init /usr/bin/code-server \
    --bind-addr 0.0.0.0:8080 \
    --disable-telemetry \
    --disable-update-check \
    --auth password \
    "$@"
