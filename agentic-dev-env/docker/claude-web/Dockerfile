# ============================================================
# Claude Code Web 服务
# 将 Claude Code CLI 包装为 Web 服务
# ============================================================

FROM node:20-slim

# 安装必要依赖
RUN apt-get update && apt-get install -y \
    git \
    curl \
    vim \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 安装 Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# 创建工作目录
WORKDIR /app

# 创建简单的 Web 包装服务
RUN cat > server.js << 'EOF'
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const WORKSPACE = process.env.WORKSPACE_DIR || '/workspace';

// 简单的 HTML 界面
const HTML_TEMPLATE = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Claude Code</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1e1e1e;
            color: #d4d4d4;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .header { 
            background: #2d2d30; 
            padding: 10px 20px;
            border-bottom: 1px solid #3e3e42;
        }
        .header h1 { 
            font-size: 16px; 
            color: #fff;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .container { 
            flex: 1; 
            display: flex; 
            overflow: hidden;
        }
        .sidebar { 
            width: 250px; 
            background: #252526;
            border-right: 1px solid #3e3e42;
            padding: 20px;
        }
        .sidebar h3 { 
            font-size: 12px; 
            text-transform: uppercase;
            color: #858585;
            margin-bottom: 10px;
        }
        .sidebar .info { 
            font-size: 13px; 
            line-height: 1.6;
        }
        .main { 
            flex: 1; 
            display: flex;
            flex-direction: column;
            padding: 20px;
        }
        .status { 
            background: #2d2d30;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 20px;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            padding: 5px 0;
            border-bottom: 1px solid #3e3e42;
        }
        .status-item:last-child { border-bottom: none; }
        .status-label { color: #858585; }
        .status-value { color: #4ec9b0; }
        .actions {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .btn {
            background: #0e639c;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 13px;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 5px;
        }
        .btn:hover { background: #1177bb; }
        .btn-secondary {
            background: #3c3c3c;
        }
        .btn-secondary:hover { background: #4c4c4c; }
        .terminal {
            flex: 1;
            background: #1e1e1e;
            border: 1px solid #3e3e42;
            border-radius: 6px;
            padding: 15px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 13px;
            overflow: auto;
            white-space: pre-wrap;
            margin-top: 20px;
        }
        .note {
            background: #1e3a5f;
            border-left: 3px solid #3794ff;
            padding: 15px;
            margin-top: 20px;
            border-radius: 0 4px 4px 0;
            font-size: 13px;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🤖 Claude Code</h1>
    </div>
    <div class="container">
        <div class="sidebar">
            <h3>配置</h3>
            <div class="info">
                <p><strong>工作目录:</strong></p>
                <p style="color:#858585;word-break:break-all;">${WORKSPACE}</p>
                <br>
                <p><strong>模型:</strong></p>
                <p style="color:#858585;">${process.env.CLAUDE_CODE_MODEL || 'default'}</p>
            </div>
        </div>
        <div class="main">
            <div class="status">
                <div class="status-item">
                    <span class="status-label">服务状态</span>
                    <span class="status-value">运行中</span>
                </div>
                <div class="status-item">
                    <span class="status-label">API 端点</span>
                    <span class="status-value">${process.env.ANTHROPIC_BASE_URL || '默认'}</span>
                </div>
            </div>
            
            <div class="actions">
                <a href="/" class="btn">🏠 返回 Code Server</a>
                <a href="/api/llm/" class="btn btn-secondary">🔌 API 文档</a>
            </div>
            
            <div class="note">
                <strong>使用说明:</strong><br>
                Claude Code 需要通过终端使用。请在 Code Server 中打开终端，运行 <code>claude</code> 命令。<br><br>
                <strong>常用命令:</strong><br>
                • <code>claude</code> - 启动交互式会话<br>
                • <code>claude <file></code> - 让 Claude 编辑文件<br>
                • <code>claude config set model <model></code> - 切换模型
            </div>
            
            <div class="terminal">
> Agentic Dev Environment v1.0
> Claude Code Web Interface
> 
> 提示: 在 Code Server 终端中运行 'claude' 开始使用
            </div>
        </div>
    </div>
</body>
</html>
`;

const server = http.createServer((req, res) => {
    if (req.url === '/' || req.url === '/index.html') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(HTML_TEMPLATE);
    } else if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', service: 'claude-web' }));
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
});

server.listen(PORT, HOST, () => {
    console.log(`Claude Web server running at http://${HOST}:${PORT}/`);
});
EOF

EXPOSE 3000

CMD ["node", "server.js"]
