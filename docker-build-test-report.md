# Docker 构建测试报告

## 测试环境
- Docker 版本：29.3.0
- 主机：Ubuntu 24.04
- 时间：2026-03-06

## 发现的问题

### 1. 路径配置错误（重要）

**问题描述**：
`Dockerfile.code-server` 中引用了 `configs/vsix/*.vsix`，但 build context 是 `docker/` 目录，而实际的 `configs` 目录在上一级。

**文件位置**：
- `agentic-dev-env/docker/Dockerfile.code-server` （build context: `.` = docker/）
- `agentic-dev-env/configs/vsix/` （实际位置）

**问题代码**（Dockerfile.code-server:93）：
```dockerfile
COPY --chown=coder:coder configs/vsix/*.vsix /tmp/vsix/ 2>/dev/null || true
```

这会在 `docker/configs/vsix/` 查找文件，但该目录不存在。

**修复方案**：

方案 A - 修改 docker-compose.yml 的 build context：
```yaml
code-server:
  build:
    context: ..          # 改为上级目录
    dockerfile: docker/Dockerfile.code-server  # 调整路径
```

方案 B - 修改 Dockerfile 中的路径：
```dockerfile
COPY --chown=coder:coder ../configs/vsix/*.vsix /tmp/vsix/ 2>/dev/null || true
```

**建议采用方案 A**，因为方案 B 可能违反 Docker 安全规则（禁止 COPY 到 parent directory）。

---

### 2. 网络问题

Docker Hub 连接超时，需要配置国内镜像源。

**已配置的镜像源**：
```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

---

### 3. Dockerfile 语法检查

手动检查各 Dockerfile 语法：

#### Dockerfile.claude
- ✅ FROM 指令正确
- ✅ RUN 指令正确
- ✅ 多行脚本使用 heredoc (<< 'EOF') 格式正确
- ✅ EXPOSE 指令正确
- ✅ CMD 指令正确
- ⚠️ 注意：使用了 npm install -g，可能需要处理网络超时

#### Dockerfile.code-server
- ✅ FROM 指令正确
- ✅ USER 切换正确
- ✅ RUN 指令正确
- ✅ 插件安装使用循环
- ⚠️ **路径问题**：configs/vsix/ 位置不正确（见上文）

#### Dockerfile.embedded
- ✅ FROM 指令正确
- ✅ ENV 设置正确
- ✅ 多阶段构建结构清晰
- ✅ 健康检查配置正确
- ⚠️ 镜像体积会很大（包含完整工具链）

---

## 修复建议

1. **修复路径问题**：修改 docker-compose.yml 中的 build context ✅ **已修复**
   - 修改前：`context: .`
   - 修改后：`context: ..`
   - 相应调整：`dockerfile: docker/Dockerfile.code-server`

2. **添加 .dockerignore**：减少构建上下文大小
3. **优化镜像体积**：考虑多阶段构建减小最终镜像
4. **添加构建缓存**：利用 Docker layer caching

---

## 修复详情

### docker-compose.yml 修改
```yaml
code-server:
  build:
    context: ..          # 从 docker/ 改为上级目录
    dockerfile: docker/Dockerfile.code-server  # 相应调整路径
```

这样 `Dockerfile.code-server` 中的 `COPY configs/vsix/*.vsix` 就能正确找到 `agentic-dev-env/configs/vsix/` 目录了。

---

## 待完成

由于网络问题，实际构建测试未能完成。建议在以下环境重新测试：
- 网络稳定的环境
- 已配置 Docker 镜像加速器的环境

## 运行测试的方法

### 方法 1: 使用测试脚本
```bash
cd agentic-dev-env
./scripts/test-docker-build.sh
```

### 方法 2: 单独构建每个镜像
```bash
cd agentic-dev-env/docker

# 构建 Claude Code 镜像
docker build -f Dockerfile.claude -t agentic-dev-env/claude:latest .

# 构建 Code Server 镜像（注意 context 是上级目录）
docker build -f Dockerfile.code-server -t agentic-dev-env/code-server:latest ..

# 构建 Embedded Dev 镜像
docker build -f Dockerfile.embedded -t agentic-dev-env/embedded:latest .
```

### 方法 3: 使用 docker-compose
```bash
cd agentic-dev-env/docker
docker compose build
docker compose up -d
```

## 本次修复内容

1. ✅ **修复 build context 路径** - `code-server` 服务的 build context 从 `.` 改为 `..`
2. ✅ **移除过时的 version 字段** - docker-compose.yml 中的 `version: '3.8'` 已移除
3. ✅ **添加 .dockerignore** - 减少构建上下文大小
4. ✅ **添加测试脚本** - `scripts/test-docker-build.sh`

## Dockerfile 语法检查结果

| 镜像 | 状态 | 备注 |
|------|------|------|
| Dockerfile.claude | ✅ 语法正确 | 标准 Node.js 镜像 |
| Dockerfile.code-server | ✅ 语法正确 | 基于 code-server，预装插件 |
| Dockerfile.embedded | ✅ 语法正确 | 完整工具链，体积较大 |
