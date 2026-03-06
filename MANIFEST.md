# 文件清单与说明

## 配置文件

| 文件 | 用途 | 需要修改 |
|------|------|----------|
| `docker/.env` | 环境变量（API URL、密码等） | ✅ 必须 |
| `docker/.env.example` | 配置模板 | ❌ 参考 |
| `configs/nginx.conf` | 反向代理配置 | ⚠️ 可选 |
| `configs/settings.json` | VS Code 默认设置 | ⚠️ 可选 |
| `configs/filebrowser.json` | 文件浏览器配置 | ❌ 一般不改 |
| `configs/claude-config.json` | Claude Code 配置模板 | ❌ 自动生成 |
| `configs/vsix/README.md` | Claude Code VSIX 离线安装指南 | ❌ 参考 |
| `configs/ssl/` | SSL 证书目录 | ✅ 自动生成 |

## Docker 镜像

| 文件 | 用途 | 大小 |
|------|------|------|
| `docker/Dockerfile.code-server` | VS Code + 15+ 预装插件 | ~600MB |
| `docker/Dockerfile.claude` | Claude Code 服务 | ~300MB |
| `docker/Dockerfile.embedded` | 完整软件工程工具链 | ~3GB |
| `docker/docker-compose.yml` | 服务编排 | - |

## 脚本

| 文件 | 用途 |
|------|------|
| `scripts/manage.sh` | 环境管理（构建/启动/配置） |

## 文档

| 文件 | 内容 |
|------|------|
| `README.md` | 完整使用文档 |
| `QUICKSTART.md` | 快速参考 |
| `CONFIGURATION.md` | API 配置详细指南 |
| `MANIFEST.md` | 本文件 |

## 目录

| 目录 | 用途 | 持久化 |
|------|------|--------|
| `workspace/` | 代码工作区 | ✅ 是 |
| `models/` | Ollama 模型（如需要） | ✅ 是 |
| `configs/vsix/` | VS Code 扩展离线安装包 | ⚠️ 构建时需要 |
| `images/` | 离线镜像存储 | ❌ 可删除 |
| `logs/` | 日志文件 | ❌ 可删除 |
| `.secrets/` | 敏感信息存储 | ✅ 是（不提交git） |

## 构建产物

| 文件 | 生成方式 | 用途 |
|------|----------|------|
| `images/*.tar` | `./scripts/manage.sh save` | 离线部署 |
| `images.tar.gz` | 手动打包 | 离线部署包 |
| `ssl/server.crt` | `./scripts/manage.sh ssl` | HTTPS 证书 |
| `ssl/server.key` | `./scripts/manage.sh ssl` | HTTPS 私钥 |

---

## 首次部署检查清单

- [ ] 复制 `docker/.env.example` 为 `docker/.env`
- [ ] 编辑 `docker/.env` 配置内网 API
- [ ] 运行 `./scripts/manage.sh ssl` 生成证书
- [ ] 运行 `./scripts/manage.sh test-api` 测试 API
- [ ] 运行 `./scripts/manage.sh build` 构建镜像
- [ ] 运行 `./scripts/manage.sh up` 启动服务
- [ ] 访问 https://localhost:8443/ 验证

---

## 离线部署检查清单

- [ ] 在外网运行 `./scripts/manage.sh save`
- [ ] 打包 `tar czvf dev-env.tar.gz agentic-dev-env/`
- [ ] 传输到内网
- [ ] 内网解压 `tar xzvf dev-env.tar.gz`
- [ ] 编辑配置 `docker/.env`
- [ ] 运行 `./scripts/manage.sh load`
- [ ] 运行 `./scripts/manage.sh up`
