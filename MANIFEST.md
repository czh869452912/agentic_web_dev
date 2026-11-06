# 文件清单与说明

使用入口见 [README](README.md)，文档职责见 [文档导航](docs/README.md)。以下为当前仓库布局，不以历史镜像大小或扩展数量作为固定规格。

## 配置与镜像

| 路径 | 用途 |
| --- | --- |
| [docker/.env.example](docker/.env.example) | 密码、网关端口、forwarding 域名和 LiteLLM 参数模板 |
| `docker/.env` | 实际部署变量，不入库 |
| [docker/Dockerfile.code-server](docker/Dockerfile.code-server) | code-server、AI 工具、DSH/Office、兼容层和嵌入式工具链 |
| [docker/docker-compose.yml](docker/docker-compose.yml) | Nginx、code-server、File Browser，加可选 `llm` profile |
| [configs/nginx.conf](configs/nginx.conf) | 单一 HTTPS 网关；DSH 交给 code-server forwarding |
| [configs/settings.json](configs/settings.json) | 镜像内默认 IDE 设置 |
| [configs/filebrowser.json](configs/filebrowser.json) | 文件管理配置 |
| [configs/litellm_config.yaml.example](configs/litellm_config.yaml.example) | 可选 LiteLLM 配置模板；实际 `.yaml` 不入库 |
| `configs/ssl/` | 证书和私钥；`up` 仅在证书缺失时生成 |
| [configs/vsix/](configs/vsix/README.md) | 构建时加载的离线扩展 |

2026-11-06 的开发镜像大小约 9.80 GB；实际组件版本和镜像 ID 记录在 [兼容性指南](docs/compatibility.md#构建结果)，后续构建可能变化。

## 兼容层

| 路径 | 用途 |
| --- | --- |
| [configs/browser-compat/README.md](configs/browser-compat/README.md) | 维护与验证说明 |
| [browser.js](configs/browser-compat/browser.js)、[signal-any.js](configs/browser-compat/signal-any.js) | 按需标准 API 与取消信号兼容实现 |
| [host.mjs](configs/browser-compat/host.mjs)、[cordis.patch.yml](configs/browser-compat/cordis.patch.yml) | DSH Host 插件和早期脚本注入 |
| [prepare-viewer.mjs](configs/browser-compat/prepare-viewer.mjs) | Office Viewer 入口幂等注入，避免改写共享硬链接 |
| [forwarding.mjs](configs/browser-compat/forwarding.mjs) | code-server 与 DSH 共用域名和公开 URL 校验 |
| [build.mjs](configs/browser-compat/build.mjs)、[package.json](configs/browser-compat/package.json) | 构建脚本与依赖；产出忽略入库的 `dist/compat.js` 和版本记录 |
| [test/compat.test.mjs](configs/browser-compat/test/compat.test.mjs) | API 语义、URL 配置、注入和升级测试 |

## 脚本

| 路径 | 用途 |
| --- | --- |
| [scripts/manage.sh](scripts/manage.sh) | Linux/macOS 服务管理，支持 Compose 和 Docker-only |
| [scripts/manage.ps1](scripts/manage.ps1) | Windows PowerShell 服务管理 |
| [scripts/code-server-entrypoint.sh](scripts/code-server-entrypoint.sh) | 合并扩展 seed、卸载退役扩展、启动带 forwarding 的 code-server |
| [scripts/dsh-web.sh](scripts/dsh-web.sh) | DSH 公开 URL 校验、Viewer 处理及启动 |
| [scripts/dsh-chromium.sh](scripts/dsh-chromium.sh) | Office 服务端 Chromium 渲染入口 |
| [scripts/test-dsh-browser.mjs](scripts/test-dsh-browser.mjs) | 隔离环境下的真实浏览器与表格交互测试 |
| [scripts/test-docker-build.sh](scripts/test-docker-build.sh) | 通用镜像构建检查；不替代浏览器兼容性测试 |
| [scripts/fix-line-endings.sh](scripts/fix-line-endings.sh) | 跨平台编辑后的 CRLF/BOM 清理 |

## 文档

| 路径 | 内容 |
| --- | --- |
| [README.md](README.md) | 概览与首次启动 |
| [QUICKSTART.md](QUICKSTART.md) | 日常命令与开发工具速查 |
| [CONFIGURATION.md](CONFIGURATION.md) | 服务与模型配置、持久化和升级 |
| [EXTENSIONS.md](EXTENSIONS.md) | 扩展清单、安装和示例 |
| [docs/README.md](docs/README.md) | 文档导航及迁移说明 |
| [docs/https.md](docs/https.md) | 域名、SAN、客户端信任与证书更换 |
| [docs/compatibility.md](docs/compatibility.md) | 当前兼容方案、版本、验证结果与验收边界 |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | 历史更新日志 |
| `docs/archive/` | 原始兼容性调研与实施前评估，明确标记为历史资料 |

## 运行数据与仓库规则

| 路径或资源 | 用途 |
| --- | --- |
| `workspace/` | code-server 和 File Browser 共享项目文件 |
| `dsh-data` 卷 | DSH 配置、会话与 web profile 插件 |
| `code-extensions`、`code-config` 卷 | 扩展与部分 code-server 配置；完整范围见 [持久化说明](CONFIGURATION.md#数据持久化) |
| `filebrowser-db` 卷 | File Browser 数据库 |
| `images/` | `save` 导出的离线镜像 |
| `logs/nginx/` | 网关访问与错误日志 |
| `.gitattributes` | 跨平台行尾规则 |
| `.gitignore` | 排除密钥、用户数据、镜像及生成物 |
| `.dockerignore` | 排除工作区、文档、测试临时文件和本地依赖等构建上下文 |

Compose 的实际卷名通常带项目名前缀，Docker-only 使用固定名。查看 `docker inspect` 确认当前挂载；升级、备份和离线部署步骤见 [配置指南](CONFIGURATION.md) 与 [项目概览](README.md#常用管理)。
