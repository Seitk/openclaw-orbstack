#!/bin/bash
set -e

# 重新生成 Mac 端 ~/bin/openclaw-* 便捷命令
# 适用于已部署用户更新命令脚本（不影响 VM 和沙箱）
#
# 用法:
#   cd openclaw-orbstack && git pull && bash scripts/refresh-mac-commands.sh

echo "🔄 正在重新生成 Mac 端便捷命令..."

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

SANDBOX=false
for arg in "$@"; do
    case "$arg" in
        --sandbox) SANDBOX=true ;;
        --help|-h)
            echo "用法: openclaw-update [--sandbox]"
            echo ""
            echo "更新 OpenClaw 应用到最新版本。"
            echo ""
            echo "选项:"
            echo "  --sandbox    同时重建沙箱 Docker 镜像"
            echo ""
            echo "提示: 单独重建沙箱可用 openclaw-sandbox-rebuild"
            exit 0
            ;;
    esac
done

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

if [ "$SANDBOX" = true ]; then
    echo "  重建沙箱镜像..."
    echo "    构建基础镜像..."
    orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null || true
    echo "    构建 common 镜像..."
    orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null || true
    echo "    构建浏览器镜像..."
    orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null || true
    echo "  💡 已运行的容器仍使用旧镜像，重启后生效"
fi

echo "  启动服务..."
orb -m openclaw-vm bash -c "sudo systemctl start openclaw"

echo "✅ 更新完成！"
if [ "$SANDBOX" = false ]; then
    echo "💡 如需重建沙箱镜像: openclaw-update --sandbox"
fi
EOF

cat > ~/bin/openclaw-sandbox-rebuild << 'EOF'
#!/bin/bash
set -e
echo "🔨 正在重建沙箱 Docker 镜像..."

# 基础镜像必须先构建（sandbox-common 依赖它）
echo "  构建基础沙箱镜像..."
if orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-setup.sh'" 2>/dev/null; then
    echo "  ✓ sandbox 基础镜像构建完成"
elif orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .'" 2>/dev/null; then
    echo "  ✓ sandbox 基础镜像构建完成 (Dockerfile)"
else
    echo "  ✗ sandbox 基础镜像构建失败（sandbox-common 可能也会失败）"
fi

echo "  构建 common 沙箱镜像..."
if orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null; then
    echo "  ✓ sandbox-common 镜像构建完成"
else
    echo "  ✗ sandbox-common 镜像构建失败"
fi

echo "  构建浏览器沙箱镜像..."
if orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null; then
    echo "  ✓ sandbox-browser 镜像构建完成"
elif orb -m openclaw-vm bash -c "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .'" 2>/dev/null; then
    echo "  ✓ sandbox-browser 镜像构建完成 (Dockerfile)"
else
    echo "  ✗ sandbox-browser 镜像构建失败"
fi

echo ""
echo "✅ 沙箱镜像重建完成！"
echo "💡 已运行的容器仍使用旧镜像，运行 openclaw-restart 使新镜像生效"
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

echo "✅ Mac 端便捷命令已更新！"
echo ""
echo "已生成以下命令:"
echo "  openclaw                CLI 透传"
echo "  openclaw-status         服务状态"
echo "  openclaw-logs           实时日志"
echo "  openclaw-restart        重启服务"
echo "  openclaw-stop/start     停止/启动"
echo "  openclaw-shell          进入 VM"
echo "  openclaw-config         配置管理"
echo "  openclaw-update         更新版本"
echo "  openclaw-sandbox-rebuild 重建沙箱镜像"
echo "  openclaw-telegram       Telegram 管理"
echo "  openclaw-whatsapp       WhatsApp 登录"
echo ""
echo "确保 ~/bin 在 PATH 中: export PATH=\"\$HOME/bin:\$PATH\""
