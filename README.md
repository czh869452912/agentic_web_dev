# Agentic 云开发环境

内网私有化部署的 AI 驱动嵌入式开发平台。

---

## 核心特性

| 特性 | 说明 |
|------|------|
| **单端口入口** | 所有服务通过 8443 端口（HTTPS）访问 |
| **Claude Code 内置** | Claude Code CLI 与 VS Code 在同一容器，终端直接使用 |
| **嵌入式工具链** | ARM GCC 13.2、clang-tidy、cppcheck、OpenOCD 等内置于 IDE 容器 |
| **完整扩展** | Cortex-Debug、CMake、GitLens、Cline 等 13+ 插件预装 |
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
       │                   ├── gdb-multiarch / openocd / stlink-tools
       │                   ├── QEMU (qemu-arm-static / qemu-system-arm)
       │                   ├── pyocd / esptool / conan / scons
       │                   ├── Sphinx / Breathe（API 文档生成）
       │                   ├── Google Test / Ceedling（C/C++ 单元测试）
       │                   └── 13+ VS Code 扩展
       │
       ├── /files/    →  filebrowser（Web 文件管理）
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
│   ├── Dockerfile.code-server      # VS Code + Claude Code + 完整嵌入式工具链
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
│   ├── code-server-entrypoint.sh  # code-server 容器启动脚本
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
claude config set model claude-sonnet-4-6
```

> Claude Code 通过终端 CLI 使用。`anthropic.claude-code` 官方 VS Code 扩展与当前 code-server 版本不兼容，已预装 Cline（`saoudrizwan.claude-dev`）作为可视化 AI 助手备选。

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
| Cline | `saoudrizwan.claude-dev` |

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

> **说明**：`anthropic.claude-code` 与 code-server v4.21.0 不兼容未安装；`ms-vscode.cpptools-extension-pack` 在 code-server marketplace 中不可用。如需 C/C++ IntelliSense，请将对应 VSIX 放入 `configs/vsix/` 离线安装。

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

## 云端部署 SSL 配置

将 code-server 部署在云端服务器（公网 IP 或内网固定 IP）时，本地浏览器通过 `https://<server-ip>:8443` 访问，需要额外处理 SSL 信任问题，否则 VS Code 插件（如 Cline）使用的 Service Worker 会因证书不可信而报错：

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
2. **此方式对 Service Worker 无效**，Cline 等插件的 webview 仍会报 SSL 错误

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
