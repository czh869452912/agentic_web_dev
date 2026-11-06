#!/bin/bash
set -euo pipefail

# 用法：dsh-web [code-server 子域名 forwarding 的 HTTPS 根地址]
# 保持前台运行，Ctrl+C 停止。DSH 会打印包含登录令牌的完整地址。
if [ "$#" -gt 1 ]; then
    echo "Usage: dsh-web [https://host:port]" >&2
    exit 1
fi
PUBLIC_ROOT="$(node /opt/dsh-browser-compat/forwarding.mjs url "${1:-${DSH_PUBLIC_URL:-}}")"
PUBLIC_AUTHORITY="${PUBLIC_ROOT#https://}"
PUBLIC_AUTHORITY="${PUBLIC_AUTHORITY%/}"

# 对已有 dsh-data 卷及运行时升级后的 Office 同样生效；不修改业务 bundle。
node /opt/dsh-browser-compat/prepare-viewer.mjs "${DSH_HOME:-/var/lib/dsh}/profiles/web"
compat_args=()
if [ "${DSH_BROWSER_COMPAT:-1}" != "0" ]; then
    compat_args=(--patch /opt/dsh-browser-compat/cordis.patch.yml)
fi

# 内置 forwarding 与 DSH 位于同一容器；DSH 拒绝 wildcard，使用 loopback。
exec dsh web "${compat_args[@]}" --no-open --host 127.0.0.1 --port 3080 \
    --public-url "${PUBLIC_ROOT%/}/" --trusted-host "$PUBLIC_AUTHORITY"
