#!/bin/bash
# repair-existing-install.sh - Unified repair for existing openclaw-orbstack installations
# Fixes both VM-side (systemd service conflict) and Mac-side (stale commands)
#
# Run from Mac host:
#   bash fix/repair-existing-install.sh
#
# What it does:
#   1. Migrates VM from system-level to user-level systemd service
#   2. Updates Mac ~/bin/ commands to use openclaw gateway CLI
#   3. Verifies gateway is running

set -e

# --- Language Selection ---
# Resolve project root reliably (works with bash script.sh, ./script.sh, absolute path, etc.)
_SELF="${BASH_SOURCE[0]:-$0}"
_SELF_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
SCRIPT_DIR="$(cd "$_SELF_DIR/.." && pwd)"

select_language() {
    if [ -n "$OPENCLAW_LANG" ]; then
        echo "$OPENCLAW_LANG"
        return
    fi

    # Check saved preference
    if [ -f "$HOME/bin/.openclaw-lang" ]; then
        local _saved_lang=""
        # shellcheck source=/dev/null
        _saved_lang=$(sed -n 's/^OPENCLAW_LANG=//p' "$HOME/bin/.openclaw-lang" 2>/dev/null || true)
        if [ -n "$_saved_lang" ]; then
            echo "$_saved_lang"
            return
        fi
    fi

    echo "" >&2
    echo "Choose language / 选择语言:" >&2
    echo "" >&2
    echo "  1) English" >&2
    echo "  2) 中文" >&2
    echo "" >&2
    while true; do
        read -rp "Enter 1 or 2 / 输入 1 或 2: " choice
        case "$choice" in
            1) echo "en"; return ;;
            2) echo "zh-CN"; return ;;
            *) echo "  Invalid choice / 无效选择" >&2 ;;
        esac
    done
}

OPENCLAW_LANG_CODE=$(select_language)
LANG_FILE="$SCRIPT_DIR/lang/${OPENCLAW_LANG_CODE}.sh"

if [ -f "$LANG_FILE" ]; then
    # shellcheck source=../lang/en.sh
    source "$LANG_FILE"
else
    echo "Warning: Language file $LANG_FILE not found (SCRIPT_DIR=$SCRIPT_DIR), falling back to English" >&2
    if [ -f "$SCRIPT_DIR/lang/en.sh" ]; then
        source "$SCRIPT_DIR/lang/en.sh"
    else
        echo "Error: No language files found. Make sure you run this from the project directory." >&2
        echo "  cd openclaw-orbstack && bash fix/repair-existing-install.sh" >&2
        exit 1
    fi
fi

VM_NAME="${OPENCLAW_VM_NAME:-openclaw-vm}"

echo ""
echo "$MSG_REPAIR_TITLE"
echo "================================"
echo ""

# --- Step 1: Detect if repair is needed ---
echo "$MSG_REPAIR_DETECTING"

NEEDS_VM_FIX=false
NEEDS_MAC_FIX=false

# Check Mac-side: stale commands
if grep -q "systemctl status openclaw" ~/bin/openclaw-status 2>/dev/null; then
    NEEDS_MAC_FIX=true
fi

# Check VM-side: system-level service exists
if orb -m "$VM_NAME" bash -c "test -f /etc/systemd/system/openclaw.service" 2>/dev/null; then
    NEEDS_VM_FIX=true
fi

if [ "$NEEDS_VM_FIX" = false ] && [ "$NEEDS_MAC_FIX" = false ]; then
    echo "$MSG_REPAIR_NOT_NEEDED"
    exit 0
fi

echo ""

# --- Step 2: VM-side migration ---
if [ "$NEEDS_VM_FIX" = true ]; then
    echo "$MSG_REPAIR_VM_MIGRATING"

    echo "  [1/6] $MSG_REPAIR_VM_STOP_SYSTEM"
    orb -m "$VM_NAME" bash -c "sudo systemctl stop openclaw 2>/dev/null || true"

    echo "  [2/6] $MSG_REPAIR_VM_DISABLE_SYSTEM"
    orb -m "$VM_NAME" bash -c "sudo systemctl disable openclaw 2>/dev/null || true"
    orb -m "$VM_NAME" bash -c "sudo rm -f /etc/systemd/system/openclaw.service && sudo systemctl daemon-reload"

    echo "  [3/6] $MSG_REPAIR_VM_KILL_PORT"
    orb -m "$VM_NAME" bash -c '
        PIDS=$(lsof -t -i :18789 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            kill -9 $PIDS 2>/dev/null || true
            sleep 1
        fi
        rm -f /tmp/openclaw/*.lock /tmp/openclaw/gateway.pid 2>/dev/null || true
    '

    echo "  [4/6] $MSG_REPAIR_VM_ENABLE_LINGER"
    orb -m "$VM_NAME" bash -c 'sudo loginctl enable-linger $(whoami)'

    echo "  [5/6] $MSG_REPAIR_VM_ENABLE_USER"
    orb -m "$VM_NAME" bash -c "systemctl --user enable openclaw-gateway.service 2>/dev/null || true"

    echo "  [6/6] $MSG_REPAIR_VM_START"
    orb -m "$VM_NAME" bash -c "openclaw gateway start"

    echo "  ✓ $MSG_REPAIR_VM_DONE"
    echo ""
fi

# --- Step 3: Mac-side command update ---
if [ "$NEEDS_MAC_FIX" = true ]; then
    echo "$MSG_REPAIR_MAC_UPDATING"

    mkdir -p ~/bin

    cat > ~/bin/openclaw-status << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway status"
EOF

    cat > ~/bin/openclaw-logs << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw logs --follow"
EOF

    cat > ~/bin/openclaw-restart << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway restart"
EOF

    cat > ~/bin/openclaw-stop << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway stop"
EOF

    cat > ~/bin/openclaw-start << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway start"
EOF

    chmod +x ~/bin/openclaw-status ~/bin/openclaw-logs ~/bin/openclaw-restart ~/bin/openclaw-stop ~/bin/openclaw-start

    # Also fix openclaw-update if it has stale systemctl references
    if grep -q "sudo systemctl" ~/bin/openclaw-update 2>/dev/null; then
        sed -i '' 's|orb -m openclaw-vm bash -c "sudo systemctl stop openclaw"|orb -m openclaw-vm bash -c "openclaw gateway stop"|g' ~/bin/openclaw-update
        sed -i '' 's|orb -m openclaw-vm bash -c "sudo systemctl start openclaw"|orb -m openclaw-vm bash -c "openclaw gateway start"|g' ~/bin/openclaw-update
    fi

    echo "  ✓ $MSG_REPAIR_MAC_DONE"
    echo ""
fi

# --- Step 4: Verify ---
echo "$MSG_REPAIR_VERIFY"
sleep 2
orb -m "$VM_NAME" bash -c "openclaw gateway status" || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ $MSG_REPAIR_DONE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$MSG_REPAIR_COMMANDS_HINT"
echo "  openclaw gateway status   - $MSG_FINAL_CMD_STATUS"
echo "  openclaw gateway restart  - $MSG_FINAL_CMD_RESTART"
echo "  openclaw gateway stop     - $MSG_FINAL_CMD_LOGS"
echo ""
echo "$MSG_REPAIR_FULL_REFRESH_HINT"
echo ""
