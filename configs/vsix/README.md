# Claude Code VS Code 扩展离线安装指南

## 扩展信息

| 属性 | 值 |
|------|-----|
| **扩展名称** | Claude Code |
| **发布者** | Anthropic |
| **扩展 ID** | `anthropic.claude-code` |
| **官方文档** | https://code.claude.com/docs/en/vs-code |

---

## 在线安装（推荐，有网络环境）

Dockerfile 已配置自动安装：

```dockerfile
RUN code-server --install-extension anthropic.claude-code
```

如果安装失败，会自动跳过并继续构建。

---

## 离线安装（内网环境）

### 方法一：从 VS Code Marketplace 下载 VSIX（推荐）

#### 步骤 1：在外网下载 VSIX 文件

**方式 A：通过 Marketplace 网站**

1. 访问 https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code
2. 点击 "Download Extension" 链接
3. 保存 `.vsix` 文件

**方式 B：使用命令行下载**

```bash
# 获取最新版本（需要替换为实际版本号）
# 格式：https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{name}/{version}/vspackage

# 示例（版本号需要替换为实际版本）
wget --content-disposition \
  'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anthropic/vsextensions/claude-code/1.0.0/vspackage'
```

**方式 C：从已安装的 VS Code 导出**

如果你有已安装 Claude Code 扩展的 VS Code：

```bash
# 找到扩展目录（路径因系统而异）
# macOS: ~/.vscode/extensions/
# Linux: ~/.vscode/extensions/
# Windows: %USERPROFILE%\.vscode\extensions\

# 打包为 VSIX
cd ~/.vscode/extensions/anthropic.claude-code-*/
npm install -g vsce  # 如果未安装
vsce package

# 生成的 .vsix 文件在当前目录
```

#### 步骤 2：放置 VSIX 文件

将下载的 `.vsix` 文件复制到：

```
agentic-dev-env/configs/vsix/
```

例如：
```
configs/vsix/
├── anthropic.claude-code-1.0.0.vsix    # Claude Code 官方扩展
└── saoudrizwan.claude-dev-3.0.0.vsix   # Cline（备选）
```

#### 步骤 3：修改 Dockerfile

确保 Dockerfile 包含以下行（已添加）：

```dockerfile
# 离线安装 VSIX 插件（如果存在）
COPY configs/vsix/*.vsix /tmp/vsix/ 2>/dev/null || true
RUN if [ -d "/tmp/vsix" ]; then \
    for vsix in /tmp/vsix/*.vsix; do \
        [ -f "$vsix" ] && code-server --install-extension "$vsix" || true; \
    done; \
fi
```

#### 步骤 4：重新构建镜像

```bash
./scripts/manage.sh build
```

---

### 方法二：手动在容器中安装（已部署环境）

如果容器已经运行，可以手动安装：

```bash
# 1. 将 VSIX 文件复制到容器
docker cp anthropic.claude-code-1.0.0.vsix code-server:/tmp/

# 2. 进入容器安装
docker exec code-server code-server --install-extension /tmp/anthropic.claude-code-1.0.0.vsix

# 3. 重启 code-server 服务
docker restart code-server
```

---

### 方法三：通过 Code Server Web 界面安装

1. 打开 Code Server Web 界面
2. 点击左侧 Extensions 图标
3. 点击右上角 "..." 菜单
4. 选择 "Install from VSIX..."
5. 上传 `.vsix` 文件

---

## 备选方案：Cline 扩展

如果无法获取 Claude Code 官方扩展，可以使用 **Cline**（开源替代方案）：

| 属性 | 值 |
|------|-----|
| **扩展名称** | Cline (prev. Claude Dev) |
| **发布者** | saoudrizwan |
| **扩展 ID** | `saoudrizwan.claude-dev` |
| **特点** | 支持 Claude API，功能类似 |

下载地址：
- https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev

---

## 扩展功能说明

Claude Code VS Code 扩展提供：

1. **原生图形界面** - 在 VS Code 中直接聊天
2. **文件编辑建议** - 内联 diff 显示修改
3. **@-mentions** - 引用文件或代码行
4. **对话历史** - 保存和恢复对话
5. **多标签页** - 同时打开多个对话
6. **权限模式** - Normal / Plan / Auto-accept
7. **Quick Fix 集成** - Ctrl+. 调用 Claude 修复错误

---

## 配置说明

### 连接到内网 API

Claude Code 扩展默认连接 Anthropic 官方 API，需要配置为使用内网 API：

**方式 1：通过 VS Code 设置**

```json
// settings.json
{
  "claude.apiUrl": "http://your-internal-llm:8000/v1",
  "claude.apiKey": "your-api-key",
  "claude.model": "gpt-4"
}
```

**方式 2：通过环境变量**（已配置）

Dockerfile 已配置自动从环境变量读取：
- `LLM_API_URL`
- `LLM_API_KEY`
- `LLM_MODEL`

---

## 故障排除

### 扩展安装失败

```bash
# 检查日志
docker logs code-server | grep -i extension

# 手动安装查看错误
docker exec code-server code-server --install-extension /path/to/extension.vsix --verbose
```

### 扩展无法连接 API

1. 检查 API URL 是否正确配置
2. 确认内网 API 可访问：
   ```bash
   docker exec code-server curl $LLM_API_URL/models
   ```
3. 查看 Claude Code 输出面板中的错误信息

### 扩展界面不显示

1. 刷新浏览器
2. 检查扩展是否启用：Extensions → Claude Code → Enable
3. 查看浏览器控制台错误

---

## 相关链接

- [官方文档](https://code.claude.com/docs/en/vs-code)
- [Marketplace 页面](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code)
- [Cline 替代方案](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev)
