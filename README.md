# Agentic 云开发环境

内网私有化部署的 AI 驱动嵌入式开发平台。

---

## 核心特性

| 特性 | 说明 |
|------|------|
| **单端口入口** | 所有服务通过 8443 端口（HTTPS）访问 |
| **OpenCode + Kilo Code** | OpenCode CLI 与 Kilo Code IDE 扩展内置于开发容器 |
| **DSH + Univer Office** | 预装 DeepSeek Harness 与办公插件，支持表格、文档、演示文稿及预览 |
| **嵌入式工具链** | ARM GCC 13.2、clang-tidy、cppcheck、OpenOCD 等内置于 IDE 容器 |
| **完整扩展** | Cortex-Debug、CMake、GitLens、Kilo Code 等 13+ 插件预装 |
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
       │                   ├── OpenCode CLI + Kilo Code 扩展
       │                   ├── ARM GCC 13.2 bare-metal 工具链
       │                   ├── clang / clang-format / clang-tidy / clangd
       │                   ├── cppcheck / valgrind / lcov / gcovr
       │                   ├── gdb-multiarch / openocd / stlink-tools
       │                   ├── QEMU (qemu-arm-static / qemu-system-arm)
       │                   ├── pyocd / esptool / conan / scons
       │                   ├── Sphinx / Breathe（API 文档生成）
       │                   ├── Google Test / Ceedling（C/C++ 单元测试）
       │                   └── 13+ VS Code 扩展
       │
       ├── /dsh/     →  DSH + Univer Office（在 IDE 终端运行 dsh-web）
       │
       ├── /files/    →  filebrowser（Web 文件管理）
       │
       ├── /llm/      →  LiteLLM 统一 LLM 网关（可选，--llm 启用）
       │                   ├── Anthropic 格式（/v1/messages）
       │                   └── OpenAI 格式（/v1/chat/completions）
       │
       └── /health    →  健康检查端点
```

---

## 项目结构

```
agentic_web_dev/
├── .gitattributes                  # 强制 .sh 文件使用 LF 行尾
├── docker/
│   ├── docker-compose.yml
│   ├── Dockerfile.code-server      # VS Code + OpenCode / Kilo Code + 完整嵌入式工具链
│   └── .env.example
├── configs/
│   ├── nginx.conf
│   ├── filebrowser.json
│   ├── settings.json                    # VS Code 默认设置
│   ├── litellm_config.yaml.example      # LiteLLM 配置模板
│   ├── ssl/                             # SSL 证书（自动生成）
│   └── vsix/                            # 离线 VSIX 安装包目录
│       └── README.md
├── scripts/
│   ├── manage.sh                   # Linux/macOS 管理脚本
│   ├── manage.ps1                  # Windows PowerShell 管理脚本
│   ├── code-server-entrypoint.sh  # code-server 容器启动脚本
│   ├── fix-line-endings.sh        # 清理 CRLF/BOM（跨平台编辑后运行）
│   └── test-docker-build.sh       # 镜像构建测试脚本
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
| VS Code + OpenCode / Kilo Code | https://localhost:8443/ |
| 文件管理 | https://localhost:8443/files/ |
| DSH + Univer Office（运行 `dsh-web` 后） | https://localhost:8443/dsh/（首次使用终端输出的完整登录地址） |
| LiteLLM 网关（--llm 启用时） | https://localhost:8443/llm/ |

默认密码：`docker/.env` 中的 `CODE_SERVER_PASSWORD`（默认 `changeme`）

---

## 使用 DSH + Univer Office

开发镜像预装 `@deepseek-ai/dsh@0.2.1-rc.3` 和 `dsh-univer-office@0.4.0`，插件安装在 DSH 的 `web` profile 中。Node.js 升级至 24，并安装 Chromium 和中文字体，用于插件截图、PDF 打印及幻灯片布局检查。这是 DSH 插件，无需安装 VSIX。

已有部署需要先重新构建镜像并重建 code-server 容器：

```bash
./scripts/manage.sh build
./scripts/manage.sh up
docker compose -f docker/docker-compose.yml restart gateway
# Windows PowerShell：
# .\scripts\manage.ps1 build
# .\scripts\manage.ps1 up
# docker compose -f docker/docker-compose.yml restart gateway
```

重启网关以加载新增的 `/dsh/` 路由；docker-only 部署使用 `docker restart dev-gateway`。

在 VS Code 集成终端中启动（保持该终端运行，Ctrl+C 停止）：

```bash
# 本机访问
dsh-web

# 远程部署：传入浏览器实际访问的 HTTPS 根地址，包含自定义端口
dsh-web https://your-server.example:8443
```

打开终端打印的完整 `/dsh/` 登录地址（包含进程令牌），随后在 DSH 的 **Settings → Models** 配置模型，并选择 `/workspace` 作为工作目录。DSH 模型认证需要单独配置。可要求它创建表格、文档或幻灯片，并在会话内预览、确认或丢弃修改。

DSH 仅在执行 `dsh-web` 后运行。Nginx 通过现有 HTTPS 端口转发页面、API 和 WebSocket；未启动时 `/dsh/` 返回 502。无需额外映射 3080 或插件内部 9080 端口。

DSH 配置、会话和插件保存在 `dsh-data` 数据卷（`/var/lib/dsh`），首次创建卷时自动从镜像填充。重建容器会保留数据；已有卷也会保留其中的插件版本。后续如需升级插件，先停止 DSH，再在 IDE 终端执行 `dsh plugin --profile web add dsh-univer-office@<兼容版本>`，然后重新运行 `dsh-web`。该升级步骤需要联网，日常启动不需要重新下载插件。

官方说明：[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)、[Univer Office 插件](https://github.com/dream-num/dsh-univer-office)、[反向代理部署](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/public-deployments.md)。

---

## 使用 OpenCode 与 Kilo Code

在 VS Code 集成终端执行 `opencode` 启动编程会话。Kilo Code 通过侧边栏使用，扩展 ID 为 `kilocode.kilo-code`。OpenCode GUI 扩展仍保留在线尝试安装和 VSIX 安装入口。

两个工具分别配置提供商、API Key 和模型。自建 OpenAI Chat Completions 兼容接口可在 Kilo Code 的 Providers 页面添加 Custom provider，选择 OpenAI Compatible；OpenCode 按其提供商配置填写相同接口。

需要统一模型入口时，复制并编辑 `configs/litellm_config.yaml.example`，填写 `docker/.env` 中的 `INTERNAL_API_BASE`、`INTERNAL_API_KEY`、`LITELLM_MASTER_KEY`，然后运行 `./scripts/manage.sh up --llm`（Windows 使用 `up -Llm`）。容器内 Base URL 为 `http://llm-gateway:4000/v1`，Key 为 `LITELLM_MASTER_KEY`，模型选择模板中的 `internal-agent` 或自定义 `model_name`。

详细步骤见 [配置指南](CONFIGURATION.md)。

## 从旧版本升级

重新构建镜像并运行 `up` 重建 code-server，随后运行 `docker restart dev-gateway`。镜像不再安装 Claude Code CLI、Claude Code 扩展、Cline 和 Roo Code，也不再注入相关 API 环境变量或挂载专用配置卷。容器启动会自动卸载持久化扩展卷中的这三个旧扩展；旧配置与会话数据保留。当前项目和 Git 历史未发现 CC Switch 安装入口。

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
flash-openocd            # 别名
pyocd list               # 列出调试器
flash-pyocd              # 别名

# ESP32/ESP8266 固件烧录
esptool.py --port /dev/ttyUSB0 write_flash 0x0 firmware.bin
esp-flash                # 别名

# ARM 仿真（无硬件开发板）
qemu-arm-static ./arm-binary
qemu-arm                 # 别名
qemu-system-arm -M stm32-p103 -kernel firmware.elf

# 查看 ELF 信息
arm-none-eabi-size firmware.elf
arm-none-eabi-objdump -d firmware.elf
arm-size firmware.elf    # 别名

# API 文档生成（Sphinx + Breathe）
sphinx-quickstart
sphinx-init              # 别名
sphinx-build -b html docs/ docs/_build/

# 构建系统
scons                    # SCons 构建
conan install .          # Conan 包管理

---

## 预装 VS Code 扩展

### AI 编程助手
| 扩展 | ID |
|------|-----|
| Kilo Code | `kilocode.kilo-code` |
| OpenCode GUI（可选） | `TanishqKancharla.opencode-vscode` |

### 嵌入式 / C/C++ 开发
| 扩展 | ID |
|------|-----|
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

> **说明**：C/C++ IntelliSense 使用 clangd；Kilo Code 安装失败会中断构建，其他可选扩展可跳过。

---

## 管理命令

### Linux/macOS (`manage.sh`)

```bash
./scripts/manage.sh init          # 初始化 .env
./scripts/manage.sh ssl           # 生成 SSL 证书（up 时自动执行）
./scripts/manage.sh pull          # 拉取基础镜像
./scripts/manage.sh build         # 构建自定义镜像
./scripts/manage.sh up            # 启动服务
./scripts/manage.sh up --llm      # 启动服务（含 LiteLLM 网关）
./scripts/manage.sh up --docker-only  # 在无 docker compose 环境启动
./scripts/manage.sh down          # 停止服务
./scripts/manage.sh status        # 查看状态
./scripts/manage.sh logs          # 查看所有日志
./scripts/manage.sh logs code-server  # 查看指定服务日志
./scripts/manage.sh shell code-server # 进入 VS Code 容器
./scripts/manage.sh save          # 导出镜像（离线部署用）
./scripts/manage.sh load          # 加载镜像（无需 docker compose）
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

# 若内网只有 docker（无 docker compose），使用 --docker-only 标志
./scripts/manage.sh up --docker-only
```

---

## 云端部署 SSL 配置

将 code-server 部署在云端服务器（公网 IP 或内网固定 IP）时，本地浏览器通过 `https://<server-ip>:8443` 访问，需要额外处理 SSL 信任问题，否则 VS Code 插件（如 Kilo Code）使用的 Service Worker 会因证书不可信而报错：

> `SecurityError: Failed to register a ServiceWorker … An SSL certificate error occurred`

---

### 方案一：使用 Let's Encrypt（推荐，适合有域名的公网服务器）

无需分发任何文件，浏览器原生信任。

```bash
# 1. 安装 certbot
apt install certbot

# 2. 申请证书（需 80/443 端口可访问或使用 DNS challenge）
certbot certonly --standalone -d your.domain.com

# 3. 将证书软链接或复制到项目 ssl 目录
ln -sf /etc/letsencrypt/live/your.domain.com/fullchain.pem configs/ssl/server.crt
ln -sf /etc/letsencrypt/live/your.domain.com/privkey.pem  configs/ssl/server.key

# 4. 启动服务（跳过自动生成步骤）
./scripts/manage.sh up
```

> Let's Encrypt 证书 90 天有效，用 `certbot renew` + cron 自动续期。

---

### 方案二：自签名证书 + 分发给客户端（适合内网/无域名环境）

#### 步骤 1：在服务器上生成含服务器地址的证书

```bash
# 将服务器 IP 或内网域名写入 .env（可选，up 时自动带入）
echo "SERVER_DOMAIN=192.168.1.100" >> docker/.env

# 或直接传参生成
./scripts/manage.sh ssl 192.168.1.100
# 域名同理：
./scripts/manage.sh ssl dev.company.com
```

生成的证书 SAN 中会同时包含 `localhost` 和指定的 IP/域名。

#### 步骤 2：分发证书文件给每位客户端用户

需要分发的**唯一文件**：

```
configs/ssl/server.crt
```

> **不要分发 `server.key`（私钥）**，客户端只需要公钥证书。

#### 步骤 3：客户端导入受信任根证书

**Windows（Chrome / Edge）**

```powershell
# 以管理员身份运行 PowerShell
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("C:\path\to\server.crt")
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$store.Open("ReadWrite"); $store.Add($cert); $store.Close()
```

或图形界面：`Win+R` → `certmgr.msc` → "受信任的根证书颁发机构" → "证书" → 右键"导入"。

**macOS（Safari / Chrome）**

```bash
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain server.crt
```

**Linux（Chrome）**

```bash
# Debian/Ubuntu
sudo cp server.crt /usr/local/share/ca-certificates/dev-server.crt
sudo update-ca-certificates

# Chrome 使用系统证书（需重启浏览器）
```

**Linux（Firefox）**

Firefox 使用独立证书库，需手动导入：
`设置` → `隐私与安全` → 拉到底部 `查看证书` → `证书颁发机构` → `导入`。

---

### 方案三：浏览器临时信任（最简单，有局限）

首次访问时浏览器会显示"不安全"警告：
1. 点击"高级" → "继续访问"
2. **此方式对 Service Worker 无效**，Kilo Code 等插件的 webview 仍会报 SSL 错误

结论：若需要插件正常工作，必须使用方案一或方案二。

---

### 各方案对比

| | 方案一（Let's Encrypt）| 方案二（自签名+分发）| 方案三（浏览器跳过）|
|---|---|---|---|
| 需要域名 | ✅ 是 | ❌ 否 | ❌ 否 |
| 浏览器信任 | ✅ 自动 | ✅ 导入后 | ⚠️ 仅普通页面 |
| Service Worker 可用 | ✅ | ✅ 导入后 | ❌ |
| 客户端操作 | 无 | 导入一次证书 | 每次手动跳过 |
| 适用场景 | 公网服务器 | 内网/离线环境 | 临时测试 |

---

## 故障排除

### AI 工具无法连接模型

在 OpenCode / Kilo Code 中检查提供商、Base URL、Key 和模型 ID，并确认容器可以访问模型服务。DSH 在自己的 Settings → Models 中单独配置。详见 [配置指南](CONFIGURATION.md)。

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

### WebSocket 错误 1006（工作台无法连接）

nginx 必须使用 `$http_host`（含端口）转发 Host 头，否则 code-server CSRF 检查会拒绝 WebSocket 升级请求（返回 403）。当前配置已正确设置，若自定义 nginx 配置请确保：

```nginx
# code-server location 块中：
proxy_set_header Host $http_host;  # 不能用 $host（会丢失端口）
```

### 构建时 apt-get 网络错误

国内环境 `archive.ubuntu.com` 可能无法访问。Dockerfile 已切换至阿里云 HTTP 镜像，若仍失败可改为：

```dockerfile
RUN sed -i 's|http://mirrors.aliyun.com/ubuntu|http://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' /etc/apt/sources.list
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

## 跨平台编辑：行尾与编码修复

项目在 Windows 和 Linux 之间来回编辑时，部分编辑器（如 VS Code on Windows、PowerShell）会写入 CRLF 行尾或 UTF-8 BOM，导致 Linux 上的 shell 脚本和配置文件损坏（常见表现：`bad interpreter`、`$'\r': command not found`）。

项目已通过 `.gitattributes` 对 `.sh` 等文件强制 LF，但本地未提交的文件或手动编辑的配置仍可能被污染。

### 一键修复（在 Linux 上运行）

```bash
./scripts/fix-line-endings.sh
```

**处理范围**：`.sh` `.yml` `.yaml` `.conf` `.json` `.env` 及 `scripts/` 下无扩展名文件
**跳过**：`images/` 目录、`.tar` 文件等二进制内容
**操作**：CRLF → LF、去除 UTF-8 BOM，就地修改原文件

建议在以下时机运行：
- 从 Windows 拉取代码后首次在 Linux 上启动
- 手动编辑配置文件后遇到奇怪报错时

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

### 2026-11-05
- 保留 OpenCode，新增 Kilo Code 扩展；移除 Claude Code、Cline、Roo Code 的安装与专用配置。
- 新增 DSH + Univer Office、持久化数据和 `/dsh/` 网关入口。

### v4.2.0 (2026-03-10)
- 新增：`scripts/fix-line-endings.sh`，一键清理跨平台编辑引入的 CRLF 行尾和 UTF-8 BOM，防止配置文件在 Linux 上损坏

### v4.1.0 (2026-03-09)
- 修复：Dockerfile 补充 `clangd` 包（`clang-tools` 不包含 language server 二进制），vscode-clangd 扩展现在开箱即用
- 新增：manage.sh `--docker-only` 模式，`up`/`down`/`status`/`logs`/`shell` 均可在无 docker compose 环境下运行（`build` 本来就直接用 `docker build`，不受影响）
- 新增：LiteLLM 统一 LLM 网关（可选服务，`--llm` 启用）
  - 同时暴露 Anthropic（`/v1/messages`）和 OpenAI（`/v1/chat/completions`）格式
  - 内网 OpenAI 兼容 API → 转换 → Claude Code / Cline / Roo Code
  - 统一 API key，各工具无需单独登录配置
  - nginx `/llm/` 路由使用懒解析，服务未启动时其他服务不受影响
- 新增：`configs/litellm_config.yaml.example` 配置模板

### v4.0.0 (2026-03-07)
- 将 embedded-dev 容器工具链全部迁移进 code-server，终端直接使用所有嵌入式工具
- 新增：QEMU (qemu-user-static / qemu-system-arm)、stlink-tools、libftdi1-dev、libhidapi-dev
- 新增：pyocd、esptool、conan、scons、Sphinx + Breathe + Exhale、Google Test
- 新增：pyusb、pycparser、cffi 等 Python 支持库
- 删除：embedded-dev 服务及 Dockerfile.embedded、embedded-* 辅助脚本
- 更新：manage.sh / test-docker-build.sh 去除 embedded-dev 相关构建/保存逻辑

### v3.2.0 (2026-03-07)
- 修复 SSL 证书不含 SAN 导致 Service Worker 注册失败（Cline 插件 webview 不可用）
- manage.ps1：重新生成证书后自动导入 Windows 受信任根存储
- manage.sh：gen_ssl 支持可选参数 `<host>`，云端 IP/域名加入证书 SAN；up 时读取 `.env` 中 `SERVER_DOMAIN` 自动传参
- manage.sh：修正旧变量名（LLM_API_URL → ANTHROPIC_*）、update-config 引用已删容器、start_services 错误 URL、save_images 包含已删镜像
- manage.sh：pull_images 改为从 docker-compose.yml / Dockerfile 动态读取镜像版本，与 manage.ps1 保持一致
- 新增"云端部署 SSL 配置"文档，含三种方案对比及各平台证书导入步骤

### v3.1.0 (2026-03-06)
- 修复 nginx WebSocket 代理（`$host` → `$http_host`），解决工作台无法连接（错误 1006）
- 切换 apt 源至阿里云 HTTP 镜像，解决国内网络无法构建问题
- 移除不可用包（`cloc`、`astyle` 等）及已被 `probe-rs-tools` 替代的 `cargo-embed`
- 文档全面更新，与实际测试状态保持一致

### v3.0.0 (2026-03-06)
- Claude Code CLI 与 code-server 合并为单一容器，终端直接使用 `claude`
- ARM GCC 13.2 / clang / cppcheck / openocd 内置于 IDE 容器
- 移除独立 claude-web 服务（原为无功能静态页）
- 新增 Windows PowerShell 管理脚本 `scripts/manage.ps1`
- 修复 nginx 健康检查、build context、docker compose v1/v2 兼容性等问题
- 新增 `.gitattributes` 防止 Windows CRLF 破坏 Linux 脚本

### v1.0.0 (2026-03-05)
- 初始版本
