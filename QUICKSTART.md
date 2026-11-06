# 快速参考手册

完整配置见 [配置指南](CONFIGURATION.md)，全部文档见 [文档导航](docs/README.md)。宿主机命令在仓库根目录执行。

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
./scripts/manage.sh shell code-server    # VS Code + OpenCode / Kilo Code + 嵌入式工具链
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
| DSH 办公（手动启动后，首次使用终端输出的完整地址） | https://3080.localhost:8443/ |
| 文件管理 | https://localhost:8443/files/ |
| LiteLLM 网关（--llm 启用时） | https://localhost:8443/llm/ |
| 健康检查 | https://localhost:8443/health |

默认端口为 8443，修改 `GATEWAY_PORT` 后相应替换地址。自签名证书须在客户端受信任，并包含 IDE 与 DSH 访问域名；仅点击“继续访问”不足以保证扩展可用。见 [HTTPS 指南](docs/https.md)。

---

## AI 工具

- OpenCode：在 IDE 终端运行 `opencode`，配置提供商及模型。
- Kilo Code：打开侧边栏，在 Providers 中配置模型；自建接口可选 OpenAI Compatible。
- DSH + Univer Office：终端运行 `dsh-web`，打开输出的完整登录地址，在 Settings → Models 配置模型。远程部署先在 `.env` 设置 `CODE_SERVER_PROXY_DOMAIN={{port}}.dev.example:8443`，配置对应 DNS/hosts 与证书，再重建 code-server；详见配置指南。
- 可选 LiteLLM：复制并编辑 `configs/litellm_config.yaml.example`，配置 `docker/.env` 的 `INTERNAL_API_BASE`、`INTERNAL_API_KEY`、`LITELLM_MASTER_KEY`，使用 `up --llm`（Windows `up -Llm`）。容器内兼容 API 地址为 `http://llm-gateway:4000/v1`。

详见 [配置指南](CONFIGURATION.md)。升级时重新构建并运行 `up`，再 `docker restart dev-gateway`。旧 AI 扩展会在启动时自动卸载。

更新前确认 [数据持久化范围](CONFIGURATION.md#数据持久化)。普通构建可使用缓存，已有卷中的 Office 也不会自动升级，见 [升级步骤](CONFIGURATION.md#更新已有部署)。

DSH/Office 已在 Linux Chromium 108 与 156 完成基础表格验证，完整 Win7 与其他应用流程尚未验收，见 [兼容性指南](docs/compatibility.md)。

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
esptool --port /dev/ttyUSB0 write-flash 0x0 firmware.bin
esp-flash               # 别名

# ARM 仿真
qemu-arm-static ./arm-binary
qemu-arm                # 别名
qemu-system-arm -machine help  # 查询支持的开发板，按实际机器和固件选择启动参数

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
| AI | `kilocode.kilo-code`（Kilo Code）、OpenCode GUI（可选） |
| C/C++ IntelliSense | `llvm-vs-code-extensions.vscode-clangd` |
| 嵌入式调试 | `marus25.cortex-debug` |
| ARM 汇编 | `dan-c-underwood.arm` |
| 链接脚本 | `zixuanwang.linkerscript` |
| 代码检查 | `jbenden.c-cpp-flylint`、`notskm.clang-tidy` |
| 格式化 | `xaver.clang-format` |
| 文档 | `cschlosser.doxdocgen` |
| 构建 | `ms-vscode.cmake-tools`、`twxs.cmake` |
| Git | `eamodio.gitlens`、`mhutchie.git-graph` |
| 生产力 | `usernamehw.errorlens`、`christian-kohler.path-intellisense`、`pkief.material-icon-theme` |

完整清单和实际安装规则见 [扩展说明](EXTENSIONS.md)。

---

## 常见问题

**Q: 脚本报错 `bad interpreter` 或 `$'\r': command not found`**
A: Windows 编辑器引入了 CRLF 行尾。在 Linux 上运行一键修复：
```bash
./scripts/fix-line-endings.sh
```

**Q: 浏览器显示"无法连接到服务器 (WebSocket 1006)"**
A: nginx 需要使用 `$http_host`（含端口）转发 Host 头，否则 code-server CSRF 检查会拒绝 WebSocket 升级。当前配置已修复此问题，若重新部署请确保 `configs/nginx.conf` 中 code-server 代理块使用 `proxy_set_header Host $http_host;`。

**Q: 构建时 apt-get 出现网络错误**
A: 先查看失败层及其实际软件源。本次基础镜像为 Debian，Chromium 大包安装层已切换到 Debian 官方 HTTPS 源；不要套用 Ubuntu 的源配置。重试前检查容器网络、代理及源可达性。

**Q: DSH 打不开或 Office 资源 404**
A: 保持 `dsh-web` 运行，使用其输出的 forwarding 子域名登录链接，核对 DNS、证书及端口；不使用旧 `/dsh/` 或 `/proxy/3080/`。详见 [DSH 配置](CONFIGURATION.md#dsh--univer-office)。

**Q: 如何离线安装 VS Code 扩展（.vsix）**
A: 将 `.vsix` 文件放入 `configs/vsix/` 目录，重新构建镜像后自动安装。
