# Agentic 云开发环境 v2.0

内网私有化部署的 AI 驱动嵌入式开发平台。
**版本特性**: 接入内网 OpenAI 兼容 API + 完整软件工程工具链

---

## 🎯 核心特性

| 特性 | 说明 |
|------|------|
| **单端口入口** | 所有服务通过 8443 端口访问 |
| **内网 API 接入** | 支持 OpenAI 兼容格式的内网大模型 API |
| **完整工具链** | 静态检查、代码覆盖率、文档生成、测试框架 |
| **预装 VS Code 插件** | C/C++、嵌入式、Git、代码质量等 15+ 插件 |
| **Web IDE** | 完整的 VS Code 功能 |
| **完全离线** | 支持无互联网环境部署 |

---

## 📁 项目结构

```
agentic-dev-env/
├── README.md
├── QUICKSTART.md
├── CONFIGURATION.md
├── MANIFEST.md
├── docker/
│   ├── docker-compose.yml
│   ├── Dockerfile.code-server      # VS Code + Claude Code 扩展
│   ├── Dockerfile.claude
│   ├── Dockerfile.embedded
│   └── .env.example
├── configs/
│   ├── nginx.conf
│   ├── filebrowser.json
│   ├── settings.json
│   ├── vsix/                       # Claude Code VSIX 离线包
│   │   └── README.md
│   └── ssl/
├── scripts/
│   └── manage.sh
└── workspace/
```

---

## 🚀 快速开始

### 1. 初始化环境

```bash
cd agentic-dev-env
./scripts/manage.sh init
```

### 2. 配置内网 LLM API

```bash
./scripts/manage.sh config
```

或直接编辑 `docker/.env`：

```bash
cp docker/.env.example docker/.env
# 编辑 docker/.env
```

**关键配置项**:
```bash
# 内网 OpenAI 兼容 API 地址
LLM_API_URL=http://10.0.0.100:8000/v1

# API 密钥（如果需要）
LLM_API_KEY=your-api-key

# 模型名称
LLM_MODEL=gpt-4
```

### 3. 测试 API 连接

```bash
./scripts/manage.sh test-api
```

### 4. 构建镜像

```bash
# 在线环境
./scripts/manage.sh pull
./scripts/manage.sh build

# 离线环境
./scripts/manage.sh load
```

### 5. 启动服务

```bash
./scripts/manage.sh up
```

### 6. 访问

- **VS Code**: https://localhost:8443/
- **Claude Code**: https://localhost:8443/claude/
- **文件管理**: https://localhost:8443/files/

---

## 🛠️ 预装软件工程工具链

### 编译工具
- **ARM GCC** 13.2 - ARM 裸机编译
- **arm-linux-gnueabihf-gcc** - ARM Linux 编译
- **aarch64-linux-gnu-gcc** - ARM64 编译
- **Clang/LLVM** - 包含 clang-format, clang-tidy
- **CMake** + **Ninja** - 现代构建系统
- **Meson**, **SCons** - 替代构建工具
- **Conan** - C/C++ 包管理器
- **xmake** - 现代 C/C++ 构建工具

### 代码质量工具
| 工具 | 用途 | 别名 |
|------|------|------|
| **clang-format** | 代码格式化 | `cf` |
| **clang-tidy** | 静态分析 | `ct` |
| **cppcheck** | C/C++ 静态检查 | `cppc` |
| **valgrind** | 内存泄漏检测 | - |
| **splint** | 安全代码检查 | - |

### 代码覆盖率
- **lcov** - GCC 覆盖率工具
- **gcovr** - 覆盖率报告生成（别名 `cov`）

### 测试框架
- **Google Test** - C++ 单元测试
- **CMocka** - C 单元测试
- **Unity Test** - 嵌入式单元测试（预装在 /opt/test-frameworks）

### 文档工具
- **Doxygen** + **Graphviz** - 代码文档生成
- **Sphinx** - Python 风格文档

### 版本控制
- **Git** + **Git LFS** + **tig** + **git-review**

### 调试和模拟
- **GDB Multiarch** - 多架构调试器
- **OpenOCD** - JTAG/SWD 调试
- **QEMU** - ARM/ARM64 模拟器
- **probe-rs** / **cargo-embed** - Rust 嵌入式调试

### Rust 工具链
- **Rust** + **Cargo**
- 目标平台: thumbv7m, thumbv7em, thumbv8m, aarch64-none

---

## 🧩 预装 VS Code 插件

### 🤖 AI 编程助手
| 插件 | 功能 | 备注 |
|------|------|------|
| anthropic.claude-code | **Claude Code 官方扩展** | AI 编程助手，支持内联编辑、对话历史 |
| saoudrizwan.claude-dev | Cline（备选） | 开源 Claude 替代品 |

**Claude Code 扩展功能**:
- 原生图形界面，集成在 VS Code 侧边栏
- 文件编辑建议，内联 diff 显示
- @-mentions 引用文件或代码行
- 对话历史保存和多标签页
- Quick Fix 集成（Ctrl+. 调用 Claude 修复）
- 支持连接内网 OpenAI 兼容 API

**注意**: 离线部署需要预下载 `.vsix` 文件，详见 `configs/vsix/README.md`

### C/C++ 开发
| 插件 | 功能 |
|------|------|
| ms-vscode.cpptools-extension-pack | C/C++ 完整支持 |
| marus25.cortex-debug | ARM Cortex 调试 |
| dan-c-underwood.arm | ARM 汇编支持 |
| zixuanwang.linkerscript | 链接器脚本支持 |
| ms-vscode.cmake-tools | CMake 集成 |
| twxs.cmake | CMake 语法高亮 |

### 代码质量
| 插件 | 功能 |
|------|------|
| jbenden.c-cpp-flylint | 静态分析集成 |
| xaver.clang-format | 代码格式化 |
| notskm.clang-tidy | C++ 代码检查 |
| cschlosser.doxdocgen | 文档生成 |

### Git 和生产力
| 插件 | 功能 |
|------|------|
| eamodio.gitlens | Git 增强 |
| mhutchie.git-graph | Git 可视化 |
| streetsidesoftware.code-spell-checker | 拼写检查 |
| usernamehw.errorlens | 错误高亮 |
| christian-kohler.path-intellisense | 路径补全 |

### 主题
- **Material Icon Theme** - 文件图标
- **Material Theme** - 主题配色

---

## 🔌 API 配置说明

### OpenAI 兼容格式

内网 API 需要支持以下端点：

```
GET  /v1/models          - 列出可用模型
POST /v1/chat/completions - 聊天完成（流式/非流式）
POST /v1/completions     - 文本完成
```

### 请求/响应格式

**请求**:
```json
{
  "model": "gpt-4",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello!"}
  ],
  "stream": false
}
```

**响应**:
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you?"
    }
  }]
}
```

### Claude Code 配置

Claude Code 会自动读取环境变量配置：

```bash
# 查看当前配置
claude config get

# 临时切换模型
claude --model gpt-4-turbo

# 查看支持的命令
claude --help
```

---

## 📖 使用示例

### 嵌入式开发流程

```bash
# 进入开发容器
docker-compose exec embedded-dev bash

# 创建项目
cd /workspace
mkdir stm32-project && cd stm32-project

# 初始化 CMake
cmake -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=arm-none-eabi.cmake

# 格式化代码
clang-format -i src/*.c

# 静态检查
clang-tidy src/main.c --
cppcheck --enable=all --suppress=missingIncludeSystem src/

# 编译
ninja -C build

# 代码覆盖率
# 在测试后运行
gcovr -r . --html --html-details -o coverage.html

# 生成文档
doxygen Doxyfile
```

### 使用 Claude Code

在 VS Code 终端中：

```bash
# 启动交互式会话
claude

# 让 Claude 审查代码
claude review src/main.c

# 让 Claude 生成单元测试
claude test src/calculator.c

# 解释代码
claude explain src/interrupt_handler.c
```

---

## 🔧 管理命令

```bash
# 基础管理
./scripts/manage.sh init          # 初始化配置
./scripts/manage.sh config        # 配置 API
./scripts/manage.sh test-api      # 测试 API
./scripts/manage.sh up            # 启动
./scripts/manage.sh down          # 停止
./scripts/manage.sh status        # 状态
./scripts/manage.sh logs          # 日志

# 调试
./scripts/manage.sh shell embedded-dev   # 进入开发环境
./scripts/manage.sh shell code-server    # 进入 VS Code

# 更新配置（不重启）
./scripts/manage.sh update-config
```

---

## 📦 离线部署

### 准备阶段（外网）

```bash
# 1. 准备环境
./scripts/manage.sh init
./scripts/manage.sh config

# 2. 拉取和构建
./scripts/manage.sh pull
./scripts/manage.sh build

# 3. 导出镜像
./scripts/manage.sh save

# 4. 打包
tar czvf agentic-dev-env-v2.tar.gz agentic-dev-env/ --exclude='workspace/*'
```

### 部署阶段（内网）

```bash
tar xzvf agentic-dev-env-v2.tar.gz
cd agentic-dev-env

# 编辑配置
cp docker/.env.example docker/.env
vim docker/.env  # 设置内网 API

# 加载镜像
./scripts/manage.sh load

# 启动
./scripts/manage.sh up
```

---

## 🔐 安全建议

1. **修改默认密码**
   ```bash
   # 编辑 docker/.env
   CODE_SERVER_PASSWORD=YourStrongPassword
   ```

2. **限制访问 IP**
   ```nginx
   # 在 configs/nginx.conf 中添加
   allow 10.0.0.0/8;
   deny all;
   ```

3. **API Key 管理**
   - 使用只读 API Key
   - 定期轮换
   - 避免提交到版本控制

---

## ⚠️ 故障排除

### API 连接失败

```bash
# 测试连接
./scripts/manage.sh test-api

# 检查网络
curl -v $LLM_API_URL/models

# 检查容器网络
docker exec claude-web curl $LLM_API_URL/models
```

### VS Code 插件不工作

```bash
# 查看日志
docker logs code-server

# 重新安装插件
docker exec code-server code-server --install-extension <ext-id>
```

### 静态检查工具找不到

```bash
# 进入开发容器检查
docker-compose exec embedded-dev which clang-tidy

# 验证环境变量
docker-compose exec embedded-dev echo $PATH
```

---

## 📝 更新日志

### v2.0.0 (2026-03-05)
- 支持内网 OpenAI 兼容 API
- 完整软件工程工具链
- 预装 15+ VS Code 插件
- 新增配置管理脚本

### v1.0.0 (2026-03-05)
- 初始版本
- 基础嵌入式开发环境

---

## 📄 许可证

MIT License - 仅供内部使用
