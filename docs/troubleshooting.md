# 故障排查指南

## 常见问题

### 1. Bonjour hostname conflict 警告

#### 症状

日志中持续出现以下警告，数字不断递增：

```
gateway hostname conflict resolved; newHostname="openclaw-(127)"
gateway name conflict resolved; newName="openclaw-vm (128)"
gateway hostname conflict resolved; newHostname="openclaw-(128)"
```

#### 原因

这是 OpenClaw 的 [已知 Bug (Issue #3238)](https://github.com/openclaw/openclaw/issues/3238)。

Gateway 使用 `ciao` 库注册 Bonjour/mDNS 服务时，用了系统的 hostname。但在 OrbStack VM 环境中：

1. macOS 的 mDNSResponder 已经占用了这个主机名
2. ciao 探测时发现"冲突"，递增到 `(2)`
3. 再探测又冲突，递增到 `(3)`
4. **无限循环** → 数字一直增长

#### 解决方案

**方法 1：重新运行部署脚本（推荐）**

最新版本的 `openclaw-orbstack-setup.sh` 已经包含了修复，会自动禁用 Bonjour。

```bash
# 重新运行部署脚本会重新生成 systemd 服务文件
bash openclaw-orbstack-setup.sh
```

**方法 2：手动修改 systemd 服务**

```bash
# 进入 VM
openclaw-shell

# 编辑服务文件
sudo nano /etc/systemd/system/openclaw.service

# 在 [Service] 段落添加以下两行：
# Environment=OPENCLAW_DISABLE_BONJOUR=1
# Environment=CLAWDBOT_DISABLE_BONJOUR=1

# 重载并重启
sudo systemctl daemon-reload
sudo pkill -9 openclaw
sudo systemctl start openclaw
```

完整的服务文件示例：

```ini
[Unit]
Description=OpenClaw Gateway
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=<your-username>
WorkingDirectory=/home/<your-username>/openclaw
ExecStart=/usr/bin/node /home/<your-username>/openclaw/dist/entry.js gateway --port 18789
Restart=always
RestartSec=5
KillMode=process
Environment=NODE_ENV=production
Environment=HOME=/home/<your-username>
Environment=OPENCLAW_DISABLE_BONJOUR=1
Environment=CLAWDBOT_DISABLE_BONJOUR=1

[Install]
WantedBy=multi-user.target
```

**验证修复**

检查环境变量是否生效：

```bash
orb -m openclaw-vm bash -c 'cat /proc/$(pgrep -f openclaw-gateway | head -1)/environ | tr "\0" "\n" | grep -i bonjour'
```

应该看到：
```
OPENCLAW_DISABLE_BONJOUR=1
CLAWDBOT_DISABLE_BONJOUR=1
```

#### 影响

禁用 Bonjour 后：
- ✅ 冲突警告消失
- ✅ 减少日志膨胀
- ✅ Gateway 正常工作
- ⚠️ 失去本地网络自动发现功能（一般不需要，可通过 `http://openclaw-vm.orb.local:18789` 直接访问）

#### 参考

- [OpenClaw Issue #3238](https://github.com/openclaw/openclaw/issues/3238)
- [官方文档: Bonjour/mDNS](https://docs.openclaw.ai/gateway/bonjour)

---

### 2. Port 18789 is already in use

#### 症状

```
Port 18789 is already in use.
Gateway failed to start: gateway already running (pid XXX); lock timeout after 5000ms
```

#### 原因

- 已有一个 Gateway 进程在运行
- 或者端口被其他程序占用

#### 解决方案

```bash
# 检查什么占用了端口
orb -m openclaw-vm bash -c 'ss -tlnp | grep 18789'

# 如果是旧的 gateway 进程，强制停止并重启
orb -m openclaw-vm bash -c 'sudo systemctl stop openclaw; sudo pkill -9 openclaw; sudo pkill -9 node; sleep 2; sudo systemctl start openclaw'
```

如果使用 Web UI 时看到这个错误，通常可以忽略 - 这只是说明 systemd 管理的 Gateway 已经在运行。

---

### 3. Gateway already running (使用 Web UI 时)

#### 症状

使用 Web UI 控制台时，日志显示：

```
Gateway failed to start: gateway already running (pid XXX)
Gateway service appears enabled. Stop it first.
```

#### 原因

这是**正常现象**。Web UI 检测到 Gateway 已经由 systemd 管理并运行中，所以不需要再启动。

#### 解决方案

**无需处理** - Gateway 正常工作，Web UI 也能正常使用。这只是信息提示，不是错误。

---

### 4. Memory 目录问题

#### 症状

```
EISDIR: illegal operation on a directory
```

#### 解决方案

```bash
openclaw-shell
mkdir -p ~/.openclaw/memory
chmod 755 ~/.openclaw/memory
exit
openclaw-restart
```

---

### 5. 服务状态检查

#### 常用诊断命令

```bash
# 查看服务状态
openclaw-status

# 查看实时日志
openclaw-logs

# 运行官方诊断
openclaw doctor

# 进入 VM 排查
openclaw-shell

# 查看进程
orb -m openclaw-vm bash -c 'ps aux | grep openclaw'

# 查看端口占用
orb -m openclaw-vm bash -c 'ss -tlnp | grep 18789'

# 查看 systemd 服务配置
orb -m openclaw-vm bash -c 'systemctl show openclaw --property=Environment'
```

---

## 重启服务

### 正常重启

```bash
openclaw-restart
```

### 强制重启（杀死所有进程）

```bash
orb -m openclaw-vm bash -c 'sudo systemctl stop openclaw; sudo pkill -9 openclaw; sudo pkill -9 node; sleep 2; sudo systemctl start openclaw'
```

---

## 完全重置

如果遇到无法解决的问题，可以删除 VM 重新部署：

```bash
# 删除 VM（会丢失所有数据！）
orb delete openclaw-vm

# 重新运行部署脚本
bash openclaw-orbstack-setup.sh
```

⚠️ **注意**：这会丢失所有会话数据和配置，需要重新配对 WhatsApp/Telegram。

---

## 获取帮助

1. 查看日志：`openclaw-logs`
2. 运行诊断：`openclaw doctor`
3. 查看 [官方文档](https://docs.openclaw.ai/gateway/troubleshooting)
4. 搜索 [GitHub Issues](https://github.com/openclaw/openclaw/issues)
