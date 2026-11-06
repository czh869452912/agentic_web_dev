# DSH 浏览器兼容层

当前方案、已验证版本和覆盖范围见 [兼容性指南](../../docs/compatibility.md)，部署域名和升级操作见 [配置指南](../../CONFIGURATION.md)。本文面向兼容层维护与测试。

主页面使用 `webserver/index-inject` 在 head 首位加载同步本地脚本。Office Viewer 的独立入口也加载同一资源；不改业务 JavaScript，不重建上游 Viewer，不改服务端 Node 或渲染浏览器。

当前补齐 `Promise.withResolvers`、`Array.prototype.toSorted`、`URL.parse`、`URL.canParse` 和 `AbortSignal.any`。前四项使用 core-js 的按需模块；取消信号实现包含首个取消原因、输入校验和监听清理。现代浏览器保留其可用的原生实现。

`dsh-web` 每次启动都会对当前 web profile 的 Viewer 入口做幂等处理，因此旧数据卷和运行时升级的 Office 也会注入。使用 `DSH_BROWSER_COMPAT=0 dsh-web` 会移除 Viewer 标签，并停用 Host 插件。HTML 结构不符合预期时启动会报错，避免默默漏掉兼容层。

Viewer HTML 通过临时文件与原子替换更新，避免写穿 pnpm store 的共享硬链接。`forwarding.mjs` 则由 code-server 启动脚本与 `dsh-web` 共用，统一校验域名模板和 HTTPS 根地址。

安装默认使用 latest，构建产物的 `dist/version.json` 记录内容摘要和实际构建依赖版本。升级后运行冒烟检查，不要求冻结其他组件。

## 单元验证

在本目录运行：

```sh
npm install --no-package-lock
npm run build
npm test
```

4 项测试覆盖取消信号语义与监听清理、稳定排序及不修改原数组、缺失 API、forwarding 配置、重复/关闭注入、Office 升级后重新注入及共享硬链接保护。镜像构建时也会运行这些测试。

## 浏览器验证

生产镜像含用于 Office 渲染的现代 Chromium，不额外安装 Playwright 或 Chromium 108。测试时在隔离容器可写的 `/qa` 中准备真实旧内核：

```bash
cd /qa
npm install --no-save --package-lock=false playwright@1.28.1
PLAYWRIGHT_BROWSERS_PATH=/qa/browsers npx playwright install chromium
```

该 Playwright 版本对应 Chromium 108.0.5359.29；测试结果会输出实际内核版本。通过 `DSH_TEST_BROWSER=/usr/bin/chromium` 可切换到镜像内现代浏览器，不能用修改 User-Agent 替代旧内核验证。

`scripts/test-dsh-browser.mjs` 需要以下测试环境：

- 当前镜像启动 code-server，配置 forwarding 模板 `{{port}}.localhost:8443`，并设置临时测试 `PASSWORD`。
- 同一隔离 Docker 网络中的 Nginx 加载仓库配置，HTTPS 证书包含 `3080.localhost`；code-server 的网络别名为 `code-server`、`filebrowser`（后者仅满足本次不用的上游解析）。不需要发布宿主机端口。
- 在 code-server 容器内运行 `dsh-web >/tmp/dsh-smoke.log 2>&1`。日志含登录令牌，不应公开。
- 设 `PLAYWRIGHT_MODULE=/qa/node_modules/playwright`、`PLAYWRIGHT_BROWSERS_PATH=/qa/browsers`、`DSH_TEST_GATEWAY_IP=<测试网关容器 IP>`，运行该测试脚本。

将仓库 `scripts/` 只读挂到隔离容器 `/test-scripts` 后，在容器内执行：

```bash
export PLAYWRIGHT_MODULE=/qa/node_modules/playwright
export PLAYWRIGHT_BROWSERS_PATH=/qa/browsers
export DSH_TEST_GATEWAY_IP=172.18.0.3  # 替换为测试网关实际 IP
DSH_TEST_SCREENSHOT=/qa/dsh-108.png node /test-scripts/test-dsh-browser.mjs
DSH_TEST_BROWSER=/usr/bin/chromium DSH_TEST_SCREENSHOT=/qa/dsh-modern.png node /test-scripts/test-dsh-browser.mjs
```

`PASSWORD` 使用测试容器启动时的临时 code-server 密码。脚本固定测试 `https://3080.localhost:8443/`，不是任意生产域名探测器。网关 IP 可在宿主机通过 `docker inspect` 查询。复测最终镜像时，兼容层和启动脚本使用镜像内文件，不用源码挂载覆盖。

测试通过 HTTPS 网关完成 code-server 登录和 DSH 鉴权，检查主页面 API、Office 网关、文档范围拒绝、会话及表格创建、独立 Viewer 和键盘编辑。随后在仅共享 Cookie 的全新浏览器上下文中刷新并复制读取单元格，排除原页面缓存影响；收集页面 JavaScript 异常与截图。测试在隔离容器的 `/workspace` 创建 `.univer` 文件，结束后删除测试容器及网络即可。

可选变量：`DSH_TEST_LOG` 指定启动日志，`DSH_TEST_SCREENSHOT` 指定截图路径。测试忽略临时 HTTPS 证书的信任错误，客户端证书信任须另行验收。结果不等同于 Win7 真机、大文档、完整模型流程或所有文档类型通过；当前未对 Worker 和 CSS 做全局劫持。
