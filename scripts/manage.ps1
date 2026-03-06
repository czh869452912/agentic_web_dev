# ============================================================
# Agentic 开发环境管理脚本 (Windows PowerShell)
# 用法: .\scripts\manage.ps1 <命令>
# ============================================================

param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Arg1 = ""
)

$ErrorActionPreference = "Stop"

# ---- 路径 ----
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DockerDir   = Join-Path $ProjectRoot "docker"
$ConfigsDir  = Join-Path $ProjectRoot "configs"
$EnvFile     = Join-Path $DockerDir ".env"

# ---- 颜色输出 ----
function Write-Info  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "[ OK ]  $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL]  $msg" -ForegroundColor Red }

# ---- Docker 命令检测（兼容 v1/v2）----
function Get-DockerCompose {
    $savedEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    docker compose version 2>&1 | Out-Null
    $exit1 = $LASTEXITCODE
    $ErrorActionPreference = $savedEAP
    if ($exit1 -eq 0) { return "docker compose" }
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) { return "docker-compose" }
    Write-Fail "未找到 docker compose 或 docker-compose"
    exit 1
}

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

# ---- 初始化目录 ----
function Initialize-Dirs {
    @("images","logs\nginx","workspace") | ForEach-Object {
        $p = Join-Path $ProjectRoot $_
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
    $sslDir = Join-Path $ConfigsDir "ssl"
    if (-not (Test-Path $sslDir)) { New-Item -ItemType Directory -Path $sslDir -Force | Out-Null }
}

# ---- 命令函数 ----

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
# 方案C: 不填，启动后在终端执行 claude 完成交互式登录
ANTHROPIC_API_KEY=
ANTHROPIC_BASE_URL=
"@ | Set-Content -Encoding UTF8 $EnvFile
    Write-OK "配置文件已创建 $EnvFile"
    Write-Warn "请编辑该文件配置 API 后再启动"
}

function Invoke-GenSSL {
    Write-Info "生成自签名 SSL 证书..."
    $sslDir = Join-Path $ConfigsDir "ssl"
    New-Item -ItemType Directory -Path $sslDir -Force | Out-Null

    # 优先用 openssl（Git for Windows 自带 / WSL）
    $opensslCmd = $null
    foreach ($candidate in @("openssl","C:\Program Files\Git\usr\bin\openssl.exe")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            $opensslCmd = $candidate; break
        }
    }

    if ($opensslCmd) {
        # openssl 会往 stderr 写信息性消息；临时改为 Continue 避免 Stop 误报
        $savedEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $opensslCmd genrsa -out "$sslDir\server.key" 2048 2>$null
        & $opensslCmd req -new -key "$sslDir\server.key" -out "$sslDir\server.csr" `
            -subj "/C=CN/ST=Beijing/L=Beijing/O=DevOps/CN=dev-server.local" 2>$null
        & $opensslCmd x509 -req -days 365 `
            -in "$sslDir\server.csr" `
            -signkey "$sslDir\server.key" `
            -out "$sslDir\server.crt" 2>$null
        $ErrorActionPreference = $savedEAP
        if ($LASTEXITCODE -ne 0) { Write-Fail "openssl x509 failed (exit $LASTEXITCODE)"; exit 1 }
        Remove-Item "$sslDir\server.csr" -ErrorAction SilentlyContinue
        Write-OK "SSL 证书已生成到 $sslDir"
    } else {
        # 回退：用 PowerShell 内置证书（仅 Windows）
        Write-Warn "未找到 openssl，使用 PowerShell New-SelfSignedCertificate..."
        $cert = New-SelfSignedCertificate `
            -DnsName "dev-server.local","localhost" `
            -CertStoreLocation "Cert:\LocalMachine\My" `
            -NotAfter (Get-Date).AddYears(1)

        # 导出 PFX -> 再拆分为 PEM（需要 openssl，仅作提示）
        $pfxPath = "$sslDir\server.pfx"
        $pwd = ConvertTo-SecureString "devenv" -AsPlainText -Force
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwd | Out-Null
        Write-Warn "已生成 PFX: $pfxPath"
        Write-Warn "Please convert to server.key / server.crt manually with openssl, or install Git for Windows and retry"
    }
}

function Invoke-Build {
    Assert-Docker
    Write-Info "构建镜像..."

    Write-Info "[1/2] 构建 code-server + Claude Code（build context: 项目根目录）"
    docker build `
        -f "$DockerDir\Dockerfile.code-server" `
        -t "code-server-custom:latest" `
        $ProjectRoot
    if ($LASTEXITCODE -ne 0) { Write-Fail "code-server 镜像构建失败"; exit 1 }

    Write-Info "[2/2] Build embedded-dev (full toolchain)"
    docker build `
        -f "$DockerDir\Dockerfile.embedded" `
        -t "embedded-dev-env:latest" `
        $ProjectRoot
    if ($LASTEXITCODE -ne 0) { Write-Fail "embedded-dev 镜像构建失败"; exit 1 }

    Write-OK "All images built"
}

function Invoke-Pull {
    Assert-Docker
    Write-Info "拉取基础镜像..."
    @("nginx:alpine","codercom/code-server:4.21.0","filebrowser/filebrowser:v2.27.0",
      "ubuntu:22.04") | ForEach-Object {
        Write-Info "  拉取 $_"
        docker pull $_
    }
    Write-OK "基础镜像拉取完成"
}

function Invoke-Up {
    Assert-Docker
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

    $dc = Get-DockerCompose
    Set-Location $DockerDir
    Invoke-Expression "$dc up -d"
    Set-Location $ProjectRoot

    Write-OK "Services started"
    Write-Host ""
    Write-Host "  访问地址:" -ForegroundColor Cyan
    Write-Host "    VSCode + Claude: https://localhost:8443" -ForegroundColor White
    Write-Host "    文件管理:        https://localhost:8443/files/" -ForegroundColor White
}

function Invoke-Down {
    Assert-Docker
    $dc = Get-DockerCompose
    Set-Location $DockerDir
    Invoke-Expression "$dc down"
    Set-Location $ProjectRoot
    Write-OK "Services stopped"
}

function Invoke-Status {
    Assert-Docker
    $dc = Get-DockerCompose
    Set-Location $DockerDir
    Invoke-Expression "$dc ps"
    Set-Location $ProjectRoot
}

function Invoke-Logs {
    Assert-Docker
    $dc = Get-DockerCompose
    Set-Location $DockerDir
    if ($Arg1) { Invoke-Expression "$dc logs -f --tail=100 $Arg1" }
    else       { Invoke-Expression "$dc logs -f --tail=100" }
    Set-Location $ProjectRoot
}

function Invoke-Shell {
    Assert-Docker
    if (-not $Arg1) {
        Write-Fail "请指定服务名，例如: .\scripts\manage.ps1 shell code-server"
        exit 1
    }
    $dc = Get-DockerCompose
    Set-Location $DockerDir
    Invoke-Expression "$dc exec $Arg1 /bin/bash"
    Set-Location $ProjectRoot
}

function Invoke-Save {
    Assert-Docker
    $imgDir = Join-Path $ProjectRoot "images"
    New-Item -ItemType Directory -Path $imgDir -Force | Out-Null
    @("nginx:alpine","codercom/code-server:4.21.0","filebrowser/filebrowser:v2.27.0",
      "code-server-custom:latest","embedded-dev-env:latest") | ForEach-Object {
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
        Write-Info "  加载 $($_.Name)"
        docker load -i $_.FullName
    }
    Write-OK "镜像加载完成"
}

function Show-Help {
    Write-Host @"

用法: .\scripts\manage.ps1 <命令> [参数]

命令:
  init          初始化 .env 配置文件
  ssl           生成自签名 SSL 证书
  pull          拉取基础镜像
  build         构建自定义镜像
  up            启动所有服务（自动生成 SSL）
  down          停止所有服务
  status        查看服务状态
  logs [svc]    查看日志（可指定服务名）
  shell <svc>   进入服务 shell（code-server / embedded-dev）
  save          保存镜像到 images\
  load          从 images\ 加载镜像

示例:
  .\scripts\manage.ps1 init
  .\scripts\manage.ps1 build
  .\scripts\manage.ps1 up
  .\scripts\manage.ps1 shell code-server
  .\scripts\manage.ps1 logs code-server
"@
}

# ---- 主入口 ----
Write-Host "=== Agentic 开发环境 (Windows) ===" -ForegroundColor Blue

switch ($Command.ToLower()) {
    "init"   { Initialize-Dirs; Invoke-Init; break }
    "ssl"    { Invoke-GenSSL; break }
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
