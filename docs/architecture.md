# Architecture

## System Overview (本地安装版)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  macOS Host                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  OrbStack VM (openclaw-vm) - Ubuntu LTS                                 ││
│  │                                                                          ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │  Gateway 进程 (Node.js, systemd 管理)                            │    ││
│  │  │  - Web UI :18789                                                 │    ││
│  │  │  - API Gateway                                                   │    ││
│  │  │  - Session Management                                            │    ││
│  │  │  - 直接调用 docker 命令管理沙箱容器                                │    ││
│  │  └───────────────────────────┬─────────────────────────────────────┘    ││
│  │                              │ docker exec/create/start                  ││
│  │                              ▼                                           ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │  Docker Engine (仅供沙箱使用)                                     │    ││
│  │  │  ┌─────────────────────┐  ┌─────────────────────┐               │    ││
│  │  │  │ sandbox-common      │  │ sandbox-browser     │               │    ││
│  │  │  │ (代码执行)           │  │ (浏览器自动化)       │               │    ││
│  │  │  │                     │  │                     │               │    ││
│  │  │  │ - exec/read/write   │  │ - Chromium          │               │    ││
│  │  │  │ - network: none     │  │ - CDP protocol      │               │    ││
│  │  │  │ - 完全隔离           │  │ - 可访问网络         │               │    ││
│  │  │  └─────────────────────┘  └─────────────────────┘               │    ││
│  │  └─────────────────────────────────────────────────────────────────┘    ││
│  │                                                                          ││
│  │  Files in VM:                                                            ││
│  │  - ~/openclaw/          Git repo (Node.js 源码)                         ││
│  │  - ~/.openclaw/         配置、会话、工作区                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  Mac-side commands: ~/bin/openclaw-*                                        │
│  Access URL: http://openclaw-vm.orb.local:18789                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Why This Architecture?

**官方推荐**: OpenClaw 设计为 Gateway 运行在宿主机，通过 Docker CLI 管理沙箱容器。

**安全优势**: 相比直接在 Mac 上运行，我们多了一层 VM 隔离：

| 攻击场景 | 直接安装 | OrbStack 架构 |
|---------|---------|--------------|
| 沙箱逃逸 | 危及 Mac | 只到 VM |
| Gateway 漏洞 | 危及 Mac | 只到 VM |
| 恶意代码 | 访问 Mac 文件 | 只访问 VM |
| 最坏情况 | 重装系统 | 删除 VM |

## Deployment Flow

```
Step 1: Check OrbStack
    │   Verify orb command exists on Mac
    ▼
Step 2: Create Ubuntu VM
    │   orb create ubuntu openclaw-vm
    ▼
Step 3: Install Docker
    │   curl -fsSL https://get.docker.com | sh
    │   (仅供沙箱容器使用)
    ▼
Step 4: Install Node.js
    │   Node.js 20.x LTS + build-essential
    ▼
Step 5: Clone & Build OpenClaw
    │   git clone + npm install + npm run build
    ▼
Step 6: Build Sandbox Images
    │   ├── openclaw-sandbox:bookworm-slim
    │   ├── openclaw-sandbox-browser:bookworm-slim
    │   └── openclaw-sandbox-common:bookworm-slim
    ▼
Step 7: Run Setup Wizard
    │   ./openclaw setup (interactive)
    │   - Configure AI provider API keys
    │   - Configure chat channels
    ▼
Step 8: Configure systemd + Commands
        - Create openclaw.service (auto-start)
        - Create ~/bin/openclaw-* commands on Mac
        - Merge sandbox config
```

## Files Created

### In VM (~/)

```
~/openclaw/                    # Git repo (源码)
  ├── dist/                    # 编译后的代码
  ├── node_modules/            # 依赖
  ├── package.json
  └── ...

~/.openclaw/                   # 配置目录
  ├── openclaw.json            # 主配置 (含沙箱设置)
  ├── credentials/             # API keys, tokens
  ├── workspace/               # Agent workspace
  └── sandboxes/               # Sandbox workspaces
```

### systemd Service

```
/etc/systemd/system/openclaw.service
  - ExecStart: node dist/gateway/index.js
  - Restart: on-failure
  - User: <vm-user>
```

### On Mac (~/bin/)

```
~/bin/
  ├── openclaw               # CLI 入口 (透传参数)
  ├── openclaw-config        # 编辑配置
  ├── openclaw-status        # systemctl status
  ├── openclaw-logs          # journalctl -f
  ├── openclaw-restart       # systemctl restart
  ├── openclaw-stop          # systemctl stop
  ├── openclaw-start         # systemctl start
  ├── openclaw-shell         # 进入 VM
  ├── openclaw-doctor        # 运行诊断
  └── openclaw-update        # 更新版本
```

## Gateway ↔ Sandbox Communication

```
Gateway (VM 进程)
    │
    │  docker create/start/exec
    │  (直接调用 Docker CLI)
    ▼
┌─────────────────────────────────────────┐
│  Docker Engine                          │
│                                         │
│  sandbox-common        sandbox-browser  │
│  ┌─────────────┐      ┌─────────────┐  │
│  │ network:none│      │ network:yes │  │
│  │ 代码执行     │      │ 浏览器控制   │  │
│  │ 完全隔离     │      │ CDP 协议    │  │
│  └─────────────┘      └─────────────┘  │
└─────────────────────────────────────────┘
```

- **代码沙箱**: `network: none`，通过 Docker exec API 通信
- **浏览器沙箱**: 需要网络，通过 CDP (Chrome DevTools Protocol) 通信
