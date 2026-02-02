# OpenClaw Gateway 服务冲突修复说明

## 问题描述

`openclaw-orbstack-setup.sh` 脚本创建了一个**系统级** systemd 服务，同时 `openclaw onboard` 又创建了一个**用户级**服务，导致两个服务同时尝试启动 gateway，产生端口冲突和重启循环。

### 冲突的两个服务

| 服务类型 | 路径 | 创建者 |
|---------|------|--------|
| 系统级 | `/etc/systemd/system/openclaw.service` | setup 脚本手动创建 |
| 用户级 | `~/.config/systemd/user/openclaw-gateway.service` | `openclaw onboard` 自动创建 |

### 症状

- `openclaw gateway status` 显示 `Runtime: stopped`，但 `RPC probe: ok`
- 日志中反复出现 "Port 18789 is already in use"
- `openclaw gateway restart` 导致服务冲突

## 解决方案

### 方案一：修复现有安装（推荐）

在 VM 中执行以下命令，切换到官方推荐的用户级服务：

```bash
# 1. 停止并禁用系统级服务
sudo systemctl stop openclaw
sudo systemctl disable openclaw

# 2. 可选：删除系统级服务文件
sudo rm /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload

# 3. 确认端口已释放
lsof -i :18789

# 4. 启用用户级服务
systemctl --user enable openclaw-gateway.service

# 5. 启动 gateway
openclaw gateway start

# 6. 确认状态
openclaw gateway status
```

成功后 `openclaw gateway status` 应显示 `Runtime: running`。

### 方案二：更新 Mac 命令脚本

如果选择使用用户级服务，需要更新 Mac 上的命令脚本：

```bash
# 更新 openclaw-status
cat > ~/bin/openclaw-status << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway status"
EOF

# 更新 openclaw-logs
cat > ~/bin/openclaw-logs << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw logs --follow"
EOF

# 更新 openclaw-restart
cat > ~/bin/openclaw-restart << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway restart"
EOF

# 更新 openclaw-stop
cat > ~/bin/openclaw-stop << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway stop"
EOF

# 更新 openclaw-start
cat > ~/bin/openclaw-start << 'EOF'
#!/bin/bash
orb -m openclaw-vm bash -c "openclaw gateway start"
EOF

chmod +x ~/bin/openclaw-*
```

## 紧急修复脚本

当遇到端口冲突/僵尸进程时，在 VM 中运行：

```bash
#!/bin/bash
# openclaw-fix.sh

set -e

PORT=18789
LOCK_DIR="/tmp/openclaw"

echo "🦞 OpenClaw Gateway 修复脚本"
echo "============================"

# 1. 停止 systemd 服务（两种都尝试）
echo "[1/5] 停止 systemd 服务..."
systemctl --user stop openclaw-gateway.service 2>/dev/null || true
sudo systemctl stop openclaw 2>/dev/null || true

# 2. 杀掉占用端口的进程
echo "[2/5] 检查端口 $PORT..."
PIDS=$(lsof -t -i :$PORT 2>/dev/null || true)
if [ -n "$PIDS" ]; then
    echo "      发现进程: $PIDS"
    kill -9 $PIDS 2>/dev/null || true
    sleep 1
else
    echo "      端口空闲"
fi

# 3. 清理 lock 文件
echo "[3/5] 清理 lock 文件..."
rm -f "$LOCK_DIR"/*.lock "$LOCK_DIR"/gateway.pid 2>/dev/null || true

# 4. 确认端口已释放
echo "[4/5] 确认端口已释放..."
if lsof -i :$PORT >/dev/null 2>&1; then
    echo "      ⚠️  端口仍被占用"
    lsof -i :$PORT
    exit 1
else
    echo "      ✓ 端口已释放"
fi

# 5. 启动 gateway
echo "[5/5] 启动 gateway..."
openclaw gateway start

echo ""
echo "✓ 完成！"
openclaw gateway status
```

## 根本修复：更新 setup 脚本

问题根源是 `openclaw-orbstack-setup.sh` 第 283-309 行手动创建了系统级服务。

**修改方案**：删除手动创建 systemd 服务的代码，改用 OpenClaw 官方的用户级服务。

主要改动：
1. 删除 `/etc/systemd/system/openclaw.service` 的创建代码
2. 添加 `systemctl --user enable openclaw-gateway.service` 启用官方服务
3. 更新 Mac 命令脚本使用 `openclaw gateway` 命令而非 `systemctl`

详见 `openclaw-orbstack-setup-fixed.sh`。

## 两种服务的区别

| 特性 | 系统级服务 | 用户级服务（推荐） |
|------|-----------|-------------------|
| 路径 | `/etc/systemd/system/` | `~/.config/systemd/user/` |
| 管理命令 | `sudo systemctl` | `systemctl --user` 或 `openclaw gateway` |
| 启动时机 | 系统启动时 | 用户登录时 |
| 权限 | 需要 root | 普通用户 |
| OpenClaw 兼容 | ❌ `openclaw gateway` 命令不工作 | ✅ 完全兼容 |

## 一键修复脚本（推荐）

对于已安装用户，提供了统一修复脚本，从 Mac 主机运行，同时修复 VM 端和 Mac 端：

```bash
# 在项目目录下运行
bash fix/repair-existing-install.sh
```

该脚本会自动：
1. 检测是否需要修复
2. 迁移 VM 中的 systemd 服务（系统级 → 用户级）
3. 更新 Mac 端 `~/bin/` 命令
4. 验证 gateway 状态

也可以直接运行 `openclaw-update`，更新命令会自动检测并修复旧版配置。

## 相关 GitHub Issues

- [#3815](https://github.com/openclaw/openclaw/issues/3815) - Gateway crashes repeatedly, stale lock files
- [#5103](https://github.com/openclaw/openclaw/issues/5103) - Migration leaves system in broken state
- [#3780](https://github.com/openclaw/openclaw/issues/3780) - gateway stop uses bootout, breaking subsequent start
