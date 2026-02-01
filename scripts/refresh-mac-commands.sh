#!/bin/bash
set -e

# Regenerate Mac ~/bin/openclaw-* convenience commands
# For existing users to update command scripts (does not affect VM or sandbox)
#
# Usage:
#   cd openclaw-orbstack && git pull && bash scripts/refresh-mac-commands.sh

# --- Language Selection ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
    # shellcheck source=../lang/en.sh
    source "$LANG_FILE"
else
    echo "Warning: Language file $LANG_FILE not found, falling back to English"
    source "$SCRIPT_DIR/lang/en.sh"
fi

echo "$MSG_REFRESH_START"

mkdir -p ~/bin

# Save language preference
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

cat > ~/bin/openclaw << 'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    set -- "--help"
fi
orb -m openclaw-vm bash -c "openclaw $*"
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

echo "$MSG_REFRESH_DONE"
echo ""
echo "$MSG_REFRESH_LIST_HEADER"
echo "$MSG_REFRESH_CMD_CLI"
echo "$MSG_REFRESH_CMD_STATUS"
echo "$MSG_REFRESH_CMD_LOGS"
echo "$MSG_REFRESH_CMD_RESTART"
echo "$MSG_REFRESH_CMD_STARTSTOP"
echo "$MSG_REFRESH_CMD_SHELL"
echo "$MSG_REFRESH_CMD_CONFIG"
echo "$MSG_REFRESH_CMD_UPDATE"
echo "$MSG_REFRESH_CMD_REBUILD"
echo "$MSG_REFRESH_CMD_TELEGRAM"
echo "$MSG_REFRESH_CMD_WHATSAPP"
echo ""
echo "$MSG_REFRESH_PATH_HINT"
