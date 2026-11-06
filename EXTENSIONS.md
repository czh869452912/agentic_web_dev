# VS Code 扩展说明

## 预装扩展列表

以下为 Dockerfile 配置的安装清单，构建时通过 Open VSX 尝试安装。Kilo Code 必须安装成功，其他可选扩展安装失败可跳过。实际版本以构建日志和扩展管理器为准；2026-11-06 的镜像快照见 [兼容性指南](docs/compatibility.md#构建结果)。

### AI 编程助手

| 扩展 ID | 名称 | 说明 |
|---------|------|------|
| `kilocode.kilo-code` | Kilo Code | 核心 IDE 编程智能体，通过 Open VSX 安装 |
| `TanishqKancharla.opencode-vscode` | OpenCode GUI | 在线尝试安装；不可用时通过 VSIX 安装，本次镜像已在线安装 0.4.4 |

> OpenCode CLI 通过 npm 单独安装，命令为 `opencode`。DSH 和 Univer Office 也已内置，但 Office 是 DSH web profile 插件，不是 VS Code 扩展。

### 嵌入式 / C/C++ 开发

| 扩展 ID | 名称 |
|---------|------|
| `llvm-vs-code-extensions.vscode-clangd` | C/C++ IntelliSense（基于 clangd，Open VSX 可用） |
| `marus25.cortex-debug` | ARM Cortex-M 调试（配合 OpenOCD/JLink） |
| `dan-c-underwood.arm` | ARM 汇编语法高亮 |
| `zixuanwang.linkerscript` | 链接器脚本（.ld）语法支持 |
| `ms-vscode.cmake-tools` | CMake 项目支持；本次镜像已在线安装 1.24.42 |
| `twxs.cmake` | CMake 语法高亮 |

> C/C++ IntelliSense 使用 `vscode-clangd`，容器内已安装 clangd 二进制。`cpptools` 及其扩展包不在默认清单中；额外 VSIX 应确认与 code-server、容器架构及其使用条件兼容。在线可用性以实际构建结果为准。

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

> 容器内预装 `doorstop`，用于基于文本文件的需求追踪。Python 工具在 `/opt/dev-python` 虚拟环境中，已加入 PATH。`pandoc` 也已预装，具体导出格式仍取决于相应渲染依赖。

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

联网构建后的镜像已含成功安装的扩展，运行时不需重新下载。需要补充或覆盖扩展时，预先下载匹配目标容器架构和内置 Code 版本的 `.vsix`；构建与运行时安装步骤见 [VSIX 指南](configs/vsix/README.md)。

## seed 与已有数据卷

扩展构建时安装到 `/opt/code-server-extensions-seed`；启动时合并到 `/home/coder/.local/share/code-server/extensions` 的持久化卷。合并不覆盖已存在的文件，不能据此认定运行中的扩展已全部更新。

核对运行时版本：

```bash
docker exec code-server code-server --extensions-dir /home/coder/.local/share/code-server/extensions --list-extensions --show-versions
```

启动时通过扩展管理器卸载旧数据卷中的 Claude Code、Cline、Roo Code 扩展，不删除其历史设置。用户设置的持久化范围和重建前备份见 [配置指南](CONFIGURATION.md#数据持久化)。

DSH 的兼容注入不进入 Kilo 或其他扩展网页视图。扩展安装成功不代表 Chromium 108/Win7 的模型、工具和 diff 流程已经验收，见 [兼容性边界](docs/compatibility.md#尚未覆盖)。

---

## 扩展配置

### Kilo Code 连接模型

在扩展的 Providers 页面配置提供商、Key 和模型。自建 Chat Completions 接口选择 OpenAI Compatible。启用 LiteLLM 后，容器内地址为 `http://llm-gateway:4000/v1`，Key 为 `.env` 的 `LITELLM_MASTER_KEY`。详见 [配置指南](CONFIGURATION.md)。

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
