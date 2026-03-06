# 快速参考手册 v2.0

## 常用命令

```bash
# 初始化（首次使用）
./scripts/manage.sh init
./scripts/manage.sh config
./scripts/manage.sh test-api

# 构建和启动
./scripts/manage.sh pull
./scripts/manage.sh build
./scripts/manage.sh up

# 管理
./scripts/manage.sh status
./scripts/manage.sh logs
./scripts/manage.sh down

# 调试
./scripts/manage.sh shell embedded-dev
./scripts/manage.sh shell code-server
```

## 访问地址

| 服务 | 地址 |
|------|------|
| VS Code | https://server:8443/ |
| Claude | https://server:8443/claude/ |
| 文件 | https://server:8443/files/ |

## 环境配置 (docker/.env)

```bash
# 必填
LLM_API_URL=http://internal-llm:8000/v1
LLM_API_KEY=your-key
LLM_MODEL=gpt-4

# 可选
CODE_SERVER_PASSWORD=changeme
GATEWAY_PORT=8443
```

## 代码质量工具速查

```bash
# 格式化
clang-format -i *.c

# 静态检查
clang-tidy *.c --
cppcheck --enable=all src/

# 内存检查
valgrind --leak-check=full ./program

# 覆盖率
gcovr -r . --html -o coverage.html

# 文档
doxygen Doxyfile
```

## Claude Code 用法

```bash
# 交互模式
claude

# 审查代码
claude review src/main.c

# 生成测试
claude test calculator.c

# 解释代码
claude explain interrupt.c
```

## 预装 VS Code 插件

### AI 助手
| 插件 ID | 功能 |
|---------|------|
| anthropic.claude-code | **Claude Code 官方扩展** |
| saoudrizwan.claude-dev | Cline（备选） |

### C/C++ 开发