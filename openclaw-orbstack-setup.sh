#!/bin/bash
# ============================================================================
# OpenClaw OrbStack 一键部署脚本 (本地安装版)
#
# 架构: Gateway 直接运行在 VM 上，沙箱在 Docker 容器中
#
#   Mac
#   └── OrbStack
#       └── Ubuntu VM (openclaw-vm)
#           ├── Gateway 进程 (Node.js, systemd 管理)
#           └── Docker
#               ├── sandbox-common 容器
#               └── sandbox-browser 容器
#
# 在 Mac 终端运行：
#   bash openclaw-orbstack-setup.sh
#
# 前置条件：
#   - macOS 12.3+
#   - OrbStack 已安装 (https://orbstack.dev)
#
# 脚本共 8 步：
#   1. 检查 OrbStack         — 确认 orb 命令可用
#   2. 创建 Ubuntu VM        — OrbStack 轻量虚拟机
#   3. 安装 Docker           — VM 内安装 Docker Engine (仅供沙箱使用)
#   4. 安装 Node.js          — 安装 Node.js 20.x LTS
#   5. 克隆并构建 OpenClaw    — 本地编译 (npm install + build)
#   6. 构建沙箱镜像           — sandbox-common + sandbox-browser
#   7. 运行配置向导           — 设置 API Key 和聊天平台
#   8. 配置 systemd 服务      — Gateway 开机自启 + Mac 端快捷命令
#
# ============================================================================

set -e

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 配置 (可通过环境变量覆盖) ---
VM_NAME="${OPENCLAW_VM_NAME:-openclaw-vm}"
VM_DISTRO="${OPENCLAW_VM_DISTRO:-ubuntu}"
GATEWAY_PORT="${OPENCLAW_PORT:-18789}"
TOTAL_STEPS=8

# --- 可选环境变量 ---
# OPENCLAW_VM_NAME            - 虚拟机名称 (默认: openclaw-vm)
# OPENCLAW_VM_DISTRO          - 虚拟机发行版 (默认: ubuntu)
# OPENCLAW_PORT               - 网关端口 (默认: 18789)

# --- 输出函数 ---
step()    { echo -e "\n${CYAN}[$1/$TOTAL_STEPS] $2${NC}"; }
ok()      { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
err()     { echo -e "${RED}  ✗ $1${NC}"; }
info()    { echo -e "  $1"; }

# --- VM 命令执行 ---
vm_exec() {
    orb -m "$VM_NAME" bash -c "$1"
}

# ============================================================================
# 步骤 1/8: 检查 OrbStack
# ============================================================================
step 1 "检查 OrbStack"

if ! command -v orb &> /dev/null; then
    err "未检测到 OrbStack"
    echo ""
    echo "请先安装："
    echo "  1. 访问 https://orbstack.dev 下载安装"
    echo "  2. 启动 OrbStack 完成初始化"
    echo "  3. 重新运行此脚本"
    exit 1
fi

ok "OrbStack 已安装: $(orb version 2>/dev/null || echo 'unknown')"

# ============================================================================
# 步骤 2/8: 创建 Ubuntu VM
# ============================================================================
step 2 "创建 Ubuntu VM"

if orb list 2>/dev/null | grep -q "$VM_NAME"; then
    ok "虚拟机 '$VM_NAME' 已存在"
    if ! orb list 2>/dev/null | grep "$VM_NAME" | grep -q "running"; then
        info "启动虚拟机..."
        orb start "$VM_NAME"
    fi
else
    info "创建虚拟机: $VM_NAME ($VM_DISTRO)"
    orb create "$VM_DISTRO" "$VM_NAME"
fi

sleep 3
ok "虚拟机已就绪"

# ============================================================================
# 步骤 3/8: 安装 Docker Engine (仅供沙箱使用)
# ============================================================================
step 3 "安装 Docker"

if vm_exec "command -v docker &> /dev/null"; then
    ok "Docker 已安装: $(vm_exec 'docker --version' 2>/dev/null)"
else
    info "安装 Docker Engine..."
    vm_exec "curl -fsSL https://get.docker.com | sh"
    vm_exec "sudo usermod -aG docker \$USER"
fi

vm_exec "sudo systemctl enable docker && sudo systemctl start docker" || true
ok "Docker 服务已启动"

# ============================================================================
# 步骤 4/8: 安装 Node.js 20.x LTS
# ============================================================================
step 4 "安装 Node.js"

REQUIRED_NODE_MAJOR=22

if vm_exec "command -v node &> /dev/null"; then
    NODE_VERSION=$(vm_exec 'node --version' 2>/dev/null)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge "$REQUIRED_NODE_MAJOR" ]; then
        ok "Node.js 已安装: $NODE_VERSION"
    else
        info "Node.js $NODE_VERSION 版本过低，升级到 22.x..."
        vm_exec "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
        vm_exec "sudo apt-get install -y nodejs"
        ok "Node.js 已升级: $(vm_exec 'node --version')"
    fi
else
    info "安装 Node.js 22.x..."
    vm_exec "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    vm_exec "sudo apt-get install -y nodejs"
    ok "Node.js 已安装: $(vm_exec 'node --version')"
fi

# 安装构建工具
vm_exec "sudo apt-get install -y build-essential git" || true

# 安装 pnpm (OpenClaw 构建需要)
if vm_exec "command -v pnpm &> /dev/null"; then
    ok "pnpm 已安装: $(vm_exec 'pnpm --version')"
else
    info "安装 pnpm..."
    vm_exec "sudo npm install -g pnpm"
    ok "pnpm 已安装: $(vm_exec 'pnpm --version')"
fi

# ============================================================================
# 步骤 5/8: 克隆并构建 OpenClaw
# ============================================================================
step 5 "克隆并构建 OpenClaw"

if vm_exec "test -d ~/openclaw"; then
    info "仓库已存在，拉取最新代码..."
    vm_exec "cd ~/openclaw && git pull"
else
    info "克隆仓库..."
    vm_exec "git clone https://github.com/openclaw/openclaw.git ~/openclaw"
fi

info "安装依赖 (npm install)..."
vm_exec "cd ~/openclaw && npm install"

info "编译项目 (npm run build)..."
vm_exec "cd ~/openclaw && npm run build"

info "构建 Control UI..."
vm_exec "cd ~/openclaw && pnpm ui:build"

info "全局安装 CLI..."
vm_exec "cd ~/openclaw && sudo npm install -g ."

ok "OpenClaw 构建完成 (CLI: openclaw)"

# ============================================================================
# 步骤 6/8: 构建沙箱 Docker 镜像
# ============================================================================
step 6 "构建沙箱镜像"

info "构建通用沙箱镜像..."
if vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null; then
    ok "sandbox 镜像构建完成"
elif vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .'" 2>/dev/null; then
    ok "sandbox 镜像构建完成 (Dockerfile)"
else
    warn "sandbox 镜像构建失败，跳过"
fi

info "构建浏览器沙箱镜像..."
if vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null; then
    ok "sandbox-browser 镜像构建完成"
elif vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .'" 2>/dev/null; then
    ok "sandbox-browser 镜像构建完成 (Dockerfile)"
else
    warn "sandbox-browser 镜像构建失败，跳过"
fi

info "构建 common 沙箱镜像..."
if vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null; then
    ok "sandbox-common 镜像构建完成"
elif vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-common:bookworm-slim -f Dockerfile.sandbox-common .'" 2>/dev/null; then
    ok "sandbox-common 镜像构建完成 (Dockerfile)"
else
    warn "sandbox-common 镜像构建失败，跳过"
fi

# ============================================================================
# 步骤 7/8: 运行配置向导
# ============================================================================
step 7 "运行配置向导"

echo ""
info "接下来进入交互式配置向导 (onboard)，请准备："
info "  - AI 模型 API Key（支持 Anthropic / OpenAI / OpenRouter 等）"
info "  - Telegram Bot Token (从 @BotFather 获取) 或其他平台凭据"
echo ""
echo -e "${YELLOW}按 Enter 继续...${NC}"
read -r

vm_exec "mkdir -p ~/.openclaw"

orb -m "$VM_NAME" openclaw onboard

ok "配置向导完成"

# ============================================================================
# 步骤 8/8: 配置 systemd 服务 + Mac 端便捷命令
# ============================================================================
step 8 "配置服务与便捷命令"

# --- 创建 systemd 服务 ---
info "创建 systemd 服务..."

VM_USER=$(vm_exec 'whoami')
VM_HOME=$(vm_exec 'echo $HOME')

vm_exec "sudo tee /etc/systemd/system/openclaw.service > /dev/null << 'SYSTEMD_EOF'
[Unit]
Description=OpenClaw Gateway
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=$VM_USER
WorkingDirectory=$VM_HOME/openclaw
ExecStart=/usr/bin/node $VM_HOME/openclaw/dist/entry.js gateway --port 18789
Restart=always
RestartSec=5
KillMode=process
Environment=NODE_ENV=production
Environment=HOME=$VM_HOME

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF"

vm_exec "sudo systemctl daemon-reload"
vm_exec "sudo systemctl enable openclaw"
vm_exec "sudo systemctl start openclaw"

sleep 3

if vm_exec "systemctl is-active openclaw" | grep -q "active"; then
    ok "Gateway 服务已启动"
else
    warn "Gateway 服务启动可能有问题，请检查: openclaw-logs"
fi

# --- 创建 Mac 端便捷命令 ---
mkdir -p ~/bin

cat > ~/bin/openclaw-status << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "systemctl status openclaw"
EOF

cat > ~/bin/openclaw-logs << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "journalctl -u openclaw -f"
EOF

cat > ~/bin/openclaw-restart << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && node dist/entry.js gateway restart"
EOF

cat > ~/bin/openclaw-stop << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && node dist/entry.js gateway stop"
EOF

cat > ~/bin/openclaw-start << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && node dist/entry.js gateway start"
EOF

cat > ~/bin/openclaw-shell << 'EOF'
#!/bin/bash
orb -m openclaw-vm
EOF

cat > ~/bin/openclaw << 'EOF'
#!/bin/bash
# OpenClaw CLI - 透传到 VM 的官方 CLI
if [ $# -eq 0 ]; then
    set -- "--help"
fi
orb -m openclaw-vm bash -c "openclaw $*"
EOF

cat > ~/bin/openclaw-config << 'EOF'
#!/bin/bash
ACTION="${1:-edit}"
CONFIG_PATH="$HOME/.openclaw/openclaw.json"

case "$ACTION" in
    edit)
        echo "正在打开配置编辑器..."
        orb -m openclaw-vm bash -c "nano ~/.openclaw/openclaw.json 2>/dev/null || vi ~/.openclaw/openclaw.json"
        echo "配置已保存。运行 openclaw-restart 使更改生效。"
        ;;
    show)
        orb -m openclaw-vm bash -c "cat ~/.openclaw/openclaw.json"
        ;;
    backup)
        BACKUP="openclaw-config-$(date +%Y%m%d-%H%M%S).json"
        orb -m openclaw-vm bash -c "cat ~/.openclaw/openclaw.json" > "$BACKUP"
        echo "已备份到: $BACKUP"
        ;;
    *)
        echo "用法: openclaw-config [edit|show|backup]"
        ;;
esac
EOF

cat > ~/bin/openclaw-update << 'EOF'
#!/bin/bash
set -e
echo "🔄 正在更新 OpenClaw..."

echo "  停止服务..."
orb -m openclaw-vm bash -c "sudo systemctl stop openclaw"

echo "  拉取最新代码..."
orb -m openclaw-vm bash -c "cd ~/openclaw && git pull"

echo "  安装依赖..."
orb -m openclaw-vm bash -c "cd ~/openclaw && npm install"

echo "  编译项目..."
orb -m openclaw-vm bash -c "cd ~/openclaw && npm run build"

echo "  构建 Control UI..."
orb -m openclaw-vm bash -c "cd ~/openclaw && pnpm ui:build"

echo "  重新安装 CLI..."
orb -m openclaw-vm bash -c "cd ~/openclaw && sudo npm install -g ."

echo "  更新沙箱镜像..."
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null || true
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null || true
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null || true

echo "  启动服务..."
orb -m openclaw-vm bash -c "sudo systemctl start openclaw"

echo "✅ 更新完成！"
EOF

cat > ~/bin/openclaw-telegram << 'EOF'
#!/bin/bash
# Telegram Bot 管理
ACTION="${1:-help}"

case "$ACTION" in
    add)
        if [ -z "$2" ]; then
            echo "用法: openclaw-telegram add <bot_token>"
            echo "从 @BotFather 获取 token"
            exit 1
        fi
        orb -m openclaw-vm bash -c "openclaw channels add --channel telegram --token $2"
        ;;
    approve)
        if [ -z "$2" ]; then
            echo "用法: openclaw-telegram approve <pairing_code>"
            echo "输入 Bot 发给你的配对码"
            exit 1
        fi
        orb -m openclaw-vm bash -c "openclaw pairing approve telegram $2"
        ;;
    *)
        echo "Telegram Bot 管理"
        echo ""
        echo "用法:"
        echo "  openclaw-telegram add <bot_token>      添加 Bot (从 @BotFather 获取)"
        echo "  openclaw-telegram approve <code>       批准配对 (回执验证码)"
        echo ""
        echo "或直接使用:"
        echo "  openclaw channels login --channel telegram"
        ;;
esac
EOF

cat > ~/bin/openclaw-whatsapp << 'EOF'
#!/bin/bash
# WhatsApp 登录 (扫码)
orb -m openclaw-vm bash -c "openclaw channels login --channel whatsapp"
EOF

chmod +x ~/bin/openclaw-*
chmod +x ~/bin/openclaw
ok "便捷命令已创建"

# --- 写入默认沙箱配置 ---
info "写入沙箱配置..."

vm_exec 'cat > /tmp/sandbox-config.json << '\''SANDBOX_EOF'\''
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",
        "scope": "agent",
        "workspaceAccess": "rw",
        "workspaceRoot": "~/.openclaw/sandboxes",
        "docker": {
          "image": "openclaw-sandbox-common:bookworm-slim",
          "containerPrefix": "openclaw-sbx-",
          "workdir": "/workspace",
          "readOnlyRoot": true,
          "tmpfs": ["/tmp:exec,mode=1777", "/var/tmp", "/run"],
          "network": "bridge",
          "user": "501:501",
          "capDrop": ["ALL"],
          "env": {
            "LANG": "C.UTF-8"
          },
          "pidsLimit": 256,
          "memory": "1g",
          "memorySwap": "2g",
          "cpus": 1
        },
        "browser": {
          "enabled": true,
          "image": "openclaw-sandbox-browser:bookworm-slim",
          "autoStart": true,
          "autoStartTimeoutMs": 30000,
          "allowHostControl": true
        },
        "prune": {
          "idleHours": 24,
          "maxAgeDays": 7
        }
      }
    }
  },
  "tools": {
    "sandbox": {
      "tools": {
        "allow": ["group:runtime", "group:fs", "group:sessions", "group:ui"],
        "deny": ["canvas", "nodes", "cron", "gateway", "telegram", "whatsapp", "discord", "googlechat", "slack", "signal", "imessage"]
      }
    }
  },
  "browser": {
    "enabled": true
  }
}
SANDBOX_EOF'

vm_exec 'cd ~/openclaw && python3 << "PYEOF"
import json
import os

config_path = os.path.expanduser("~/.openclaw/openclaw.json")
sandbox_path = "/tmp/sandbox-config.json"

if os.path.exists(config_path):
    with open(config_path, "r") as f:
        config = json.load(f)
    with open(sandbox_path, "r") as f:
        sandbox = json.load(f)
    
    # Deep merge agents.defaults.sandbox
    if "agents" not in config:
        config["agents"] = {}
    if "defaults" not in config["agents"]:
        config["agents"]["defaults"] = {}
    config["agents"]["defaults"]["sandbox"] = sandbox["agents"]["defaults"]["sandbox"]
    
    # Merge tools.sandbox.tools
    if "tools" not in config:
        config["tools"] = {}
    if "sandbox" not in config["tools"]:
        config["tools"]["sandbox"] = {}
    config["tools"]["sandbox"]["tools"] = sandbox["tools"]["sandbox"]["tools"]
    
    # Merge browser
    config["browser"] = sandbox["browser"]
    
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    print("merged")
else:
    print("config not found, skipping sandbox merge")
PYEOF'

ok "沙箱配置已写入"

# 检查 PATH
if ! echo "$PATH" | grep -q "$HOME/bin"; then
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
    
    if ! grep -q 'export PATH="\$HOME/bin:\$PATH"' "$SHELL_RC" 2>/dev/null; then
        echo '' >> "$SHELL_RC"
        echo '# OpenClaw CLI' >> "$SHELL_RC"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
        info "已添加 ~/bin 到 PATH ($SHELL_RC)"
    fi
fi

# ============================================================================
# 完成
# ============================================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "架构:"
echo "  Mac → OrbStack → Ubuntu VM"
echo "                   ├── Gateway (systemd 服务)"
echo "                   └── Docker (沙箱容器)"
echo ""
echo "访问地址: http://${VM_NAME}.orb.local:${GATEWAY_PORT}"
echo ""
echo "Mac 端命令:"
echo ""
echo -e "  ${GREEN}openclaw${NC}              CLI 入口 (透传所有参数)"
echo -e "  ${GREEN}openclaw-config${NC}       编辑配置"
echo -e "  ${GREEN}openclaw-status${NC}       服务状态"
echo -e "  ${GREEN}openclaw-logs${NC}         实时日志"
echo -e "  ${GREEN}openclaw-restart${NC}      重启服务"
echo -e "  ${GREEN}openclaw-update${NC}       更新版本"
echo -e "  ${GREEN}openclaw-doctor${NC}       运行诊断"
echo -e "  ${GREEN}openclaw-shell${NC}        进入 VM"
echo ""
echo "沙箱容器 (由 Gateway 按需创建):"
echo "  - openclaw-sandbox-common   代码执行 (无网络)"
echo "  - openclaw-sandbox-browser  浏览器自动化"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
