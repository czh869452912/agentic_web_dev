# Claude Code VS Code 扩展添加完成

## 新增内容

### 1. 预装扩展

Dockerfile.code-server 现在预装以下 AI 编程助手扩展：

| 扩展 | ID | 说明 |
|------|-----|------|
| **Claude Code** | `anthropic.claude-code` | 官方 VS Code 扩展 |
| **Cline** | `saoudrizwan.claude-dev` | 开源备选方案 |

### 2. 离线安装支持

创建了 `configs/vsix/` 目录用于存放 `.vsix` 离线安装包：

```
configs/vsix/
├── README.md                    # 详细安装指南
├── anthropic.claude-code-*.vsix    # Claude Code 官方扩展（需自行下载）
└── saoudrizwan.claude-dev-*.vsix   # Cline 扩展（备选）
```

### 3. Dockerfile 更新

- 在线安装：自动从 Marketplace 安装 `anthropic.claude-code`
- 离线安装：自动检测并安装 `configs/vsix/*.vsix` 文件
- 使用 `|| echo` 确保安装失败不影响构建

### 4. 文档更新

- `README.md` - 添加 AI 插件章节
- `QUICKSTART.md` - 更新插件清单
- `MANIFEST.md` - 更新文件清单
- `configs/vsix/README.md` - 详细的离线安装指南

## Claude Code 扩展功能

- ✅ 原生图形界面，集成在 VS Code 侧边栏
- ✅ 文件编辑建议，内联 diff 显示
- ✅ @-mentions 引用文件或代码行
- ✅ 对话历史保存和多标签页
- ✅ Quick Fix 集成（Ctrl+. 调用 Claude 修复）
- ✅ 支持连接内网 OpenAI 兼容 API

## 使用方式

### 在线环境
```bash
./scripts/manage.sh build
# 会自动从 Marketplace 安装 Claude Code 扩展
```

### 离线环境
1. 在外网下载 `anthropic.claude-code-*.vsix`
2. 放入 `configs/vsix/` 目录
3. 构建镜像时会自动安装

详细步骤见 `configs/vsix/README.md`
