# VSIX 离线扩展

将需要的 `.vsix` 放在本目录，构建镜像时会安装到扩展 seed 目录，启动时同步到持久化扩展卷。

当前 AI 扩展：

| 扩展 ID | 用途 |
|---------|------|
| `kilocode.kilo-code` | Kilo Code；默认从 Open VSX 安装 |
| `TanishqKancharla.opencode-vscode` | 保留的 OpenCode GUI；在线不可用时可放入 VSIX |

下载与目标容器 Linux 架构及 code-server 内嵌 VS Code 版本兼容的 VSIX。在可联网环境完成整个镜像构建，再导出镜像供离线部署；本目录不会让其他联网构建步骤自动变成离线步骤。

运行中的容器也可手动安装：

```bash
docker cp my-extension.vsix code-server:/tmp/my-extension.vsix
docker exec code-server code-server --extensions-dir /home/coder/.local/share/code-server/extensions --install-extension /tmp/my-extension.vsix
```

不要放入已退役的 Claude Code、Cline 或 Roo Code VSIX；容器启动时会卸载这些扩展。
