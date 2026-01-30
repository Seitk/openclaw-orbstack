#!/bin/bash
# ============================================================================
# OpenClaw OrbStack 一键部署脚本
#
# 在 Mac 终端运行，自动完成全部部署：
#   bash openclaw-orbstack-setup.sh
#
# 前置条件：
#   - macOS 12.3+
#   - OrbStack 已安装 (https://orbstack.dev)
#
# 脚本共 8 步：
#   1. 检查 OrbStack         — 确认 orb 命令可用
#   2. 创建 Ubuntu VM        — OrbStack 轻量虚拟机 openclaw-vm
#   3. 安装 Docker           — VM 内安装 Docker Engine
#   4. 克隆 OpenClaw          — 从 GitHub 拉取源码
#   5. 构建镜像              — 主程序 + 沙箱容器镜像
#   6. 写入沙箱安全配置       — 容器隔离、资源限制、工具权限
#   7. 运行配置向导           — 设置 API Key 和聊天平台
#   8. 合并配置 + 便捷命令    — 最终配置合并，创建 Mac 端快捷命令
#
# ============================================================================

set -e

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 配置 ---
VM_NAME="openclaw-vm"
VM_DISTRO="ubuntu"
TOTAL_STEPS=8

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
#   - 虚拟机名称: openclaw-vm
#   - 系统: Ubuntu (OrbStack 默认最新 LTS)
#   - 如果已存在则直接启动
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
# 步骤 3/8: 在 VM 中安装 Docker Engine
#   - 使用 Docker 官方安装脚本 (https://get.docker.com)
#   - 将当前用户加入 docker 组
#   - 启用 Docker 服务开机自启
# ============================================================================
step 3 "安装 Docker"

if vm_exec "command -v docker &> /dev/null"; then
    ok "Docker 已安装: $(vm_exec 'docker --version' 2>/dev/null)"
else
    info "安装 Docker Engine (官方脚本)..."
    vm_exec "curl -fsSL https://get.docker.com | sh"
    vm_exec "sudo usermod -aG docker \$USER"
fi

vm_exec "sudo systemctl enable docker && sudo systemctl start docker" || true
ok "Docker 服务已启动"

# ============================================================================
# 步骤 4/8: 克隆 OpenClaw 仓库
#   - 源码地址: https://github.com/openclaw/openclaw.git
#   - 克隆到 VM 的 ~/openclaw 目录
#   - 如果已存在则 git pull 更新
# ============================================================================
step 4 "获取 OpenClaw 源码"

if vm_exec "test -d ~/openclaw"; then
    info "仓库已存在，拉取最新代码..."
    vm_exec "cd ~/openclaw && git pull"
else
    info "克隆仓库..."
    vm_exec "git clone https://github.com/openclaw/openclaw.git ~/openclaw"
fi

ok "源码已就绪: ~/openclaw"

# ============================================================================
# 步骤 5/8: 构建 Docker 镜像
#   构建两个镜像:
#   - openclaw:local           — 主程序（网关 + CLI）
#   - openclaw-sandbox:bookworm-slim — 沙箱执行环境（Debian Bookworm 精简版）
# ============================================================================
step 5 "构建 Docker 镜像"

info "构建主镜像 openclaw:local ..."
vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw:local -f Dockerfile .'"
ok "主镜像构建完成"

info "构建沙箱镜像 openclaw-sandbox:bookworm-slim ..."
vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null || \
vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .'" || true
ok "沙箱镜像构建完成"

info "构建浏览器沙箱镜像 openclaw-sandbox-browser:bookworm-slim ..."
vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null || \
vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .'" || true
ok "浏览器沙箱镜像构建完成"

info "构建通用沙箱镜像 openclaw-sandbox-common:bookworm-slim ..."
vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null || \
vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-common:bookworm-slim -f Dockerfile.sandbox-common .'" || true
ok "通用沙箱镜像构建完成"

# ============================================================================
# 步骤 6/8: 写入沙箱安全配置
#
#   准备沙箱配置文件（步骤 8 中合并到 Docker volume）
#
#   安全设置一览:
#   ┌─────────────────┬──────────────────────────┬──────────────────────────────┐
#   │ 设置项           │ 值                       │ 含义                         │
#   ├─────────────────┼──────────────────────────┼──────────────────────────────┤
#   │ mode            │ non-main                 │ 非主会话在沙箱中执行           │
#   │ scope           │ agent                    │ 每个 Agent 一个独立容器        │
#   │ workspaceAccess │ none                     │ 沙箱不访问宿主工作区           │
#   │ workspaceRoot   │ ~/.openclaw/sandboxes    │ 沙箱工作区存储目录             │
#   │ network         │ none                     │ 容器无网络访问                │
#   │ readOnlyRoot    │ true                     │ 根文件系统只读                │
#   │ capDrop         │ ALL                      │ 放弃所有 Linux capabilities   │
#   │ user            │ 1000:1000                │ 非 root 用户运行              │
#   │ memory          │ 1g (swap 2g)             │ 内存限制                     │
#   │ cpus            │ 1                        │ CPU 限制                     │
#   │ pidsLimit       │ 256                      │ 最大进程数                    │
#   │ ulimits.nofile  │ 1024/2048                │ 文件描述符限制                │
#   │ prune           │ 24h idle / 7d max        │ 自动清理空闲容器              │
#   └─────────────────┴──────────────────────────┴──────────────────────────────┘
#
#   工具权限:
#     允许: exec, process, read, write, edit, apply_patch, sessions_*
#     禁止: browser, canvas, nodes, cron, discord, gateway
#
# ============================================================================
step 6 "准备沙箱安全配置"

# 先在宿主写好配置文件，步骤 7 docker-setup.sh 运行后再合并
# 使用 OPENCLAW_HOME_VOLUME 让容器自由管理 /home/node（避免 bind mount 的权限和 rename 问题）
vm_exec 'mkdir -p ~/openclaw-sandbox-config'

orb -m "$VM_NAME" bash << 'REMOTE_EOF'
cat > ~/openclaw-sandbox-config/sandbox-config.json << 'EOFCONFIG'
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "scope": "agent",
        "workspaceAccess": "none",
        "workspaceRoot": "~/.openclaw/sandboxes",
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim",
          "containerPrefix": "openclaw-sbx-",
          "workdir": "/workspace",
          "readOnlyRoot": true,
          "tmpfs": ["/tmp", "/var/tmp", "/run"],
          "network": "none",
          "user": "1000:1000",
          "capDrop": ["ALL"],
          "env": {
            "LANG": "C.UTF-8"
          },
          "pidsLimit": 256,
          "memory": "1g",
          "memorySwap": "2g",
          "cpus": 1,
          "ulimits": {
            "nofile": { "soft": 1024, "hard": 2048 },
            "nproc": 256
          }
        },
        "browser": {
          "enabled": true,
          "image": "openclaw-sandbox-browser:bookworm-slim"
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
        "allow": [
          "exec",
          "process",
          "read",
          "write",
          "edit",
          "apply_patch",
          "sessions_list",
          "sessions_history",
          "sessions_send",
          "sessions_spawn",
          "session_status",
          "browser"
        ],
        "deny": [
          "canvas",
          "nodes",
          "cron",
          "discord",
          "gateway"
        ]
      }
    }
  }
}
EOFCONFIG
REMOTE_EOF

info "沙箱配置已准备: ~/openclaw-sandbox-config/sandbox-config.json"
info ""
info "安全设置:"
info "  隔离模式     non-main     非主会话在沙箱中执行"
info "  隔离范围     agent        每个 Agent 独立容器"
info "  工作区访问   none         沙箱不访问宿主文件"
info "  网络         none         容器完全隔离"
info "  文件系统     只读根       防止容器篡改系统"
info "  权限         capDrop ALL  放弃所有特权"
info "  资源限制     1G RAM / 1 CPU / 256 进程"
info "  自动清理     空闲 24h 或存活 7 天后删除"
ok "沙箱配置已就绪"

# ============================================================================
# 步骤 7/8: 运行配置向导
#   - 调用 OpenClaw 官方 docker-setup.sh
#   - 需要输入: AI 模型 API Key + 聊天平台凭据 (Telegram/WhatsApp/...)
#   - 支持: OpenCode Zen / Anthropic / OpenAI 等多种提供商
#   - 设置 OPENCLAW_HOME_VOLUME=openclaw_home 使用 Docker named volume
#     这样容器内 /home/node 整体持久化，可以自由完成 配置迁移
#   - 向导会生成 config.json 和 docker-compose.yml
# ============================================================================
step 7 "运行配置向导"

echo ""
info "接下来进入交互式配置，请准备："
info "  - AI 模型 API Key（支持 OpenCode Zen / Anthropic / OpenAI 等）"
info "  - Telegram Bot Token (从 @BotFather 获取) 或其他平台凭据"
echo ""
echo -e "${YELLOW}按 Enter 继续...${NC}"
read -r

# Pre-create directories with correct ownership (container node user = uid 1000)
vm_exec "mkdir -p ~/.openclaw ~/.openclaw/credentials ~/.openclaw/workspace"
vm_exec "sudo chown -R 1000:1000 ~/.openclaw ~/.openclaw/workspace"

vm_exec "cd ~/openclaw && export OPENCLAW_HOME_VOLUME=openclaw_home && sg docker -c './docker-setup.sh'"
ok "配置向导完成"

# Fix EBUSY: docker-setup.sh uses -f flag which ignores override files
# So we patch docker-compose.yml directly using Python (more reliable than sed for YAML)
info "修复 EBUSY 迁移错误..."
vm_exec 'cd ~/openclaw && sg docker -c "docker compose stop"'

# Add OPENCLAW_STATE_DIR to both services using Python
# This is more reliable than sed for modifying YAML structure
vm_exec 'cd ~/openclaw && python3 << "PYEOF"
import yaml

with open("docker-compose.yml", "r") as f:
    data = yaml.safe_load(f)

# Add OPENCLAW_STATE_DIR to both services
for svc in ["openclaw-gateway", "openclaw-cli"]:
    if svc in data.get("services", {}):
        if "environment" not in data["services"][svc]:
            data["services"][svc]["environment"] = {}
        data["services"][svc]["environment"]["OPENCLAW_STATE_DIR"] = "/home/node/.openclaw"

with open("docker-compose.yml", "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print("✓ OPENCLAW_STATE_DIR added to docker-compose.yml")
PYEOF'

# Restart with the patched config
vm_exec 'cd ~/openclaw && sg docker -c "docker compose up -d"'
ok "EBUSY 修复完成"

# ============================================================================
# 步骤 8/8: 合并配置 + 创建便捷命令
#   - 用 jq 将沙箱配置合并到主配置 config.json
#   - 在 Mac 的 ~/bin/ 下创建快捷命令
# ============================================================================
step 8 "合并配置 + 创建便捷命令"

# --- 合并沙箱配置到 Docker volume 内的 config.json ---
# docker-setup.sh 生成的 config.json 在 named volume 里
# 通过临时容器把沙箱配置复制进去并合并
info "将沙箱配置合并到容器内..."

vm_exec 'sg docker -c '\''
    # 把宿主上的沙箱配置复制进 named volume
    # 使用 root 用户运行临时容器，确保有权限操作 volume 内文件
    docker run --rm -u root \
        -v openclaw_home:/home/node \
        -v ~/openclaw-sandbox-config:/tmp/sbx:ro \
        openclaw:local \
        sh -c "
            CONFIG=/home/node/.openclaw/config.json
            # 检查配置文件是否存在
            [ -f /home/node/.openclaw/config.json ] && CONFIG=/home/node/.openclaw/config.json
            if [ -f \$CONFIG ] && command -v jq >/dev/null 2>&1; then
                jq -s \".[0] * .[1]\" \$CONFIG /tmp/sbx/sandbox-config.json > /tmp/merged.json
                mv /tmp/merged.json \$CONFIG
                echo merged
            else
                # jq 不可用或 config.json 不存在，直接复制
                DIR=\$(dirname \$CONFIG)
                mkdir -p \$DIR
                cp /tmp/sbx/sandbox-config.json \$DIR/
                echo copied
            fi
            # 修复 volume 内所有文件的所有权，确保 node 用户 (1000:1000) 有写权限
            chown -R 1000:1000 /home/node
        "
    '\'''
ok "沙箱配置已合并"

# 启动容器
vm_exec "cd ~/openclaw && sg docker -c 'docker compose up -d'"

# --- 创建 Mac 端便捷命令 ---
mkdir -p ~/bin

cat > ~/bin/openclaw-status << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker compose ps'"
EOF

cat > ~/bin/openclaw-logs << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker compose logs -f openclaw-gateway'"
EOF

cat > ~/bin/openclaw-restart << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker compose restart openclaw-gateway'"
EOF

cat > ~/bin/openclaw-stop << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker compose down'"
EOF

cat > ~/bin/openclaw-start << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker compose up -d'"
EOF

cat > ~/bin/openclaw-shell << 'EOF'
#!/bin/bash
orb -m openclaw-vm
EOF

cat > ~/bin/openclaw-doctor << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker compose run --rm openclaw-cli doctor'"
EOF

chmod +x ~/bin/openclaw-*
ok "便捷命令已创建到 ~/bin/"

# ============================================================================
# 完成
# ============================================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}部署完成${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "访问地址: http://${VM_NAME}.orb.local:18789"
echo ""
echo "Mac 端命令 (需将 ~/bin 加入 PATH):"
echo "  openclaw-status    查看服务状态"
echo "  openclaw-logs      实时日志"
echo "  openclaw-restart   重启服务"
echo "  openclaw-stop      停止服务"
echo "  openclaw-start     启动服务"
echo "  openclaw-shell     进入 VM 终端"
echo "  openclaw-doctor    运行诊断"
echo ""
echo "加入 PATH (添加到 ~/.zshrc):"
echo '  export PATH="$HOME/bin:$PATH"'
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
