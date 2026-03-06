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
./scripts/manage.sh shell code-server    # VS Code + Claude Code 容器
./scripts/manage.sh shell embedded-dev  # 重型工具链容器
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
| VS Code Web | https://server:8443/ |
| 文件管理 | https://server:8443/files/ |

---

## API 配置 (docker/.env)

```bash
# Anthropic 官方 API
ANTHROPIC_API_KEY=sk-ant-api03-...

# 内网代理（须实现 Anthropic /v1/messages 协议）
ANTHROPIC_API_KEY=your-key
ANTHROPIC_BASE_URL=http://10.0.0.100:8000

# 不填则启动后交互式登录（运行 claude 命令）
```

---

## Claude Code 用法（在 VS Code 终端中运行）

```bash
# 启动交互式会话
claude

# 编辑文件
claude src/main.c

# 查看/修改配置
claude config get
claude config set model claude-opus-4-5
```

---

## 嵌入式开发工具速查

```bash
# ARM 编译
arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -o fw.elf main.c
arm-gcc main.c          # 别名

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

# 文档生成
doxygen Doxyfile
```

---

## 预装 VS Code 扩展

| 类别 | 扩展 |
|------|------|
| AI | `anthropic.claude-code`, `saoudrizwan.claude-dev` |
| C/C++ | `ms-vscode.cpptools-extension-pack`, `marus25.cortex-debug` |
| 嵌入式 | `dan-c-underwood.arm`, `zixuanwang.linkerscript` |
| 质量 | `jbenden.c-cpp-flylint`, `xaver.clang-format`, `notskm.clang-tidy` |
| 构建 | `ms-vscode.cmake-tools`, `twxs.cmake` |
| Git | `eamodio.gitlens`, `mhutchie.git-graph` |
| 生产力 | `usernamehw.errorlens`, `christian-kohler.path-intellisense` |
