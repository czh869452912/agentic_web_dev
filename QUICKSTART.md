# 快速参考手册

## 常用命令

### Linux/macOS
```bash
# 首次使用
./scripts/manage.sh init
./scripts/manage.sh build
./scripts/manage.sh up

# 日常管理
./scripts/manage.sh status
./scripts/manage.sh logs [服务名]
./scripts/manage.sh down

# 进入容器
./scripts/manage.sh shell code-server    # VS Code + Claude Code + 嵌入式工具链
```

### Windows (PowerShell)
```powershell
.\scripts\manage.ps1 init
.\scripts\manage.ps1 build
.\scripts\manage.ps1 up
.\scripts\manage.ps1 shell code-server
```

---

## 访问地址

| 服务 | 地址 |
|------|------|
| VS Code Web | https://localhost:8443/ |
| 文件管理 | https://localhost:8443/files/ |
| LiteLLM 网关（--llm 启用时） | https://localhost:8443/llm/ |
| 健康检查 | https://localhost:8443/health |

> 使用自签名证书，浏览器会提示不安全，点击"高级 → 继续访问"即可。

---

## API 配置 (docker/.env)

```bash
# 方案 A：Anthropic 官方 API
ANTHROPIC_API_KEY=sk-ant-api03-...

# 方案 B：内网代理（须实现 Anthropic /v1/messages 协议）
ANTHROPIC_API_KEY=your-key
ANTHROPIC_BASE_URL=http://10.0.0.100:8000

# 方案 C：LiteLLM 统一网关（内网 OpenAI 兼容 API）
# cp configs/litellm_config.yaml.example configs/litellm_config.yaml  # 编辑后
# ./scripts/manage.sh up --llm
ANTHROPIC_BASE_URL=http://llm-gateway:4000
ANTHROPIC_API_KEY=sk-devenv   # 与 LITELLM_MASTER_KEY 一致

# 方案 D：不填则启动后交互式登录（在 VS Code 终端运行 claude 命令）
```

---

## Claude Code 用法（在 VS Code 终端中运行）

> Claude Code 以 CLI 形式集成，在 VS Code 内置终端直接使用。

```bash
# 首次使用：交互式登录
claude

# 启动对话
claude

# 直接处理单个文件
claude src/main.c

# 查看/修改配置
claude config get
claude config set model claude-sonnet-4-6

# 验证安装
claude --version
```

---

## 嵌入式开发工具速查

> 以下命令在 **code-server 终端**中直接可用（已配置 PATH 和别名）。

```bash
# ARM bare-metal 编译（arm-none-eabi-gcc 13.2）
arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -o fw.elf main.c
arm-gcc main.c          # 别名

# ARM Linux 交叉编译
arm-linux-gnueabihf-gcc -o app main.c
aarch64-linux-gnu-gcc -o app main.c

# 代码格式化
clang-format -i *.c
cf *.c                  # 别名

# 静态检查
clang-tidy src/main.c --
ct src/main.c --        # 别名
cppcheck --enable=all src/
cppc src/               # 别名

# 内存分析
valgrind --leak-check=full ./test

# 代码覆盖率
gcovr -r . --html --html-details -o coverage.html
cov                     # 别名

# ELF 分析
arm-none-eabi-size firmware.elf
arm-size firmware.elf   # 别名
arm-none-eabi-objdump -d firmware.elf
arm-objdump firmware.elf  # 别名

# 文档生成
doxygen Doxyfile

# 固件调试
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg
flash-openocd           # 别名
pyocd list              # 列出调试器
flash-pyocd             # 别名

# ESP32/ESP8266 烧录
esptool.py --port /dev/ttyUSB0 write_flash 0x0 firmware.bin
esp-flash               # 别名

# ARM 仿真
qemu-arm-static ./arm-binary
qemu-arm                # 别名
qemu-system-arm -M stm32-p103 -kernel firmware.elf

# API 文档
sphinx-quickstart && sphinx-build -b html docs/ docs/_build/
sphinx-init             # 别名

# 构建系统 / 包管理
scons
conan install .
```

---

## 预装 VS Code 扩展

| 类别 | 扩展 |
|------|------|
| AI | `saoudrizwan.claude-dev`（Cline，可调用 Claude API） |
| 嵌入式调试 | `marus25.cortex-debug` |
| ARM 汇编 | `dan-c-underwood.arm` |
| 链接脚本 | `zixuanwang.linkerscript` |
| 代码检查 | `jbenden.c-cpp-flylint`、`notskm.clang-tidy` |
| 格式化 | `xaver.clang-format` |
| 文档 | `cschlosser.doxdocgen` |
| 构建 | `ms-vscode.cmake-tools`、`twxs.cmake` |
| Git | `eamodio.gitlens`、`mhutchie.git-graph` |
| 生产力 | `usernamehw.errorlens`、`christian-kohler.path-intellisense`、`pkief.material-icon-theme` |

> **注意**：`anthropic.claude-code` 官方扩展与当前 code-server 版本不兼容，Claude Code 通过 CLI（`claude` 命令）使用。

---

## 常见问题

**Q: 浏览器显示"无法连接到服务器 (WebSocket 1006)"**
A: nginx 需要使用 `$http_host`（含端口）转发 Host 头，否则 code-server CSRF 检查会拒绝 WebSocket 升级。当前配置已修复此问题，若重新部署请确保 `configs/nginx.conf` 中 code-server 代理块使用 `proxy_set_header Host $http_host;`。

**Q: 构建时 apt-get 出现网络错误**
A: 国内环境下 `archive.ubuntu.com` 可能无法访问。Dockerfile 已切换至阿里云镜像（HTTP），如仍失败可改用 `http://mirrors.tuna.tsinghua.edu.cn/ubuntu`。

**Q: 如何离线安装 VS Code 扩展（.vsix）**
A: 将 `.vsix` 文件放入 `configs/vsix/` 目录，重新构建镜像后自动安装。
