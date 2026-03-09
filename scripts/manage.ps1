# ============================================================
# Agentic 开发环境管理脚本 (Windows PowerShell)
# 用法: .\scripts\manage.ps1 <命令> [参数] [-Llm] [-DockerOnly]
# ============================================================

param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Arg1 = "",

    [switch]$Llm,        # 包含 LiteLLM 统一 LLM 网关服务
    [switch]$DockerOnly  # 强制使用 docker 命令（不使用 docker compose）
)

$ErrorActionPreference = "Stop"

# ---- 路径 ----
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DockerDir   = Join-Path $ProjectRoot "docker"
$ConfigsDir  = Join-Path $ProjectRoot "configs"
$EnvFile     = Join-Path $DockerDir ".env"

# ---- 模块级状态变量 ----
$script:ComposeAvailable = $true
$script:DockerCompose    = "docker compose"
$script:UseLlm           = $Llm.IsPresent
$script:DockerOnly       = $DockerOnly.IsPresent

# ---- 颜色输出 ----
function Write-Info  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "[ OK ]  $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL]  $msg" -ForegroundColor Red }

# ---- Docker 基本检测 ----
function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Fail "未找到 docker，请先安装 Docker Desktop"
        exit 1
    }
    $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    docker info 2>&1 | Out-Null
    $dockerExit = $LASTEXITCODE
    $ErrorActionPreference = $savedEAP
    if ($dockerExit -ne 0) {
        Write-Fail "Docker daemon 未运行，请启动 Docker Desktop"
        exit 1
    }
}

# ---- Compose 模式初始化（检测 compose 可用性，设模块变量）----
function Initialize-ComposeMode {
    if ($script:DockerOnly) {
        $script:ComposeAvailable = $false
        Write-Warn "[模式] docker-only（已通过 -DockerOnly 强制）"
        return
    }
    $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    docker compose version 2>&1 | Out-Null
    $exit1 = $LASTEXITCODE
    $ErrorActionPreference = $savedEAP
    if ($exit1 -eq 0) {
        $script:DockerCompose = "docker compose"
        $script:ComposeAvailable = $true
    } elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $script:DockerCompose = "docker-compose"
        $script:ComposeAvailable = $true
    } else {
        $script:ComposeAvailable = $false
        Write-Warn "未找到 docker compose，自动切换到 docker-only 模式"
    }
}

# ---- 解析 .env 文件为哈希表（bash source .env 的替代）----
function Read-EnvFile {
    $envHash = @{}
    if (-not (Test-Path $EnvFile)) { return $envHash }
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#\s][^=]*)=(.*)$') {
            $envHash[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $envHash
}

# ---- 初始化目录 ----
function Initialize-Dirs {
    @("images","logs\nginx","workspace") | ForEach-Object {
        $p = Join-Path $ProjectRoot $_
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
    $sslDir = Join-Path $ConfigsDir "ssl"
    if (-not (Test-Path $sslDir)) { New-Item -ItemType Directory -Path $sslDir -Force | Out-Null }
}

# ---- 从源文件动态读取基础镜像版本 ----
function Get-BaseImages {
    $composeFile  = Join-Path $DockerDir "docker-compose.yml"
    $csDockerfile = Join-Path $DockerDir "Dockerfile.code-server"
    $composeLines = Get-Content $composeFile
    $nginxImg = ($composeLines | Select-String "image:\s*(nginx\S+)"    ).Matches[0].Groups[1].Value
    $fbImg    = ($composeLines | Select-String "image:\s*(filebrowser\S+)").Matches[0].Groups[1].Value
    $csImg    = ((Get-Content $csDockerfile | Select-String "^FROM\s+(\S+)")[0]).Matches[0].Groups[1].Value
    return @($nginxImg, $csImg, $fbImg)
}

# ============================================================
# Docker-only 辅助函数
# ============================================================

function Ensure-Network {
    $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    docker network inspect devnet 2>&1 | Out-Null
    $ErrorActionPreference = $savedEAP
    if ($LASTEXITCODE -ne 0) {
        Write-Info "  创建网络 devnet..."
        docker network create --driver bridge --subnet 172.20.0.0/16 devnet | Out-Null
    }
}

function Ensure-Volumes {
    @("code-extensions","code-config","claude-config","filebrowser-db") | ForEach-Object {
        $vol = $_
        $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        docker volume inspect $vol 2>&1 | Out-Null
        $ErrorActionPreference = $savedEAP
        if ($LASTEXITCODE -ne 0) {
            Write-Info "  创建 volume: $vol"
            docker volume create $vol | Out-Null
        }
    }
}

# 移除同名旧容器后重新 docker run
function Invoke-DockerRunContainer {
    param([string]$Name, [string[]]$RunArgs)
    $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    docker inspect $Name 2>&1 | Out-Null
    $ErrorActionPreference = $savedEAP
    if ($LASTEXITCODE -eq 0) {
        Write-Info "  移除旧容器 $Name..."
        docker rm -f $Name | Out-Null
    }
    $allArgs = @("run","-d","--name",$Name,"--network","devnet","--restart","unless-stopped") + $RunArgs
    & docker @allArgs
    if ($LASTEXITCODE -ne 0) { Write-Fail "容器 $Name 启动失败"; exit 1 }
}

function Invoke-UpDocker {
    $envVars      = Read-EnvFile
    $pw           = if ($envVars["CODE_SERVER_PASSWORD"]) { $envVars["CODE_SERVER_PASSWORD"] } else { "changeme" }
    $sudoPw       = if ($envVars["SUDO_PASSWORD"])        { $envVars["SUDO_PASSWORD"] }        else { "changeme" }
    $apiKey       = if ($envVars["ANTHROPIC_API_KEY"])    { $envVars["ANTHROPIC_API_KEY"] }    else { "" }
    $baseUrl      = if ($envVars["ANTHROPIC_BASE_URL"])   { $envVars["ANTHROPIC_BASE_URL"] }   else { "" }
    $gwPort       = if ($envVars["GATEWAY_PORT"])         { $envVars["GATEWAY_PORT"] }         else { "8443" }
    $litellmKey   = if ($envVars["LITELLM_MASTER_KEY"])   { $envVars["LITELLM_MASTER_KEY"] }   else { "sk-devenv" }
    $internalBase = if ($envVars["INTERNAL_API_BASE"])    { $envVars["INTERNAL_API_BASE"] }    else { "" }
    $internalKey  = if ($envVars["INTERNAL_API_KEY"])     { $envVars["INTERNAL_API_KEY"] }     else { "" }

    Ensure-Network
    Ensure-Volumes

    # 1. code-server
    Write-Info "  启动 code-server..."
    Invoke-DockerRunContainer -Name "code-server" -RunArgs @(
        "--hostname","code-server","--network-alias","vscode.local",
        "-e","PASSWORD=$pw","-e","SUDO_PASSWORD=$sudoPw",
        "-e","ANTHROPIC_API_KEY=$apiKey","-e","ANTHROPIC_BASE_URL=$baseUrl",
        "-v","${ProjectRoot}\workspace:/workspace",
        "-v","code-extensions:/home/coder/.local/share/code-server/extensions",
        "-v","code-config:/home/coder/.config/code-server",
        "-v","claude-config:/home/coder/.claude",
        "code-server-custom:latest"
    )

    # 2. filebrowser
    Write-Info "  启动 filebrowser..."
    $fbJson = Join-Path $ConfigsDir "filebrowser.json"
    Invoke-DockerRunContainer -Name "filebrowser" -RunArgs @(
        "--hostname","filebrowser","--network-alias","files.local",
        "-e","FB_DATABASE=/database/filebrowser.db","-e","FB_ROOT=/srv","-e","FB_PORT=8080",
        "-v","${ProjectRoot}\workspace:/srv",
        "-v","filebrowser-db:/database",
        "-v","${fbJson}:/.filebrowser.json:ro",
        "filebrowser/filebrowser:v2.27.0"
    )

    # 3. llm-gateway（可选）
    if ($script:UseLlm) {
        $llmCfg = Join-Path $ConfigsDir "litellm_config.yaml"
        if (-not (Test-Path $llmCfg)) {
            Write-Fail "错误: $llmCfg 不存在，请先创建: Copy-Item configs\litellm_config.yaml.example configs\litellm_config.yaml"
            exit 1
        }
        $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        docker volume inspect litellm-cache 2>&1 | Out-Null
        $ErrorActionPreference = $savedEAP
        if ($LASTEXITCODE -ne 0) { docker volume create litellm-cache | Out-Null }
        Write-Info "  启动 llm-gateway..."
        Invoke-DockerRunContainer -Name "llm-gateway" -RunArgs @(
            "--hostname","llm-gateway","--network-alias","llm.local",
            "-e","LITELLM_MASTER_KEY=$litellmKey",
            "-e","INTERNAL_API_BASE=$internalBase",
            "-e","INTERNAL_API_KEY=$internalKey",
            "-v","${llmCfg}:/app/config.yaml:ro",
            "-v","litellm-cache:/app/.cache",
            "ghcr.io/berriai/litellm:main-latest",
            "--config","/app/config.yaml","--port","4000"
        )
    }

    # 4. nginx gateway（最后启动，确保上游容器已存在）
    $logsNginx = Join-Path $ProjectRoot "logs\nginx"
    New-Item -ItemType Directory -Path $logsNginx -Force | Out-Null
    Write-Info "  启动 dev-gateway (nginx)..."
    $nginxConf = Join-Path $ConfigsDir "nginx.conf"
    $sslDir    = Join-Path $ConfigsDir "ssl"
    Invoke-DockerRunContainer -Name "dev-gateway" -RunArgs @(
        "--hostname","gateway","--network-alias","gateway.local",
        "-p","${gwPort}:8443",
        "-v","${nginxConf}:/etc/nginx/nginx.conf:ro",
        "-v","${sslDir}:/etc/nginx/ssl:ro",
        "-v","${logsNginx}:/var/log/nginx",
        "nginx:alpine"
    )
}

function Invoke-DownDocker {
    $containers = @("dev-gateway","filebrowser","code-server")
    if ($script:UseLlm) { $containers = @("dev-gateway","llm-gateway","filebrowser","code-server") }
    foreach ($name in $containers) {
        $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        docker inspect $name 2>&1 | Out-Null
        $ErrorActionPreference = $savedEAP
        if ($LASTEXITCODE -eq 0) {
            Write-Info "  停止并移除 $name..."
            docker rm -f $name | Out-Null
        }
    }
}

function Show-StatusDocker {
    $containers = @("dev-gateway","code-server","filebrowser")
    if ($script:UseLlm) { $containers += "llm-gateway" }
    Write-Host ("{0,-20} {1,-12} {2}" -f "CONTAINER","STATUS","PORTS")
    foreach ($name in $containers) {
        $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        docker inspect $name 2>&1 | Out-Null
        $ErrorActionPreference = $savedEAP
        if ($LASTEXITCODE -eq 0) {
            $st = docker inspect --format '{{.State.Status}}' $name
            $savedEAP2 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $po = docker inspect --format '{{range $p,$b:=.NetworkSettings.Ports}}{{if $b}}{{$p}}->{{(index $b 0).HostPort}} {{end}}{{end}}' $name 2>&1
            $ErrorActionPreference = $savedEAP2
            Write-Host ("{0,-20} {1,-12} {2}" -f $name,$st,$po)
        } else {
            Write-Host ("{0,-20} {1,-12}" -f $name,"(not found)")
        }
    }
}

function Show-LogsDocker {
    $containerMap = @{
        "gateway"     = "dev-gateway"
        "code-server" = "code-server"
        "filebrowser" = "filebrowser"
        "llm-gateway" = "llm-gateway"
    }
    if (-not $Arg1) {
        foreach ($c in @("dev-gateway","code-server","filebrowser")) {
            Write-Host "=== $c ===" -ForegroundColor Blue
            $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            docker logs --tail=30 $c 2>&1
            $ErrorActionPreference = $savedEAP
        }
    } else {
        $cname = if ($containerMap.ContainsKey($Arg1)) { $containerMap[$Arg1] } else { $Arg1 }
        docker logs -f --tail=100 $cname
    }
}

function Enter-ShellDocker {
    $containerMap = @{
        "gateway"     = "dev-gateway"
        "code-server" = "code-server"
        "filebrowser" = "filebrowser"
        "llm-gateway" = "llm-gateway"
    }
    $cname = if ($containerMap.ContainsKey($Arg1)) { $containerMap[$Arg1] } else { $Arg1 }
    docker exec -it $cname /bin/bash
}

# ============================================================
# 命令函数
# ============================================================

function Invoke-Init {
    Write-Info "初始化环境配置..."
    if (Test-Path $EnvFile) {
        $ans = Read-Host ".env 已存在，是否覆盖? (y/N)"
        if ($ans -notmatch "^[Yy]$") { Write-OK "保留现有配置"; return }
    }
    @"
# ---- 服务访问 ----
GATEWAY_PORT=8443
CODE_SERVER_PASSWORD=changeme
SUDO_PASSWORD=changeme

# ---- Claude Code API ----
# 方案A: 官方 API  -> 填写 ANTHROPIC_API_KEY，留空 ANTHROPIC_BASE_URL
# 方案B: 内网代理  -> 同时填写（代理须实现 Anthropic /v1/messages 协议）
# 方案C: LiteLLM 统一网关（内网 OpenAI 兼容 API）->见下方 LiteLLM 配置，启动时加 -Llm
#   ANTHROPIC_API_KEY=sk-devenv         # 与 LITELLM_MASTER_KEY 保持一致
#   ANTHROPIC_BASE_URL=http://llm-gateway:4000
# 方案D: 不填，启动后在终端执行 claude 完成交互式登录
ANTHROPIC_API_KEY=
ANTHROPIC_BASE_URL=

# ---- LiteLLM 统一 LLM 网关（可选，方案C）----
# 前置: Copy-Item configs\litellm_config.yaml.example configs\litellm_config.yaml
# 启动: .\scripts\manage.ps1 up -Llm
INTERNAL_API_BASE=http://10.0.0.1:8000
INTERNAL_API_KEY=your-internal-api-key
LITELLM_MASTER_KEY=sk-devenv

# ---- 云端部署（可选）----
# SERVER_DOMAIN=1.2.3.4
"@ | Set-Content -Encoding UTF8 $EnvFile
    Write-OK "配置文件已创建 $EnvFile"
    Write-Warn "请编辑该文件配置 API 后再启动"

    # 询问是否初始化 LiteLLM 配置
    $ans2 = Read-Host "是否同时创建 LiteLLM 配置文件? (y/N)"
    if ($ans2 -match "^[Yy]$") {
        $llmExample = Join-Path $ConfigsDir "litellm_config.yaml.example"
        $llmConfig  = Join-Path $ConfigsDir "litellm_config.yaml"
        if ((Test-Path $llmExample) -and (-not (Test-Path $llmConfig))) {
            Copy-Item $llmExample $llmConfig
            Write-OK "LiteLLM 配置已创建: $llmConfig"
            Write-Warn "请编辑该文件填写内网 API 地址和模型名称"
        } elseif (Test-Path $llmConfig) {
            Write-Warn "LiteLLM 配置已存在: $llmConfig"
        } else {
            Write-Warn "请手动创建: Copy-Item configs\litellm_config.yaml.example configs\litellm_config.yaml"
        }
    }
}

function Invoke-GenSSL {
    param([string]$ServerHost = "")
    Write-Info "生成自签名 SSL 证书（含 SAN，支持 localhost）..."
    $sslDir = Join-Path $ConfigsDir "ssl"
    New-Item -ItemType Directory -Path $sslDir -Force | Out-Null

    # 构建 alt_names
    $altNames = @"
DNS.1 = localhost
DNS.2 = dev-server.local
IP.1  = 127.0.0.1
"@
    $cnName = "localhost"
    if ($ServerHost) {
        $cnName = $ServerHost
        if ($ServerHost -match '^\d+\.\d+\.\d+\.\d+$') {
            $altNames += "IP.2  = $ServerHost`n"
        } else {
            $altNames += "DNS.3 = $ServerHost`n"
        }
        Write-Info "  SAN 包含云端地址: $ServerHost"
    }

    $opensslCmd = $null
    foreach ($candidate in @("openssl","C:\Program Files\Git\usr\bin\openssl.exe")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            $opensslCmd = $candidate; break
        }
    }

    if ($opensslCmd) {
        $opensslConf = @"
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_req

[dn]
C  = CN
ST = Beijing
L  = Beijing
O  = DevOps
CN = $cnName

[v3_req]
subjectAltName      = @alt_names
keyUsage            = critical, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth
basicConstraints    = CA:FALSE

[alt_names]
$altNames
"@
        $confPath = "$sslDir\openssl.cnf"
        Set-Content -Path $confPath -Value $opensslConf -Encoding ASCII

        $savedEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $opensslCmd req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes `
            -keyout "$sslDir\server.key" `
            -out    "$sslDir\server.crt" `
            -config $confPath 2>$null
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedEAP
        Remove-Item $confPath -ErrorAction SilentlyContinue

        if ($exitCode -ne 0) { Write-Fail "openssl req -x509 failed (exit $exitCode)"; exit 1 }
        Write-OK "SSL 证书已生成到 $sslDir"
    } else {
        Write-Warn "未找到 openssl，使用 PowerShell New-SelfSignedCertificate..."
        $dnsNames = @("localhost","dev-server.local")
        if ($ServerHost -and ($ServerHost -notmatch '^\d+')) { $dnsNames += $ServerHost }
        $cert = New-SelfSignedCertificate `
            -DnsName $dnsNames `
            -CertStoreLocation "Cert:\LocalMachine\My" `
            -NotAfter (Get-Date).AddYears(1) `
            -KeyAlgorithm RSA -KeyLength 2048 `
            -HashAlgorithm SHA256 `
            -KeyUsage DigitalSignature,KeyEncipherment `
            -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")
        $pfxPath = "$sslDir\server.pfx"
        $pfxPwd = ConvertTo-SecureString "devenv" -AsPlainText -Force
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pfxPwd | Out-Null
        Write-Warn "已生成 PFX: $pfxPath"
        Write-Warn "请安装 Git for Windows（含 openssl）后重新运行 ssl 命令以生成 PEM 格式证书"
        return
    }

    # 导入 Windows 受信任根
    Write-Info "将证书导入 Windows 受信任根证书存储（需要管理员权限）..."
    try {
        $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            (Resolve-Path "$sslDir\server.crt").Path
        )
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($certObj)
        $store.Close()
        Write-OK "证书已导入受信任根存储 —— 浏览器无需手动确认"
    } catch {
        Write-Warn "导入受信任根失败（$($_.Exception.Message)）"
        Write-Warn "请以管理员身份重新运行，或手动将 $sslDir\server.crt 导入到"
        Write-Warn "'证书 -> 受信任的根证书颁发机构 -> 证书'"
    }
}

function Invoke-Build {
    Assert-Docker
    Write-Info "构建 code-server + Claude Code + 嵌入式工具链（build context: 项目根目录）"
    docker build `
        -f "$DockerDir\Dockerfile.code-server" `
        -t "code-server-custom:latest" `
        $ProjectRoot
    if ($LASTEXITCODE -ne 0) { Write-Fail "code-server 镜像构建失败"; exit 1 }
    Write-OK "镜像构建完成"
}

function Invoke-Pull {
    Assert-Docker
    Write-Info "拉取基础镜像..."
    Get-BaseImages | ForEach-Object {
        Write-Info "  拉取 $_"
        docker pull $_
    }
    if ($script:UseLlm) {
        Write-Info "  拉取 ghcr.io/berriai/litellm:main-latest"
        docker pull ghcr.io/berriai/litellm:main-latest
    }
    Write-OK "基础镜像拉取完成"
}

function Invoke-Up {
    Assert-Docker
    Initialize-ComposeMode
    Initialize-Dirs

    if (-not (Test-Path $EnvFile)) {
        Write-Fail ".env 不存在，请先运行: .\scripts\manage.ps1 init"
        exit 1
    }

    $sslCrt = Join-Path $ConfigsDir "ssl\server.crt"
    if (-not (Test-Path $sslCrt)) {
        Write-Warn "SSL 证书不存在，自动生成..."
        Invoke-GenSSL
    }

    if ($script:ComposeAvailable) {
        $composeArgs = if ($script:UseLlm) { "--profile llm up -d" } else { "up -d" }
        Set-Location $DockerDir
        Invoke-Expression "$($script:DockerCompose) $composeArgs"
        Set-Location $ProjectRoot
    } else {
        Invoke-UpDocker
    }

    Write-OK "服务已启动"
    Write-Host ""
    $envVars = Read-EnvFile
    $gwPort  = if ($envVars["GATEWAY_PORT"]) { $envVars["GATEWAY_PORT"] } else { "8443" }
    Write-Host "  访问地址:" -ForegroundColor Cyan
    Write-Host "    VSCode + Claude: https://localhost:$gwPort"    -ForegroundColor White
    Write-Host "    文件管理:        https://localhost:$gwPort/files/" -ForegroundColor White
    if ($script:UseLlm) {
        Write-Host "    LiteLLM 网关:    https://localhost:$gwPort/llm/" -ForegroundColor White
        Write-Host ""
        $lkey = if ($envVars["LITELLM_MASTER_KEY"]) { $envVars["LITELLM_MASTER_KEY"] } else { "sk-devenv" }
        Write-Host "  Claude Code 配置（容器内）:" -ForegroundColor Yellow
        Write-Host "    ANTHROPIC_BASE_URL=http://llm-gateway:4000" -ForegroundColor White
        Write-Host "    ANTHROPIC_API_KEY=$lkey" -ForegroundColor White
    }
}

function Invoke-Down {
    Assert-Docker
    Initialize-ComposeMode

    if ($script:ComposeAvailable) {
        $composeArgs = if ($script:UseLlm) { "--profile llm down" } else { "down" }
        Set-Location $DockerDir
        Invoke-Expression "$($script:DockerCompose) $composeArgs"
        Set-Location $ProjectRoot
    } else {
        Invoke-DownDocker
    }
    Write-OK "服务已停止"
}

function Invoke-Status {
    Assert-Docker
    Initialize-ComposeMode

    if ($script:ComposeAvailable) {
        Set-Location $DockerDir
        Invoke-Expression "$($script:DockerCompose) ps"
        Set-Location $ProjectRoot
    } else {
        Show-StatusDocker
    }
}

function Invoke-Logs {
    Assert-Docker
    Initialize-ComposeMode

    if ($script:ComposeAvailable) {
        Set-Location $DockerDir
        if ($Arg1) { Invoke-Expression "$($script:DockerCompose) logs -f --tail=100 $Arg1" }
        else       { Invoke-Expression "$($script:DockerCompose) logs -f --tail=100" }
        Set-Location $ProjectRoot
    } else {
        Show-LogsDocker
    }
}

function Invoke-Shell {
    Assert-Docker
    Initialize-ComposeMode

    if (-not $Arg1) {
        Write-Fail "请指定服务名，例如: .\scripts\manage.ps1 shell code-server"
        exit 1
    }

    if ($script:ComposeAvailable) {
        Set-Location $DockerDir
        Invoke-Expression "$($script:DockerCompose) exec $Arg1 /bin/bash"
        Set-Location $ProjectRoot
    } else {
        Enter-ShellDocker
    }
}

function Invoke-Save {
    Assert-Docker
    $imgDir = Join-Path $ProjectRoot "images"
    New-Item -ItemType Directory -Path $imgDir -Force | Out-Null
    $composeFile  = Join-Path $DockerDir "docker-compose.yml"
    $composeLines = Get-Content $composeFile
    $nginxImg = ($composeLines | Select-String "image:\s*(nginx\S+)"    ).Matches[0].Groups[1].Value
    $fbImg    = ($composeLines | Select-String "image:\s*(filebrowser\S+)").Matches[0].Groups[1].Value
    $images   = @($nginxImg, $fbImg, "code-server-custom:latest")
    if ($script:UseLlm) { $images += "ghcr.io/berriai/litellm:main-latest" }
    $images | ForEach-Object {
        $fname = ($_ -replace "[:/]","_") + ".tar"
        $fpath = Join-Path $imgDir $fname
        Write-Info "  保存 $_ -> $fname"
        docker save $_ -o $fpath
    }
    Write-OK "镜像已保存到 images\"
}

function Invoke-Load {
    Assert-Docker
    $imgDir = Join-Path $ProjectRoot "images"
    if (-not (Test-Path $imgDir)) { Write-Fail "images\ directory does not exist"; exit 1 }
    Get-ChildItem "$imgDir\*.tar" | ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB)
        Write-Info "  加载 $($_.Name) (${sizeMB} MB)，docker load 无进度条，大镜像请耐心等待..."
        docker load -i $_.FullName
    }
    Write-OK "镜像加载完成"
}

function Show-Help {
    Write-Host @"

用法: .\scripts\manage.ps1 <命令> [参数] [-Llm] [-DockerOnly]

命令:
  init          初始化 .env 配置文件
  ssl           生成自签名 SSL 证书
  pull          拉取基础镜像
  build         构建自定义镜像
  up            启动所有服务（自动生成 SSL）
  down          停止所有服务
  status        查看服务状态
  logs [svc]    查看日志（可指定服务名）
  shell <svc>   进入服务 shell（code-server / filebrowser / gateway / llm-gateway）
  save          保存镜像到 images\
  load          从 images\ 加载镜像（无需 docker compose）

选项:
  -Llm          包含 LiteLLM 统一 LLM 网关服务（需 configs\litellm_config.yaml）
  -DockerOnly   强制使用 docker 命令（不使用 docker compose）

示例:
  .\scripts\manage.ps1 init
  .\scripts\manage.ps1 build
  .\scripts\manage.ps1 up
  .\scripts\manage.ps1 up -Llm
  .\scripts\manage.ps1 up -DockerOnly
  .\scripts\manage.ps1 up -Llm -DockerOnly
  .\scripts\manage.ps1 shell code-server
  .\scripts\manage.ps1 logs code-server
  .\scripts\manage.ps1 down -Llm
"@
}

# ============================================================
# 主入口
# ============================================================
Write-Host "=== Agentic 开发环境 (Windows) ===" -ForegroundColor Blue

switch ($Command.ToLower()) {
    "init"   { Initialize-Dirs; Invoke-Init; break }
    "ssl"    { Invoke-GenSSL -ServerHost $Arg1; break }
    "pull"   { Invoke-Pull; break }
    "build"  { Invoke-Build; break }
    "up"     { Invoke-Up; break }
    "start"  { Invoke-Up; break }
    "down"   { Invoke-Down; break }
    "stop"   { Invoke-Down; break }
    "status" { Invoke-Status; break }
    "ps"     { Invoke-Status; break }
    "logs"   { Invoke-Logs; break }
    "shell"  { Invoke-Shell; break }
    "save"   { Invoke-Save; break }
    "load"   { Invoke-Load; break }
    default  { Show-Help }
}
