# 文件清单与说明

## 配置文件

| 文件 | 用途 | 需要修改 |
|------|------|----------|
| `docker/.env` | 环境变量（API Key、密码等） | 必须 |
| `docker/.env.example` | 配置模板 | 参考 |
| `configs/nginx.conf` | 反向代理配置 | 可选 |
| `configs/settings.json` | VS Code 默认设置 | 可选 |
| `configs/filebrowser.json` | 文件浏览器配置 | 一般不改 |
| `configs/ssl/` | SSL 证书目录（`up` 时自动生成） | 自动 |
| `configs/vsix/` | 离线 VSIX 扩展安装包目录 | 离线部署时放入 |
| `configs/vsix/README.md` | VSIX 离线安装指南 | 参考 |

## Docker 镜像

| 文件 | 用途 | 实测大小 |
|------|------|----------|
| `docker/Dockerfile.code-server` | VS Code + Claude Code CLI + ARM 工具链 + 15+ 扩展 | ~4GB |
| `docker/Dockerfile.embedded` | 完整重型工具链（QEMU、Rust、Unity Test 等） | ~3GB |
| `docker/docker-compose.yml` | 服务编排（3 个服务：gateway、code-server、embedded-dev、filebrowser） | - |

## 脚本

| 文件 | 用途 |
|------|------|
| `scripts/manage.sh` | Linux/macOS 环境管理脚本 |
| `scripts/manage.ps1` | Windows PowerShell 环境管理脚本 |
| `scripts/code-server-entrypoint.sh` | code-server 容器启动脚本（配置 Claude Code 后启动 code-server） |

## 文档

| 文件 | 内容 |
|------|------|
| `README.md` | 完整使用文档 |
| `QUICKSTART.md` | 快速参考 |
| `CONFIGURATION.md` | API 配置详细指南 |
| `MANIFEST.md` | 本文件 |
| `EXTENSIONS.md` | VS Code 扩展说明 |
| `docker-build-test-report.md` | Docker 构建测试报告 |

## 其他

| 文件 | 用途 |
|------|------|
| `.gitattributes` | 强制 `.sh` 文件使用 LF 行尾，防止 Windows CRLF 破坏 Linux 脚本 |
| `.gitignore` | Git 忽略规则（排除 `.env`、镜像、证书等） |
| `.dockerignore` | Docker 构建上下文忽略规则 |

## 目录

| 目录 | 用途 | 持久化 |
|------|------|--------|
| `workspace/` | 代码工作区（所有容器共享） | 是 |
| `configs/vsix/` | VS Code 扩展离线安装包 | 构建时需要 |
| `images/` | 离线镜像存储（`save` 命令产生） | 可删除 |
| `logs/` | Nginx 日志 | 可删除 |

---

## 首次部署检查清单

- [ ] 复制 `docker/.env.example` 为 `docker/.env`
- [ ] 编辑 `docker/.env` 配置 `ANTHROPIC_API_KEY` 或 `ANTHROPIC_BASE_URL`
- [ ] 运行 `build` 构建镜像（需要网络）
- [ ] 运行 `up` 启动服务（自动生成 SSL）
- [ ] 访问 https://localhost:8443/ 输入密码
- [ ] 在 VS Code 终端运行 `claude` 验证 Claude Code

---

## 离线部署检查清单

- [ ] 外网：`build` + `save` 导出镜像
- [ ] 外网（可选）：下载 VSIX 扩展放入 `configs/vsix/`
- [ ] 打包传输到内网
- [ ] 内网：编辑 `docker/.env` 配置内网代理
- [ ] 内网：`load` 加载镜像
- [ ] 内网：`up` 启动服务
