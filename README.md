# OpenClaw OrbStack

在 Mac 上通过 OrbStack 一键部署 OpenClaw 聊天机器人平台。

## 架构

```
Mac
└── OrbStack
    └── Ubuntu VM (openclaw-vm)
        ├── Gateway 进程 (Node.js, systemd)
        └── Docker
            ├── sandbox-common (代码执行)
            └── sandbox-browser (浏览器自动化)
```

**优势**:
- ✅ 符合 OpenClaw 官方推荐架构
- ✅ Gateway 能正常管理沙箱容器
- ✅ VM 隔离层保护 Mac 安全

## 前置条件

- macOS 12.3+
- [OrbStack](https://orbstack.dev) 已安装

## 安装

```bash
bash openclaw-orbstack-setup.sh
```

脚本会自动完成：创建 VM → 安装 Docker/Node.js → 构建 OpenClaw → 配置向导 → 启动服务

## 访问

Web 控制台: `http://openclaw-vm.orb.local:18789`

## 快速开始

```bash
# 添加 ~/bin 到 PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# 查看服务状态
openclaw-status

# 查看日志
openclaw-logs

# Telegram Bot 配对
openclaw-telegram add <bot_token>      # 添加 Bot
openclaw-telegram approve <code>       # 回执验证码

# WhatsApp 登录
openclaw-whatsapp

# 编辑配置
openclaw-config edit

# 使用官方 CLI (150+ 命令)
openclaw --help
openclaw status
openclaw channels list
openclaw doctor
```

## Mac 端命令

| 命令 | 功能 |
|------|------|
| `openclaw` | CLI 透传 (所有官方命令) |
| `openclaw-telegram` | Telegram 管理 (add/approve) |
| `openclaw-whatsapp` | WhatsApp 登录 |
| `openclaw-config` | 配置管理 |
| `openclaw-status` | 服务状态 |
| `openclaw-logs` | 实时日志 |
| `openclaw-restart` | 重启服务 |
| `openclaw-stop/start` | 停止/启动服务 |
| `openclaw-shell` | 进入 VM |
| `openclaw-update` | 更新版本 |

完整命令参考见 [docs/commands.md](docs/commands.md)

## 配置

配置文件: `~/.openclaw/openclaw.json` (VM 内)

```bash
openclaw-config edit     # 编辑
openclaw-config show     # 查看
openclaw-config backup   # 备份
```

详细配置说明见 [docs/configuration-guide.md](docs/configuration-guide.md)

## 故障排查

```bash
openclaw-status        # 服务状态
openclaw-logs          # 查看日志
openclaw doctor        # 运行诊断
openclaw-shell         # 进入 VM 排查
```

## 文档

| 文档 | 内容 |
|------|------|
| [docs/commands.md](docs/commands.md) | CLI 命令完整参考 |
| [docs/architecture.md](docs/architecture.md) | 架构说明 |
| [docs/configuration-guide.md](docs/configuration-guide.md) | 配置指南 |
| [docs/sandbox.md](docs/sandbox.md) | 沙箱安全 |
| [docs/voice-tts.md](docs/voice-tts.md) | 语音功能 |

## License

MIT
