#!/bin/sh
# code-server 镜像以 root 运行；浏览器仅用于容器内的无头渲染。
exec /usr/bin/chromium --no-sandbox --disable-dev-shm-usage "$@"
