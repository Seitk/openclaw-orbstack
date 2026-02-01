#!/bin/bash
# ============================================================================
# OpenClaw OrbStack One-Click Deployment (Local Install)
#
# Architecture: Gateway runs directly on VM, sandboxes in Docker containers
#
#   Mac
#   └── OrbStack
#       └── Ubuntu VM (openclaw-vm)
#           ├── Gateway process (Node.js, managed by systemd)
#           └── Docker
#               ├── sandbox-common container
#               └── sandbox-browser container
#
# Run in Mac terminal:
#   bash openclaw-orbstack-setup.sh
#
# Prerequisites:
#   - macOS 12.3+
#   - OrbStack installed (https://orbstack.dev)
#
# Language:
#   Interactive selection at startup. Skip prompt with:
#     OPENCLAW_LANG=en bash openclaw-orbstack-setup.sh
#     OPENCLAW_LANG=zh-CN bash openclaw-orbstack-setup.sh
#
# Steps (8 total):
#   1. Check OrbStack
#   2. Create Ubuntu VM
#   3. Install Docker Engine (for sandboxes)
#   4. Install Node.js 22.x LTS
#   5. Clone & build OpenClaw
#   6. Build sandbox images
#   7. Run configuration wizard
#   8. Configure systemd service + Mac commands
#
# ============================================================================

set -e

# --- Language Selection ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

select_language() {
    # If explicitly set via env var, skip interactive prompt
    if [ -n "$OPENCLAW_LANG" ]; then
        echo "$OPENCLAW_LANG"
        return
    fi

    echo ""
    echo "Choose language / 选择语言:"
    echo ""
    echo "  1) English"
    echo "  2) 中文"
    echo ""
    while true; do
        read -rp "Enter 1 or 2 / 输入 1 或 2: " choice
        case "$choice" in
            1) echo "en"; return ;;
            2) echo "zh-CN"; return ;;
            *) echo "  Invalid choice / 无效选择, please enter 1 or 2 / 请输入 1 或 2" ;;
        esac
    done
}

OPENCLAW_LANG_CODE=$(select_language)
LANG_FILE="$SCRIPT_DIR/lang/${OPENCLAW_LANG_CODE}.sh"

if [ -f "$LANG_FILE" ]; then
    # shellcheck source=lang/en.sh
    source "$LANG_FILE"
else
    echo "Warning: Language file $LANG_FILE not found, falling back to English"
    source "$SCRIPT_DIR/lang/en.sh"
fi

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Configuration (override via environment variables) ---
VM_NAME="${OPENCLAW_VM_NAME:-openclaw-vm}"
VM_DISTRO="${OPENCLAW_VM_DISTRO:-ubuntu}"
GATEWAY_PORT="${OPENCLAW_PORT:-18789}"
TOTAL_STEPS=8

# --- Output Functions ---
step()    { echo -e "\n${CYAN}[$1/$TOTAL_STEPS] $2${NC}"; }
ok()      { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
err()     { echo -e "${RED}  ✗ $1${NC}"; }
info()    { echo -e "  $1"; }

# --- VM Command Execution ---
vm_exec() {
    orb -m "$VM_NAME" bash -c "$1"
}

# ============================================================================
# Step 1/8
# ============================================================================
step 1 "$MSG_STEP_1"

if ! command -v orb &> /dev/null; then
    err "$MSG_ERR_NO_ORBSTACK"
    echo ""
    echo "$MSG_INSTALL_ORBSTACK_1"
    echo "$MSG_INSTALL_ORBSTACK_2"
    echo "$MSG_INSTALL_ORBSTACK_3"
    echo "$MSG_INSTALL_ORBSTACK_4"
    exit 1
fi

ok "$MSG_OK_ORBSTACK: $(orb version 2>/dev/null || echo 'unknown')"

# ============================================================================
# Step 2/8
# ============================================================================
step 2 "$MSG_STEP_2"

if orb list 2>/dev/null | grep -q "$VM_NAME"; then
    ok "$(printf "$MSG_OK_VM_EXISTS" "$VM_NAME")"
    if ! orb list 2>/dev/null | grep "$VM_NAME" | grep -q "running"; then
        info "$MSG_INFO_STARTING_VM"
        orb start "$VM_NAME"
    fi
else
    info "$(printf "$MSG_INFO_CREATING_VM" "$VM_NAME" "$VM_DISTRO")"
    orb create "$VM_DISTRO" "$VM_NAME"
fi

sleep 3
ok "$MSG_OK_VM_READY"

# ============================================================================
# Step 3/8
# ============================================================================
step 3 "$MSG_STEP_3"

if vm_exec "command -v docker &> /dev/null"; then
    ok "$MSG_OK_DOCKER_INSTALLED: $(vm_exec 'docker --version' 2>/dev/null)"
else
    info "$MSG_INFO_INSTALLING_DOCKER"
    vm_exec "curl -fsSL https://get.docker.com | sh"
    vm_exec "sudo usermod -aG docker \$USER"
fi

vm_exec "sudo systemctl enable docker && sudo systemctl start docker" || true
ok "$MSG_OK_DOCKER_STARTED"

# ============================================================================
# Step 4/8
# ============================================================================
step 4 "$MSG_STEP_4"

REQUIRED_NODE_MAJOR=22

if vm_exec "command -v node &> /dev/null"; then
    NODE_VERSION=$(vm_exec 'node --version' 2>/dev/null)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge "$REQUIRED_NODE_MAJOR" ]; then
        ok "$MSG_OK_NODE_INSTALLED: $NODE_VERSION"
    else
        info "$(printf "$MSG_INFO_NODE_UPGRADE" "$NODE_VERSION")"
        vm_exec "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
        vm_exec "sudo apt-get install -y nodejs"
        ok "$MSG_OK_NODE_UPGRADED: $(vm_exec 'node --version')"
    fi
else
    info "$MSG_INFO_INSTALLING_NODE"
    vm_exec "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    vm_exec "sudo apt-get install -y nodejs"
    ok "$MSG_OK_NODE_INSTALLED: $(vm_exec 'node --version')"
fi

# Build tools
vm_exec "sudo apt-get install -y build-essential git" || true

# pnpm (required by OpenClaw build)
if vm_exec "command -v pnpm &> /dev/null"; then
    ok "$MSG_OK_PNPM_INSTALLED: $(vm_exec 'pnpm --version')"
else
    info "$MSG_INFO_INSTALLING_PNPM"
    vm_exec "sudo npm install -g pnpm"
    ok "$MSG_OK_PNPM_INSTALLED: $(vm_exec 'pnpm --version')"
fi

# ============================================================================
# Step 5/8
# ============================================================================
step 5 "$MSG_STEP_5"

if vm_exec "test -d ~/openclaw"; then
    info "$MSG_INFO_REPO_EXISTS"
    vm_exec "cd ~/openclaw && git pull"
else
    info "$MSG_INFO_CLONING"
    vm_exec "git clone https://github.com/openclaw/openclaw.git ~/openclaw"
fi

info "$MSG_INFO_NPM_INSTALL"
vm_exec "cd ~/openclaw && npm install"

info "$MSG_INFO_NPM_BUILD"
vm_exec "cd ~/openclaw && npm run build"

info "$MSG_INFO_UI_BUILD"
vm_exec "cd ~/openclaw && pnpm ui:build"

info "$MSG_INFO_GLOBAL_INSTALL"
vm_exec "cd ~/openclaw && sudo npm install -g ."

ok "$MSG_OK_BUILD_DONE"

# ============================================================================
# Step 6/8
# ============================================================================
step 6 "$MSG_STEP_6"

info "$MSG_INFO_SANDBOX_BASE"
if vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null; then
    ok "$MSG_OK_SANDBOX_BASE"
elif vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .'" 2>/dev/null; then
    ok "$MSG_OK_SANDBOX_BASE_DF"
else
    warn "$MSG_WARN_SANDBOX_BASE_FAIL"
fi

info "$MSG_INFO_SANDBOX_BROWSER"
if vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null; then
    ok "$MSG_OK_SANDBOX_BROWSER"
elif vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .'" 2>/dev/null; then
    ok "$MSG_OK_SANDBOX_BROWSER_DF"
else
    warn "$MSG_WARN_SANDBOX_BROWSER_FAIL"
fi

info "$MSG_INFO_SANDBOX_COMMON"
if vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null; then
    ok "$MSG_OK_SANDBOX_COMMON"
else
    warn "$MSG_WARN_SANDBOX_COMMON_FAIL"
fi

# ============================================================================
# Step 7/8
# ============================================================================
step 7 "$MSG_STEP_7"

echo ""
info "$MSG_INFO_ONBOARD_INTRO"
info "$MSG_INFO_ONBOARD_API"
info "$MSG_INFO_ONBOARD_TOKEN"
echo ""
echo -e "${YELLOW}$MSG_PRESS_ENTER${NC}"
read -r

vm_exec "mkdir -p ~/.openclaw"

orb -m "$VM_NAME" openclaw onboard

ok "$MSG_OK_ONBOARD_DONE"

info "$MSG_INFO_CREATING_MEMORY"
vm_exec "mkdir -p ~/.openclaw/memory && chmod 755 ~/.openclaw/memory"
ok "$MSG_OK_MEMORY_CREATED"

# ============================================================================
# Step 8/8
# ============================================================================
step 8 "$MSG_STEP_8"

# --- Create systemd service ---
info "$MSG_INFO_CREATING_SERVICE"

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
Environment=OPENCLAW_DISABLE_BONJOUR=1
Environment=CLAWDBOT_DISABLE_BONJOUR=1

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF"

vm_exec "sudo systemctl daemon-reload"
vm_exec "sudo systemctl enable openclaw"
vm_exec "sudo systemctl start openclaw"

sleep 3

if vm_exec "systemctl is-active openclaw" | grep -q "active"; then
    ok "$MSG_OK_GATEWAY_STARTED"
else
    warn "$MSG_WARN_GATEWAY_ISSUE"
fi

# --- Create Mac convenience commands ---
mkdir -p ~/bin

# Save language preference for generated commands
cat > ~/bin/.openclaw-lang << LANG_EOF
OPENCLAW_LANG=$OPENCLAW_LANG_CODE
LANG_EOF

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

# --- Helper: load language for commands ---
_LANG_LOADER='
# Load language
_OPENCLAW_LANG="en"
if [ -f "$HOME/bin/.openclaw-lang" ]; then source "$HOME/bin/.openclaw-lang"; _OPENCLAW_LANG="${OPENCLAW_LANG:-en}"; fi
_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/.." && pwd)"
_LANG_FILE=""
for _d in "$_SCRIPT_DIR/lang" "/usr/local/share/openclaw/lang" "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/../lang"; do
    if [ -f "$_d/${_OPENCLAW_LANG}.sh" ]; then _LANG_FILE="$_d/${_OPENCLAW_LANG}.sh"; break; fi
done
if [ -n "$_LANG_FILE" ]; then source "$_LANG_FILE"; fi
'

# openclaw (CLI passthrough) - no language needed
cat > ~/bin/openclaw << 'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    set -- "--help"
fi
orb -m openclaw-vm bash -c "openclaw $*"
EOF

# openclaw-config - needs language
cat > ~/bin/openclaw-config << CMDEOF
#!/bin/bash
$_LANG_LOADER
ACTION="\${1:-edit}"

case "\$ACTION" in
    edit)
        echo "\$MSG_CMD_CONFIG_OPENING"
        orb -m openclaw-vm bash -c "nano ~/.openclaw/openclaw.json 2>/dev/null || vi ~/.openclaw/openclaw.json"
        echo "\$MSG_CMD_CONFIG_SAVED"
        ;;
    show)
        orb -m openclaw-vm bash -c "cat ~/.openclaw/openclaw.json"
        ;;
    backup)
        BACKUP="openclaw-config-\$(date +%Y%m%d-%H%M%S).json"
        orb -m openclaw-vm bash -c "cat ~/.openclaw/openclaw.json" > "\$BACKUP"
        printf "\$MSG_CMD_CONFIG_BACKED_UP\n" "\$BACKUP"
        ;;
    *)
        echo "\$MSG_CMD_CONFIG_USAGE"
        ;;
esac
CMDEOF

# openclaw-update - needs language
cat > ~/bin/openclaw-update << CMDEOF
#!/bin/bash
set -e
$_LANG_LOADER

SANDBOX=false
for arg in "\$@"; do
    case "\$arg" in
        --sandbox) SANDBOX=true ;;
        --help|-h)
            echo "\$MSG_CMD_UPDATE_USAGE"
            echo ""
            echo "\$MSG_CMD_UPDATE_DESC"
            echo ""
            echo "\$MSG_CMD_UPDATE_OPTIONS"
            echo "\$MSG_CMD_UPDATE_SANDBOX_OPT"
            echo ""
            echo "\$MSG_CMD_UPDATE_TIP"
            exit 0
            ;;
    esac
done

echo "\$MSG_CMD_UPDATE_UPDATING"

echo "\$MSG_CMD_UPDATE_STOPPING"
orb -m openclaw-vm bash -c "sudo systemctl stop openclaw"

echo "\$MSG_CMD_UPDATE_PULLING"
orb -m openclaw-vm bash -c "cd ~/openclaw && git pull"

echo "\$MSG_CMD_UPDATE_INSTALLING"
orb -m openclaw-vm bash -c "cd ~/openclaw && npm install"

echo "\$MSG_CMD_UPDATE_BUILDING"
orb -m openclaw-vm bash -c "cd ~/openclaw && npm run build"

echo "\$MSG_CMD_UPDATE_UI"
orb -m openclaw-vm bash -c "cd ~/openclaw && pnpm ui:build"

echo "\$MSG_CMD_UPDATE_REINSTALL"
orb -m openclaw-vm bash -c "cd ~/openclaw && sudo npm install -g ."

if [ "\$SANDBOX" = true ]; then
    echo "\$MSG_CMD_UPDATE_SANDBOX_REBUILD"
    echo "\$MSG_CMD_UPDATE_SANDBOX_BASE"
    orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null || true
    echo "\$MSG_CMD_UPDATE_SANDBOX_COMMON"
    orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null || true
    echo "\$MSG_CMD_UPDATE_SANDBOX_BROWSER"
    orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null || true
    echo "\$MSG_CMD_UPDATE_SANDBOX_NOTE"
fi

echo "\$MSG_CMD_UPDATE_STARTING"
orb -m openclaw-vm bash -c "sudo systemctl start openclaw"

echo "\$MSG_CMD_UPDATE_DONE"
if [ "\$SANDBOX" = false ]; then
    echo "\$MSG_CMD_UPDATE_SANDBOX_HINT"
fi
CMDEOF

# openclaw-sandbox-rebuild - needs language
cat > ~/bin/openclaw-sandbox-rebuild << CMDEOF
#!/bin/bash
set -e
$_LANG_LOADER

echo "\$MSG_CMD_REBUILD_START"

echo "\$MSG_CMD_REBUILD_BASE"
if orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null; then
    echo "\$MSG_CMD_REBUILD_BASE_OK"
elif orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .'" 2>/dev/null; then
    echo "\$MSG_CMD_REBUILD_BASE_OK_DF"
else
    echo "\$MSG_CMD_REBUILD_BASE_FAIL"
fi

echo "\$MSG_CMD_REBUILD_COMMON"
if orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null; then
    echo "\$MSG_CMD_REBUILD_COMMON_OK"
else
    echo "\$MSG_CMD_REBUILD_COMMON_FAIL"
fi

echo "\$MSG_CMD_REBUILD_BROWSER"
if orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null; then
    echo "\$MSG_CMD_REBUILD_BROWSER_OK"
elif orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .'" 2>/dev/null; then
    echo "\$MSG_CMD_REBUILD_BROWSER_OK_DF"
else
    echo "\$MSG_CMD_REBUILD_BROWSER_FAIL"
fi

echo ""
echo "\$MSG_CMD_REBUILD_DONE"
echo "\$MSG_CMD_REBUILD_NOTE"
CMDEOF

# openclaw-telegram - needs language
cat > ~/bin/openclaw-telegram << CMDEOF
#!/bin/bash
$_LANG_LOADER
ACTION="\${1:-help}"

case "\$ACTION" in
    add)
        if [ -z "\$2" ]; then
            echo "\$MSG_CMD_TG_ADD_USAGE"
            echo "\$MSG_CMD_TG_ADD_HINT"
            exit 1
        fi
        orb -m openclaw-vm bash -c "openclaw channels add --channel telegram --token \$2"
        ;;
    approve)
        if [ -z "\$2" ]; then
            echo "\$MSG_CMD_TG_APPROVE_USAGE"
            echo "\$MSG_CMD_TG_APPROVE_HINT"
            exit 1
        fi
        orb -m openclaw-vm bash -c "openclaw pairing approve telegram \$2"
        ;;
    *)
        echo "\$MSG_CMD_TG_TITLE"
        echo ""
        echo "\$MSG_CMD_TG_USAGE"
        echo "\$MSG_CMD_TG_ADD_DESC"
        echo "\$MSG_CMD_TG_APPROVE_DESC"
        echo ""
        echo "\$MSG_CMD_TG_ALT"
        echo "\$MSG_CMD_TG_ALT_CMD"
        ;;
esac
CMDEOF

cat > ~/bin/openclaw-whatsapp << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw channels login --channel whatsapp"
EOF

chmod +x ~/bin/openclaw-*
chmod +x ~/bin/openclaw
ok "$MSG_OK_COMMANDS_CREATED"

# --- Write default sandbox configuration ---
info "$MSG_INFO_SANDBOX_CONFIG"

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

ok "$MSG_OK_SANDBOX_CONFIG"

# Check PATH
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
        info "$(printf "$MSG_INFO_PATH_ADDED" "$SHELL_RC")"
    fi
fi

# ============================================================================
# Complete
# ============================================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}$MSG_FINAL_COMPLETE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "$MSG_FINAL_ARCH"
echo "$MSG_FINAL_ARCH_DETAIL_1"
echo "$MSG_FINAL_ARCH_DETAIL_2"
echo "$MSG_FINAL_ARCH_DETAIL_3"
echo ""
echo "$MSG_FINAL_ACCESS: http://${VM_NAME}.orb.local:${GATEWAY_PORT}"
echo ""
echo "$MSG_FINAL_MAC_COMMANDS"
echo ""
echo -e "  ${GREEN}openclaw${NC}              $MSG_FINAL_CMD_CLI"
echo -e "  ${GREEN}openclaw-config${NC}       $MSG_FINAL_CMD_CONFIG"
echo -e "  ${GREEN}openclaw-status${NC}       $MSG_FINAL_CMD_STATUS"
echo -e "  ${GREEN}openclaw-logs${NC}         $MSG_FINAL_CMD_LOGS"
echo -e "  ${GREEN}openclaw-restart${NC}      $MSG_FINAL_CMD_RESTART"
echo -e "  ${GREEN}openclaw-update${NC}       $MSG_FINAL_CMD_UPDATE"
echo -e "  ${GREEN}openclaw-sandbox-rebuild${NC} $MSG_FINAL_CMD_REBUILD"
echo -e "  ${GREEN}openclaw-doctor${NC}       $MSG_FINAL_CMD_DOCTOR"
echo -e "  ${GREEN}openclaw-shell${NC}        $MSG_FINAL_CMD_SHELL"
echo ""
echo "$MSG_FINAL_SANDBOX_TITLE"
echo "$MSG_FINAL_SANDBOX_COMMON"
echo "$MSG_FINAL_SANDBOX_BROWSER"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
