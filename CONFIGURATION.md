# 配置指南

## 服务配置

复制 `docker/.env.example` 为 `docker/.env`，修改 `CODE_SERVER_PASSWORD`、`SUDO_PASSWORD`。默认 HTTPS 端口由 `GATEWAY_PORT` 控制，云端部署还可填写 `SERVER_DOMAIN`。

```bash
./scripts/manage.sh init
./scripts/manage.sh build
./scripts/manage.sh up
```

Windows 使用 `.\scripts\manage.ps1 init`、`build`、`up`。

## OpenCode

在 IDE 终端执行 `opencode`，通过其提供商配置连接模型。使用自建接口时，按 [OpenCode 提供商文档](https://opencode.ai/docs/providers/) 配置兼容提供商、Base URL、API Key 和模型 ID。

## Kilo Code

镜像安装官方扩展 `kilocode.kilo-code`。打开 Kilo Code 设置的 Providers 页面，配置提供商和模型；自建 Chat Completions 接口选择 OpenAI Compatible，填写 Base URL、API Key 和模型 ID。新版界面可通过 Custom provider 添加。

容器内的扩展后端可以直连 `http://llm-gateway:4000/v1` 或内网模型地址。不要使用容器内的 `localhost` 指向宿主机服务。模型请求及其工具调用能力取决于所选提供商。

参考：[Kilo Code 自定义提供商](https://kilo.ai/docs/ai-providers/openai-compatible)。

## DSH + Univer Office

在 IDE 终端执行 `dsh-web`，远程部署执行 `dsh-web https://服务器地址:8443`。打开终端输出的完整登录地址，在 Settings → Models 配置模型，选择 `/workspace` 工作区。

DSH 使用独立模型配置，数据保存在 `dsh-data` 卷的 `/var/lib/dsh`。办公插件已安装在 web profile；截图和 PDF 功能使用镜像内置 Chromium。

## 可选 LiteLLM 网关

```bash
cp configs/litellm_config.yaml.example configs/litellm_config.yaml
# 编辑模板里的 YOUR_INTERNAL_MODEL，替换为实际模型 ID
# 在 docker/.env 中配置 INTERNAL_API_BASE、INTERNAL_API_KEY、LITELLM_MASTER_KEY
./scripts/manage.sh up --llm
```

Windows 使用 `Copy-Item` 复制模板，随后 `.\scripts\manage.ps1 up -Llm`。

| 设置 | 值 |
|------|----|
| 容器内 Base URL | `http://llm-gateway:4000/v1` |
| 外部 HTTPS Base URL | `https://服务器地址:8443/llm/v1` |
| API Key | `docker/.env` 中的 `LITELLM_MASTER_KEY` |
| 模型 ID | `configs/litellm_config.yaml` 中的 `model_name` |

模型配置在各工具中分别保存；管理脚本不再向容器注入某个智能体专用的 API 配置，也不提供旧的 `test-api` 和 `update-config` 命令。

## 更新已有部署

重新构建镜像，执行 `up` 重建 code-server，然后执行 `docker restart dev-gateway` 加载网关配置。启动时会自动卸载旧扩展卷中的 Claude Code、Cline 和 Roo Code 扩展。旧的专用配置卷不再挂载；历史配置和会话数据保留，避免升级误删。

## 故障排除

- Kilo Code 安装失败会中断构建；检查 Open VSX 网络及 code-server 的 VS Code 版本兼容性。
- 插件页面空白或 Service Worker 失败：让浏览器信任 HTTPS 证书，详见 README 的 SSL 配置。
- 模型无法连接：检查该工具中的 Base URL、Key、模型 ID，并确认容器可以访问该地址。
- `/dsh/` 返回 502：先在 IDE 终端运行 `dsh-web`，并保持该终端运行。
- 查看容器日志：`docker logs code-server`、`docker logs dev-gateway`。

## 参考

- [OpenCode](https://opencode.ai/docs/)
- [Kilo Code](https://github.com/Kilo-Org/kilocode)
- [DSH](https://github.com/deepseek-ai/deepseek-harness)
- [Univer Office](https://github.com/dream-num/dsh-univer-office)
- [LiteLLM](https://docs.litellm.ai/docs/proxy/quick_start)
