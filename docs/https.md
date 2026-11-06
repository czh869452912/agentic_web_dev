# HTTPS 与证书

本项目在 `configs/ssl/server.crt` 和 `configs/ssl/server.key` 读取证书与私钥，Nginx 容器将整个目录挂载到 `/etc/nginx/ssl`。部署参数见 [配置指南](../CONFIGURATION.md)。

## 域名与 SAN

证书必须覆盖浏览器实际访问的每个名称，客户端也必须信任其签发方。

| 访问方式 | 示例证书 SAN |
| --- | --- |
| 本机 IDE 与 DSH | `localhost`、`3080.localhost` |
| 远程 IDE 与 DSH | `dev.example`、`3080.dev.example` |
| IDE 直接使用 IP | 对应 IP SAN；DSH 仍需可解析的 forwarding 域名 |

证书名称不包含端口。Bash `up` 在首次生成证书时读取 `SERVER_DOMAIN`；手动 `ssl` 以及 PowerShell 的远程证书生成应显式传入服务器名称。它不配置 DNS，DSH 远程域名由 `CODE_SERVER_PROXY_DOMAIN` 决定。示例：

```dotenv
GATEWAY_PORT=8443
SERVER_DOMAIN=dev.example
CODE_SERVER_PROXY_DOMAIN={{port}}.dev.example:8443
```

配置服务器或客户端 DNS/hosts，使两个名称指向服务器。管理脚本为本机 `3080.localhost` 和模板解析出的 DSH 3080 域名生成 SAN，并不会自动为所有端口生成通配符证书。

## 使用已有受信任证书

可使用组织 CA 或公共 CA 签发的证书，确保包含 IDE 与 DSH 两个名称。将完整证书链和私钥分别复制到项目路径：

```bash
cp /path/to/fullchain.pem configs/ssl/server.crt
cp /path/to/privkey.pem configs/ssl/server.key
docker restart dev-gateway
```

公共 CA 可通过 ACME 工具管理申请与续期；每次更新项目证书文件后重新加载网关。证书文件应是容器挂载目录内可读取的实际文件；直接软链接到宿主机其他目录时，目标可能在容器中不存在。

## 生成自签名证书

先编辑 `docker/.env` 的服务器名称和 forwarding 模板，再运行：

```bash
./scripts/manage.sh ssl              # 本机
./scripts/manage.sh ssl dev.example  # 远程：显式提供 IDE 名称，同时读取 .env 的 DSH 模板
```

PowerShell：

```powershell
.\scripts\manage.ps1 ssl              # 本机
.\scripts\manage.ps1 ssl dev.example  # 远程：显式提供 IDE 名称，同时读取 .env 的 DSH 模板
```

`up` 只在证书不存在时生成，不会因 `.env` 修改而自动重新签发已有证书。旧证书缺少 DSH 域名时，应先确认原证书的备份与用途，再运行 `ssl` 替换，重启网关，并将新证书分发给客户端。PowerShell 脚本还会尝试导入本机信任库，其他客户端需单独处理。

查看生成证书的 SAN：

```bash
openssl x509 -in configs/ssl/server.crt -noout -ext subjectAltName
```

## 客户端信任

自签名方案分发 `configs/ssl/server.crt`；不要分发私钥 `server.key`。若使用组织 CA，则按组织策略安装根证书与中间链。以下步骤针对项目生成的自签名证书。

### Windows

以管理员身份运行 PowerShell，将文件路径替换为实际位置：

```powershell
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("C:\path\to\server.crt")
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
$store.Open("ReadWrite")
$store.Add($cert)
$store.Close()
```

也可通过证书管理器导入“受信任的根证书颁发机构”。导入后重启浏览器，分别访问 IDE 和 DSH 地址确认名称与信任均无错误。

### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain server.crt
```

### Linux

Debian/Ubuntu 系统信任库示例：

```bash
sudo cp server.crt /usr/local/share/ca-certificates/dev-server.crt
sudo update-ca-certificates
```

浏览器可能另有证书库或组织策略；重启后若仍未信任，在实际浏览器的证书设置中检查并导入。Firefox 可在“隐私与安全 → 证书 → 查看证书 → 证书颁发机构”中管理信任。

## 排查扩展与 DSH

单纯点击浏览器“继续访问”不足以保证 Service Worker 和扩展网页视图工作。出现 `Failed to register a ServiceWorker` 或 SSL 错误时，依次确认：

1. IDE 与 DSH 域名解析到正确服务器。
2. 浏览器看到的实际证书包含该名称，且没有过期。
3. 实际浏览器信任证书链；更换证书后已更新客户端信任。
4. 网关已重启以加载新证书，code-server 已重建以加载新的 forwarding 环境变量。

[兼容性测试](compatibility.md#验证结果) 使用隔离环境并忽略临时测试证书信任错误，不代替目标 Win7 客户端的证书验收。
