#!/bin/bash
set -euo pipefail

# 用法：dsh-web [浏览器访问的 HTTPS 根地址]
# 保持前台运行，Ctrl+C 停止。DSH 会打印包含登录令牌的完整地址。
PUBLIC_ROOT="${1:-https://localhost:8443}"
if [ "$#" -gt 1 ]; then
    echo "Usage: dsh-web [https://host:port]" >&2
    exit 1
fi
PUBLIC_AUTHORITY="$(node -e '
    const url = new URL(process.argv[1]);
    if (url.protocol !== "https:" || url.username || url.password ||
        url.pathname !== "/" || url.search || url.hash) {
        console.error("Expected an HTTPS root URL, e.g. https://localhost:8443");
        process.exit(1);
    }
    console.log(url.host);
' "$PUBLIC_ROOT")"

# DSH 拒绝 0.0.0.0；选择容器接口的实际 IPv4 地址供 Nginx 连接。
BIND_ADDRESS="$(node -e '
    const interfaces = Object.values(require("node:os").networkInterfaces()).flat();
    const address = interfaces.find(item => item.family === "IPv4" && !item.internal);
    if (!address) { console.error("No container IPv4 interface found"); process.exit(1); }
    console.log(address.address);
')"

exec dsh web --no-open --host "$BIND_ADDRESS" --port 3080 \
    --public-url "${PUBLIC_ROOT%/}/dsh/" --trusted-host "$PUBLIC_AUTHORITY"
