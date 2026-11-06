# DSH 与 Office 浏览器兼容性指南

更新日期：2026-11-06。本文集中记录当前方案、已验证版本和验收边界。部署参数与升级操作见 [配置指南](../CONFIGURATION.md)，技术维护与测试用法见 [兼容层说明](../configs/browser-compat/README.md)。原始调研和实施前评估保留在 [归档目录](README.md#历史资料)。

## 当前结论

在保持上游最新版优先的前提下，通过少量前端预先注入，DSH 基础页面和 Office 基础表格流程已在 Linux 的真实 Chromium 108 与 156 中通过验证。这个结果不等同于 Win7 真机或所有 Office 功能已完成兼容验收。

访问链路为：浏览器 → HTTPS Nginx 统一入口 → code-server 子域名 forwarding → DSH → Office。Office 使用同一 origin 下的 `/univer-viewer`、`/univer-api`、`/uf` 和协作 WebSocket，保留原有鉴权与文档范围检查。

| 入口或配置 | 当前处理 |
| --- | --- |
| `https://3080.localhost:8443/` | 本机默认 forwarding 根地址；首次打开终端输出的完整登录链接 |
| 远程域名 | 在 `docker/.env` 配置 `CODE_SERVER_PROXY_DOMAIN`，准备 DNS/hosts 与证书 |
| `/dsh/` | 已移除专用规则，不再使用 |
| `/proxy/3080/` | 不重写 Office 的绝对 URL，不作为 Office 入口 |
| DSH 3080 / Office 9080 | 容器内部使用，不单独映射到宿主机 |

## 版本与适配策略

DSH、Office 和 pnpm 默认使用 npm 的 `latest` 标签；其他组件保留项目现有更新策略。此兼容层不要求冻结或降级其他组件。每次升级记录实际安装版本，重新运行相同的浏览器检查。

预先注入仅用于缺失的运行时 API。只有在真实浏览器中复现了语法、CSS 或浏览器 Worker 问题，才针对对应入口增加适配。Kilo、code-server 和 OpenCode GUI 各自验收。

## 已实施

- 删除 Nginx 专用 `/dsh/` 路由，统一由 code-server 子域名 forwarding 转发 DSH、Office Viewer、API 和 WebSocket。DSH 监听 `127.0.0.1:3080`，内部 Office 网关 9080 不对宿主机发布。
- 本地默认入口为 `https://3080.localhost:8443/`；网关端口、自定义 forwarding 域名与 DSH 公开地址使用同一配置校验。远程部署通过 `CODE_SERVER_PROXY_DOMAIN={{port}}.dev.example:8443` 配置，并提供对应 DNS 和证书。管理脚本生成的证书包含 DSH 域名。
- `configs/browser-compat/` 提供离线兼容脚本。DSH 通过 `webserver/index-inject` 在 head 首位同步加载，Office Viewer 的独立 HTML 入口也在模块脚本之前加载。
- 仅按能力补齐 `Promise.withResolvers`、`Array.prototype.toSorted`、`URL.parse`、`URL.canParse`、`AbortSignal.any`。使用 core-js 按需模块及带清理机制的取消信号实现，保留现代浏览器可用的原生实现。
- 启动 `dsh-web` 时幂等处理当前 Office 入口，支持已有数据卷和插件升级；原子替换 HTML，避免改写 pnpm store 的共享硬链接。使用 `DSH_BROWSER_COMPAT=0 dsh-web` 可关闭并移除注入。
- DSH、Office、pnpm 的构建默认值均为 `latest`。未降级 code-server、Node、服务端 Chromium 或其他扩展；未重编译上游前端业务 bundle，也未引入全局 CSS/Worker 改写。

镜像构建还保留 Python 虚拟环境隔离修复，恢复必要的 npm 原生依赖安装脚本，并将 Chromium 大包下载切换到 Debian 官方 HTTPS 源。

## 构建结果

镜像：`code-server-custom:latest`，大小约 9.80 GB（十进制）。

镜像 ID：`sha256:12b4b62a8961dd37119f17442abda9c930eb0ceae797cb2cec1c012a5a82e509`。

| 组件 | 镜像内实际版本 |
| --- | --- |
| code-server / Code | 4.145.0 / 1.145.0 |
| DSH | 0.2.2-rc.1 |
| dsh-univer-office | 0.4.0 |
| pnpm / Node | 12.18.0 / 24.22.2 |
| 服务端 Chromium | 156.0.8078.79 |
| OpenCode CLI / GUI | 1.19.5 / 0.4.4 |
| Kilo Code | 7.8.27 |
| core-js / esbuild | 3.51.0 / 0.28.2 |

兼容脚本摘要 `5a7798ab83ef7527`；镜像内 `/opt/dsh-browser-compat/dist/version.json` 记录实际构建依赖版本与摘要。

此表是 2026-11-06 已验证镜像的快照，不是版本锁定清单，也不代表后续所有 `latest` 构建或已有数据卷的实际版本。Docker 安装层缓存和已有插件卷需分别处理，操作集中维护在 [升级说明](../CONFIGURATION.md#更新已有部署)。

## 验证结果

在独立 Docker 网络中运行新镜像和实际 Nginx 配置。测试没有挂载兼容层或启动脚本源码覆盖镜像文件，没有修改用户的数据卷或工作目录。

| 验证 | 结果 |
| --- | --- |
| 镜像完整构建、最终镜像内 4 项兼容单元测试 | 通过 |
| Compose 配置、Nginx 配置、Bash 语法、PowerShell 语法、Git 空白检查 | 通过 |
| 新生成证书的本机和自定义 forwarding 域名 SAN | 通过 |
| Chromium 108.0.5359.29，Linux 真实内核 | 以下基础流程通过，无页面 JavaScript 异常 |
| Chromium 156.0.8078.79，Linux 真实内核 | 同组基础流程通过，无页面 JavaScript 异常 |

浏览器流程包含 HTTPS 网关、code-server 密码登录、DSH 令牌鉴权、兼容脚本加载、会话创建、Office API 与网关启动、表格创建、独立 Viewer 加载、键盘编辑单元格，以及刷新后复制读取内容。另用仅共享鉴权 Cookie 的全新浏览器上下文读取同一表格，排除原页面本地缓存影响。缺少文档范围参数的 Viewer 请求返回 403，转发未绕过该检查。

可重复执行的浏览器脚本为 [test-dsh-browser.mjs](../scripts/test-dsh-browser.mjs)；测试环境与用法见 [兼容层说明](../configs/browser-compat/README.md)。测试只创建隔离容器内的 `.univer` 文件。测试日志包含 DSH 登录令牌，不应直接发布。

上述浏览器测试忽略了临时测试证书的信任错误，因此不代表客户端证书分发与信任已经验收；生产部署仍需按 [HTTPS 指南](https.md) 配置。

## 尚未覆盖

以上结果覆盖 DSH 基础页面和 Office 基础表格流程。未进行真实 Win7 浏览器、中文输入法、GPU/字体差异、大文档、文档/幻灯片、导入导出、完整模型请求/流式输出/工具审批和取消流程的全面验收。

Kilo、code-server 工作台及 OpenCode GUI 是独立执行环境，本次 DSH 注入不会自动进入它们。其 Chromium 108 兼容性仍需分别测试；未根据静态依赖线索提前改写它们或降低版本。

108 与现代浏览器均能完成当前基础表格流程，暂未增加 CSS、语法重编译或浏览器 Worker 补丁。后续按真实故障补充局部适配。

后续验收应分别记录：目标 Win7 浏览器完整版本与补丁、中文输入和字体、文档/幻灯片及导入导出、大文档性能、模型流式输出/审批/取消/重连，以及 IDE 和其他扩展的网页视图。升级后的镜像与实际数据卷版本也需分别核对。
