# Agentic 云开发环境

内网私有化部署的 AI 驱动嵌入式开发平台。

---

## 核心特性

| 特性 | 说明 |
|------|------|
| **单端口入口** | 所有服务通过 8443 端口（HTTPS）访问 |
| **Claude Code 内置** | Claude Code CLI 与 VS Code 在同一容器，终端直接使用 |
| **嵌入式工具链** | ARM GCC 13.2、clang-tidy、cppcheck、OpenOCD 等内置于 IDE 容器 |
| **完整扩展** | C/C++、Cortex-Debug、CMake、GitLens 等 15+ 插件预装 |
| **Web IDE** | 完整的 VS Code 功能（code-server） |
| **离线友好** | 支持预下载镜像 + VSIX 离线部署 |

---

## 架构

```
浏览器
  │
  └─ HTTPS:8443
       │
    Nginx 网关（单一入口）
       │
       ├── /          →  code-server（VS Code Web）
       │                   ├── Claude Code CLI（claude 命令）
       │                   ├── ARM GCC 13.2 bare-metal 工具链
       │                   ├── clang / clang-format / clang-tidy
       │                   ├── cppcheck / valgrind / lcov / gcovr
       │                   ├── gdb-multiarch / openocd
       │                   └── 15+ VS Code 扩展
       │
       ├── /files/    →  filebrowser（Web 文件管理）
       │
       └── /health    →  健康检查端点
```

`embedded-dev` 容器提供完整重型工具链（QEMU、Unity Test、Rust 嵌入式、probe-rs 等），与 code-server 共享 `/workspace` 卷，可通过 `docker exec embedded-dev <cmd>` 访问。

---

## 项目结构

```
agentic_web_dev/
├── .gitattributes                  # 强制 .sh 文件使用 LF 行尾
├── docker/
│   ├── docker-compose.yml
│   ├── Dockerfile.code-server      # VS Code + Claude Code + 嵌入式工具
│   ├── Dockerfile.embedded         # 完整重型工具链（QEMU、Rust 等）
│   └── .env.example
├── configs/
│   ├── nginx.conf
│   ├── filebrowser.json
│   ├── settings.json               # VS Code 默认设置
│   ├── ssl/                        # SSL 证书（自动生成）
│   └── vsix/                       # 离线 VSIX 安装包目录
│       └── README.md
├── scripts/
│   ├── manage.sh                   # Linux/macOS 管理脚本
│   ├── manage.ps1                  # Windows PowerShell 管理脚本
│   └── code-server-entrypoint.sh  # code-server 容器启动脚本
└── workspace/                      # 代码工作区（挂载卷）
```

---

## 快速开始

### Linux / macOS

```bash
# 1. 初始化
./scripts/manage.sh init

# 2. 编辑 docker/.env 配置 API（见下方说明）

# 3. 构建镜像（需要网络）
./scripts/manage.sh pull
./scripts/manage.sh build

# 4. 启动（自动生成 SSL 证书）
./scripts/manage.sh up
```

### Windows (PowerShell)

```powershell
# 1. 初始化
.\scripts\manage.ps1 init

# 2. 编辑 docker\.env 配置 API

# 3. 构建
.\scripts\manage.ps1 pull
.\scripts\manage.ps1 build

# 4. 启动
.\scripts\manage.ps1 up
```

### 访问

| 服务 | 地址 |
|------|------|
| VS Code + Claude Code | https://localhost:8443/ |
| 文件管理 | https://localhost:8443/files/ |

默认密码：`docker/.env` 中的 `CODE_SERVER_PASSWORD`（默认 `changeme`）

---

## API 配置

Claude Code CLI 使用 **Anthropic API 协议**（非 OpenAI 兼容格式）。编辑 `docker/.env`：

### 方案 A：使用 Anthropic 官方 API

```bash
ANTHROPIC_API_KEY=sk-ant-api03-...
ANTHROPIC_BASE_URL=          # 留空，使用默认
```

### 方案 B：使用内网 Anthropic 格式代理

内网代理必须实现 Anthropic 消息协议（`POST /v1/messages`），而非 OpenAI 的 `/v1/chat/completions`。

```bash
ANTHROPIC_API_KEY=your-proxy-key
ANTHROPIC_BASE_URL=http://10.0.0.100:8000
```

### 方案 C：不预配置（交互式登录）

不填任何 API 配置，启动后在 VS Code 终端执行 `claude`，按提示完成认证。

---

## 使用 Claude Code

启动后在 VS Code 集成终端（Ctrl+` 打开）中：

```bash
# 启动交互式会话
claude

# 让 Claude 审查/编辑文件
claude src/main.c

# 查看当前配置
claude config get

# 切换模型
claude config set model claude-opus-4-5
```

Claude Code VS Code 扩展（`anthropic.claude-code`）也已预装，提供侧边栏 UI。

---

## 嵌入式开发工具速查

以下工具在 code-server 容器的终端中直接可用：

```bash
# 编译（ARM bare-metal）
arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -o fw.elf main.c
arm-gcc main.c    # 别名

# 代码格式化
clang-format -i src/*.c
cf src/*.c         # 别名

# 静态分析
clang-tidy src/main.c --
ct src/main.c --   # 别名
cppcheck --enable=all src/
cppc src/          # 别名

# 内存分析（x86 测试程序）
valgrind --leak-check=full ./test

# 代码覆盖率
gcovr -r . --html --html-details -o coverage.html
cov                # 别名

# 文档生成
doxygen Doxyfile

# 固件调试（通过 JTAG/SWD 连接）
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg

# 查看 ELF 信息
arm-none-eabi-size firmware.elf
arm-none-eabi-objdump -d firmware.elf
arm-size firmware.elf   # 别名
```

重型工具（QEMU、Unity Test、Rust 嵌入式）在 embedded-dev 容器：

```bash
docker exec -it embedded-dev bash
qemu-system-arm -M stm32-p103 -kernel firmware.elf
```

---

## 预装 VS Code 扩展

### AI 编程助手
| 扩展 | ID |
|------|-----|
| Claude Code | `anthropic.claude-code` |
| Cline（备选） | `saoudrizwan.claude-dev` |

### C/C++ 开发
| 扩展 | ID |
|------|-----|
| C/C++ Extension Pack | `ms-vscode.cpptools-extension-pack` |
| Cortex-Debug | `marus25.cortex-debug` |
| ARM 汇编 | `dan-c-underwood.arm` |
| 链接器脚本 | `zixuanwang.linkerscript` |
| CMake Tools | `ms-vscode.cmake-tools` |
| CMake 语法 | `twxs.cmake` |

### 代码质量
| 扩展 | ID |
|------|-----|
| C/C++ Flylint | `jbenden.c-cpp-flylint` |
| clang-format | `xaver.clang-format` |
| clang-tidy | `notskm.clang-tidy` |
| Doxygen Generator | `cschlosser.doxdocgen` |

### Git 和生产力
| 扩展 | ID |
|------|-----|
| GitLens | `eamodio.gitlens` |
| Git Graph | `mhutchie.git-graph` |
| Error Lens | `usernamehw.errorlens` |
| Path Intellisense | `christian-kohler.path-intellisense` |
| Code Spell Checker | `streetsidesoftware.code-spell-checker` |
| Material Icon Theme | `pkief.material-icon-theme` |

---

## 管理命令

### Linux/macOS (`manage.sh`)

```bash
./scripts/manage.sh init          # 初始化 .env
./scripts/manage.sh ssl           # 生成 SSL 证书（up 时自动执行）
./scripts/manage.sh pull          # 拉取基础镜像
./scripts/manage.sh build         # 构建自定义镜像
./scripts/manage.sh up            # 启动服务
./scripts/manage.sh down          # 停止服务
./scripts/manage.sh status        # 查看状态
./scripts/manage.sh logs          # 查看所有日志
./scripts/manage.sh logs code-server  # 查看指定服务日志
./scripts/manage.sh shell code-server     # 进入 VS Code 容器
./scripts/manage.sh shell embedded-dev    # 进入嵌入式工具链容器
./scripts/manage.sh save          # 导出镜像（离线部署用）
./scripts/manage.sh load          # 加载镜像
```

### Windows (`manage.ps1`)

```powershell
.\scripts\manage.ps1 <命令> [参数]
# 命令与 manage.sh 相同
```

---

## 离线部署

### 准备（有网络环境）

```bash
./scripts/manage.sh pull
./scripts/manage.sh build
./scripts/manage.sh save         # 导出到 images/

# 可选：预下载 VSIX 扩展放入 configs/vsix/

tar czvf agentic-dev-env.tar.gz agentic_web_dev/ --exclude='workspace/*' --exclude='images/*.tar'
# 单独打包镜像（较大）
tar czvf images.tar.gz agentic_web_dev/images/
```

### 部署（内网）

```bash
tar xzvf agentic-dev-env.tar.gz
cd agentic_web_dev
cp docker/.env.example docker/.env
# 编辑 docker/.env 填入内网 API 配置

./scripts/manage.sh load
./scripts/manage.sh up
```

---

## 故障排除

### Claude Code 无法连接 API

```bash
# 进入 code-server 容器检查
docker exec -it code-server bash
claude config get

# 检查环境变量是否注入
echo $ANTHROPIC_API_KEY
echo $ANTHROPIC_BASE_URL
```

### VS Code 扩展不工作

```bash
# 查看 code-server 日志
docker logs code-server

# 手动安装扩展
docker exec code-server code-server --install-extension <ext-id>
```

### ARM 工具链找不到

```bash
# 确认 PATH
docker exec code-server bash -c "echo $PATH"
docker exec code-server which arm-none-eabi-gcc
```

### 容器启动失败

```bash
# 检查 SSL 证书是否存在
ls configs/ssl/
# 如果不存在，重新生成
./scripts/manage.sh ssl

# 检查日志
docker logs dev-gateway
```

---

## 安全建议

1. **修改默认密码**：编辑 `docker/.env` 中的 `CODE_SERVER_PASSWORD`
2. **API Key 保护**：`.env` 文件已在 `.gitignore` 中，不要手动提交
3. **IP 白名单**（可选）：在 `configs/nginx.conf` 的 server 块中添加
   ```nginx
   allow 10.0.0.0/8;
   deny all;
   ```

---

## 更新日志

### v3.0.0 (2026-03-06)
- Claude Code CLI 与 code-server 合并为单一容器，终端直接使用 `claude`
- ARM GCC 13.2 / clang / cppcheck / openocd 内置于 IDE 容器
- 移除独立 claude-web 服务（原为无功能静态页）
- 新增 Windows PowerShell 管理脚本 `scripts/manage.ps1`
- 修复 nginx 健康检查端口、build context 路径等问题
- 新增 `.gitattributes` 防止 Windows CRLF 破坏 Linux 脚本

### v2.0.0 (2026-03-05)
- 支持内网 OpenAI 兼容 API
- 预装 15+ VS Code 插件

### v1.0.0 (2026-03-05)
- 初始版本
