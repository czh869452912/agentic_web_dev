#!/bin/bash
set -euo pipefail

# ---- 合并内置插件 seed 到 extensions 目录 ----
# seed 目录随镜像构建，volume 挂载不会覆盖它；每次启动时将内置插件同步过去
# -n (no-clobber) 保证不覆盖用户在运行时手动安装的同名插件
SEED_DIR="${CODE_SERVER_EXTENSIONS_SEED:-/opt/code-server-extensions-seed}"
EXT_DIR="${CODE_SERVER_EXTENSIONS_DIR:-/home/coder/.local/share/code-server/extensions}"
if [ -d "$SEED_DIR" ] && [ "$(ls -A "$SEED_DIR" 2>/dev/null)" ]; then
    mkdir -p "$EXT_DIR"
    cp -rn "$SEED_DIR"/. "$EXT_DIR"/
    chown -R coder:coder "$EXT_DIR"
    echo "[entrypoint] Built-in extensions merged from $SEED_DIR"
fi

# ---- 卸载旧数据卷中已移除的 AI 扩展 ----
# 使用扩展管理器同步更新 extensions.json；保留用户的配置与会话数据。
installed_extensions="$(code-server --extensions-dir "$EXT_DIR" --list-extensions)"
for extension_id in anthropic.claude-code saoudrizwan.claude-dev RooVeterinaryInc.roo-cline; do
    if printf '%s\n' "$installed_extensions" | grep -Fxi "$extension_id" >/dev/null; then
        echo "[entrypoint] Removing retired extension: $extension_id"
        code-server --extensions-dir "$EXT_DIR" --uninstall-extension "$extension_id"
    fi
done

# ---- 启动 code-server ----
PROXY_DOMAIN="$(node /opt/dsh-browser-compat/forwarding.mjs domain)"
exec dumb-init /usr/bin/code-server \
    --bind-addr 0.0.0.0:8080 \
    --extensions-dir "$EXT_DIR" \
    --user-data-dir /home/coder/.local/share/code-server \
    --disable-telemetry \
    --disable-update-check \
    --auth password \
    --proxy-domain "$PROXY_DOMAIN" \
    "$@"
