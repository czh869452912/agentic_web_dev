# 更新日志

当前操作说明见 [项目概览](../README.md) 与 [配置指南](../CONFIGURATION.md)。历史条目中的退役工具、旧路由与旧变量保留当时记录，不作为当前配置。

### 2026-11-06

- DSH 与 Office 改用 code-server 子域名 forwarding，移除独立 `/dsh/` Nginx 规则；启动、域名与证书参数同步。
- 主页面与独立 Office Viewer 增加本地早期 API 注入，适配已有数据卷，提供关闭开关和幂等更新。
- DSH、Office、pnpm 默认使用 `latest`；记录实际版本并增加兼容单元测试和真实浏览器冒烟脚本。
- Chromium 108 与 156 通过基础表格编辑、刷新与独立浏览器上下文读取验证；完整 Win7 与其他应用流程仍待验收。
- 整理文档导航、当前兼容性指南及历史调研归档；HTTPS、持久化与升级操作集中维护。

### 2026-11-05
- 保留 OpenCode，新增 Kilo Code 扩展；移除 Claude Code、Cline、Roo Code 的安装与专用配置。
- 新增 DSH + Univer Office、持久化数据和 `/dsh/` 网关入口。

### v4.2.0 (2026-03-10)
- 新增：`scripts/fix-line-endings.sh`，一键清理跨平台编辑引入的 CRLF 行尾和 UTF-8 BOM，防止配置文件在 Linux 上损坏

### v4.1.0 (2026-03-09)
- 修复：Dockerfile 补充 `clangd` 包（`clang-tools` 不包含 language server 二进制），vscode-clangd 扩展现在开箱即用
- 新增：manage.sh `--docker-only` 模式，`up`/`down`/`status`/`logs`/`shell` 均可在无 docker compose 环境下运行（`build` 本来就直接用 `docker build`，不受影响）
- 新增：LiteLLM 统一 LLM 网关（可选服务，`--llm` 启用）
  - 同时暴露 Anthropic（`/v1/messages`）和 OpenAI（`/v1/chat/completions`）格式
  - 内网 OpenAI 兼容 API → 转换 → Claude Code / Cline / Roo Code
  - 统一 API key，各工具无需单独登录配置
  - nginx `/llm/` 路由使用懒解析，服务未启动时其他服务不受影响
- 新增：`configs/litellm_config.yaml.example` 配置模板

### v4.0.0 (2026-03-07)
- 将 embedded-dev 容器工具链全部迁移进 code-server，终端直接使用所有嵌入式工具
- 新增：QEMU (qemu-user-static / qemu-system-arm)、stlink-tools、libftdi1-dev、libhidapi-dev
- 新增：pyocd、esptool、conan、scons、Sphinx + Breathe + Exhale、Google Test
- 新增：pyusb、pycparser、cffi 等 Python 支持库
- 删除：embedded-dev 服务及 Dockerfile.embedded、embedded-* 辅助脚本
- 更新：manage.sh / test-docker-build.sh 去除 embedded-dev 相关构建/保存逻辑

### v3.2.0 (2026-03-07)
- 修复 SSL 证书不含 SAN 导致 Service Worker 注册失败（Cline 插件 webview 不可用）
- manage.ps1：重新生成证书后自动导入 Windows 受信任根存储
- manage.sh：gen_ssl 支持可选参数 `<host>`，云端 IP/域名加入证书 SAN；up 时读取 `.env` 中 `SERVER_DOMAIN` 自动传参
- manage.sh：修正旧变量名（LLM_API_URL → ANTHROPIC_*）、update-config 引用已删容器、start_services 错误 URL、save_images 包含已删镜像
- manage.sh：pull_images 改为从 docker-compose.yml / Dockerfile 动态读取镜像版本，与 manage.ps1 保持一致
- 新增"云端部署 SSL 配置"文档，含三种方案对比及各平台证书导入步骤

### v3.1.0 (2026-03-06)
- 修复 nginx WebSocket 代理（`$host` → `$http_host`），解决工作台无法连接（错误 1006）
- 切换 apt 源至阿里云 HTTP 镜像，解决国内网络无法构建问题
- 移除不可用包（`cloc`、`astyle` 等）及已被 `probe-rs-tools` 替代的 `cargo-embed`
- 文档全面更新，与实际测试状态保持一致

### v3.0.0 (2026-03-06)
- Claude Code CLI 与 code-server 合并为单一容器，终端直接使用 `claude`
- ARM GCC 13.2 / clang / cppcheck / openocd 内置于 IDE 容器
- 移除独立 claude-web 服务（原为无功能静态页）
- 新增 Windows PowerShell 管理脚本 `scripts/manage.ps1`
- 修复 nginx 健康检查、build context、docker compose v1/v2 兼容性等问题
- 新增 `.gitattributes` 防止 Windows CRLF 破坏 Linux 脚本

### v1.0.0 (2026-03-05)
- 初始版本
