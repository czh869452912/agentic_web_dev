# VS Code 扩展说明

## 预装扩展列表

构建时通过 `code-server --install-extension` 自动安装以下扩展（均使用 `|| true` 保护，单个失败不中断构建）：

### AI 编程助手

| 扩展 ID | 名称 | 说明 |
|---------|------|------|
| `anthropic.claude-code` | Claude Code | Anthropic 官方扩展；Open VSX 状态不稳定，建议通过 VSIX 安装 |
| `saoudrizwan.claude-dev` | Cline | 支持 Claude API 的开源 AI 编程助手，提供侧边栏 UI |
| `RooVeterinaryInc.roo-cline` | Roo Code | 多模式 AI 助手（Code / Architect / Ask 模式），Open VSX 可用 |
| `TanishqKancharla.opencode-vscode` | opencode GUI | opencode CLI 的 VS Code 图形界面；**VSIX only**，不在 Open VSX |

> **opencode CLI**：容器内已预装 `opencode` 命令（`npm install -g opencode-ai`）。GUI 扩展需将 VSIX 放入 `configs/vsix/` 后重新构建。

### 嵌入式 / C/C++ 开发

| 扩展 ID | 名称 |
|---------|------|
| `llvm-vs-code-extensions.vscode-clangd` | C/C++ IntelliSense（基于 clangd，Open VSX 可用） |
| `marus25.cortex-debug` | ARM Cortex-M 调试（配合 OpenOCD/JLink） |
| `dan-c-underwood.arm` | ARM 汇编语法高亮 |
| `zixuanwang.linkerscript` | 链接器脚本（.ld）语法支持 |
| `ms-vscode.cmake-tools` | CMake 项目支持（MS-only，Open VSX 不可用，会跳过） |
| `twxs.cmake` | CMake 语法高亮 |

> **说明**：`ms-vscode.cpptools-extension-pack` 和 `ms-vscode.cmake-tools` 是微软专有插件，不发布到 Open VSX Registry，code-server 无法从 marketplace 安装。C/C++ IntelliSense 由 `vscode-clangd` 提供（容器内已预装 clangd 二进制）。如需完整 cpptools，可将 VSIX 放入 `configs/vsix/` 目录后重新构建。

### 测试与覆盖率

| 扩展 ID | 名称 | 说明 |
|---------|------|------|
| `ryanluker.vscode-coverage-gutters` | Coverage Gutters | 内联显示 lcov/gcovr 覆盖率（行级高亮） |
| `hbenl.vscode-test-explorer` | Test Explorer UI | 统一测试运行侧边栏 |

> **C/C++ 测试工具**：容器内预装 `check`（libcheck）、`libcmocka-dev`、`libcunit1-dev`、`ceedling`（含 Unity/CMock）、Google Test（从 `libgtest-dev` 源码编译安装，`/usr/local/lib/libgtest*`）。

### 代码质量

| 扩展 ID | 名称 |
|---------|------|
| `jbenden.c-cpp-flylint` | 集成 clang-tidy、cppcheck、splint 等静态分析 |
| `xaver.clang-format` | clang-format 代码格式化 |
| `notskm.clang-tidy` | clang-tidy 检查提示 |
| `cschlosser.doxdocgen` | Doxygen 注释生成 |

### Git 和版本控制

| 扩展 ID | 名称 |
|---------|------|
| `eamodio.gitlens` | Git 增强（行级 blame、历史等） |
| `mhutchie.git-graph` | 可视化 Git 分支图 |

### 图表与文档

| 扩展 ID | 名称 | 说明 |
|---------|------|------|
| `jebbs.plantuml` | PlantUML | 渲染 PlantUML 图表（需容器内 `plantuml` + JRE，已预装） |
| `bierner.markdown-mermaid` | Markdown Mermaid | Markdown 预览中渲染 Mermaid 图表 |
| `yzhang.markdown-all-in-one` | Markdown All in One | TOC、快捷键、预览增强 |

> **需求管理**：容器内预装 `doorstop` CLI（`pip3 install doorstop`），用于基于文本文件的需求追踪。`pandoc` 已预装，可将需求导出为 PDF/HTML/Word。

### 生产力

| 扩展 ID | 名称 |
|---------|------|
| `usernamehw.errorlens` | 错误/警告内联显示 |
| `christian-kohler.path-intellisense` | 文件路径自动补全 |
| `streetsidesoftware.code-spell-checker` | 英文拼写检查 |
| `pkief.material-icon-theme` | 文件图标主题 |
| `Gruntfuggly.todo-tree` | TODO/FIXME 注释搜索与高亮 |

---

## 离线安装扩展

在无法访问 VS Code Marketplace 的内网环境中，需要预先下载 `.vsix` 文件。

### 步骤

1. **在外网下载 VSIX**

   从 VS Code Marketplace 网站下载：
   ```
   https://marketplace.visualstudio.com/items?itemName=<扩展ID>
   ```
   点击页面中的 "Download Extension" 链接。

   或通过命令行：
   ```bash
   # 示例：下载 C/C++ 扩展包（需替换实际版本号）
   wget "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/cpptools/latest/vspackage" \
     -O ms-vscode.cpptools.vsix
   ```

2. **放入 configs/vsix/ 目录**

   ```
   configs/vsix/
   ├── ms-vscode.cpptools-1.x.x.vsix
   └── ms-vscode.cpptools-extension-pack-x.x.x.vsix
   ```

3. **构建时自动安装**

   Dockerfile 会自动检测并安装该目录下所有 `.vsix` 文件。

### 在运行中的容器里手动安装

```bash
# 将 VSIX 文件复制到容器
docker cp my-extension.vsix code-server:/tmp/

# 在容器内安装
docker exec code-server code-server --install-extension /tmp/my-extension.vsix

# 刷新浏览器即可看到新扩展
```

---

## 扩展配置

### Claude Code 扩展连接内网 API

Claude Code VS Code 扩展遵循与 CLI 相同的配置，通过容器环境变量自动注入：

- `ANTHROPIC_API_KEY` → API 密钥
- `ANTHROPIC_BASE_URL` → API 基础地址（内网代理）

在 VS Code 设置中也可手动配置（`settings.json`）。

### Cortex-Debug 配置示例

在 `.vscode/launch.json` 中：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug STM32",
      "type": "cortex-debug",
      "request": "launch",
      "servertype": "openocd",
      "gdbPath": "arm-none-eabi-gdb",
      "device": "STM32F407VG",
      "configFiles": [
        "interface/stlink.cfg",
        "target/stm32f4x.cfg"
      ],
      "executable": "${workspaceFolder}/build/firmware.elf",
      "runToEntryPoint": "main"
    }
  ]
}
```

### C/C++ IntelliSense 配置（clangd）

clangd 通过 `compile_commands.json` 自动感知编译参数。CMake 项目生成方式：

```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json compile_commands.json
```

如需覆盖特定选项，在项目根目录创建 `.clangd`：

```yaml
CompileFlags:
  Add:
    - "--target=arm-none-eabi"
    - "-I/opt/toolchains/arm-none-eabi/arm-none-eabi/include"
```
