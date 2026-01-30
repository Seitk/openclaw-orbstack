# Sandbox System

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Sandbox System                                                              │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Gateway Process (VM Host)                                              ││
│  │  - Receives user messages                                               ││
│  │  - Manages AI model calls                                               ││
│  │  - Dispatches tool execution to sandboxes                               ││
│  └───────────────────────────────────┬─────────────────────────────────────┘│
│                                      │                                       │
│                    ┌─────────────────┴─────────────────┐                    │
│                    ▼                                   ▼                    │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │  Main Sandbox Container         │  │  Browser Sandbox Container      │  │
│  │  (openclaw-sandbox-common)      │  │  (openclaw-sandbox-browser)     │  │
│  │                                 │  │                                 │  │
│  │  Tools:                         │  │  Tools:                         │  │
│  │  - exec (run commands)          │  │  - browser (web automation)     │  │
│  │  - read/write/edit (files)      │  │                                 │  │
│  │  - process (manage processes)   │  │  Features:                      │  │
│  │                                 │  │  - Chromium + CDP               │  │
│  │  Pre-installed:                 │  │  - Xvfb (headful mode)          │  │
│  │  - Node.js, npm                 │  │  - noVNC (optional)             │  │
│  │  - Python 3                     │  │                                 │  │
│  │  - Go, Rust                     │  │                                 │  │
│  │  - git, curl, jq                │  │                                 │  │
│  │                                 │  │                                 │  │
│  │  Security:                      │  │  Security:                      │  │
│  │  - network: bridge              │  │  - network: bridge              │  │
│  │  - readOnlyRoot: true           │  │  - Separate from main sandbox   │  │
│  │  - user: 501:501                │  │  - autoStart: true              │  │
│  │  - capDrop: ALL                 │  │                                 │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                              │
│  Sandbox Images Built:                                                       │
│  1. openclaw-sandbox:bookworm-slim        - Minimal base image              │
│  2. openclaw-sandbox-common:bookworm-slim - With dev tools (DEFAULT)        │
│  3. openclaw-sandbox-browser:bookworm-slim - With Chromium browser          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Why Docker Sandbox? (Important)

**OrbStack VM does NOT provide isolation from Mac!**

| Component | Mac Filesystem Access | Network Access |
|-----------|----------------------|----------------|
| OrbStack VM | ✅ Full access via `/mnt/mac` | ✅ Full |
| Docker Container | ❌ Only mounted `/workspace` | ✅ Bridge network |

Docker containers are the **only isolation layer** protecting your Mac files:

```
Mac 文件系统 (/Users/*, Documents, Photos...)
     ↓ 自动挂载到
/mnt/mac (OrbStack VM 可完全访问)
     ↓ 但是
Docker 容器看不到！只能看到 /workspace
```

**不要设置 `sandbox.mode: "off"`** — 那样 AI 可以通过 `/mnt/mac` 访问你整个 Mac！

## Default Configuration

```json
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
          "network": "bridge",
          "readOnlyRoot": true,
          "tmpfs": ["/tmp:exec,mode=1777", "/var/tmp", "/run"],
          "user": "501:501",
          "capDrop": ["ALL"],
          "memory": "1g",
          "cpus": 1,
          "pidsLimit": 256,
          "env": {
            "LANG": "C.UTF-8",
            "OPENAI_API_KEY": "sk-xxx",
            "GOOGLE_API_KEY": "AIzaSyxxx"
          }
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
```

## Security Model

| Setting | Security Benefit | Trade-off |
|---------|-----------------|-----------|
| `network: bridge` | Browser can access internet | Code execution has network (acceptable - Mac files still protected) |
| `readOnlyRoot: true` | Can't modify system files | Can't install software |
| `user: 501:501` | Match macOS user permissions | - |
| `capDrop: ALL` | No special Linux capabilities | Limited system calls |
| `tmpfs: /tmp:exec` | Playwright can execute in /tmp | - |
| `workspaceAccess: rw` | - | Can read/write workspace files only |
| Docker isolation | **Mac filesystem protected** | Only sees mounted workspace |

### Network Configuration Options

| Value | Behavior | Use Case |
|-------|----------|----------|
| `bridge` | Full network access | **Default** - Browser automation works |
| `none` | No network | Maximum isolation (browser won't work) |
| `host` | Share host network | Not recommended |

**为什么默认 `bridge` 而不是 `none`？**

- 浏览器自动化需要网络访问
- 真正的安全边界是**文件系统隔离**，不是网络
- Docker 容器看不到 Mac 文件，即使有网络访问

### Sandbox Mode Options

| Mode | Behavior | Browser Works? | Recommendation |
|------|----------|----------------|----------------|
| `off` | 不使用沙箱，直接在 VM 执行 | ❌ (VM 没有 GUI 浏览器) | **危险** - AI 可访问 `/mnt/mac` |
| `non-main` | 只有非主会话使用沙箱 | ⚠️ 只有 non-main sessions | 主会话无法用 sandbox browser |
| `all` | 所有会话都使用沙箱 | ✅ 全部可用 | **推荐** |

**为什么默认 `all` 而不是 `non-main`？**

- `non-main` 模式下，main session 直接在 VM 里运行
- VM 没有安装 GUI 浏览器，所以 main session 无法使用浏览器功能
- `all` 模式让所有会话都在 Docker 沙箱里运行，可以使用 sandbox-browser

### Tool Groups (Sandbox Permissions)

| Group | Tools Included |
|-------|---------------|
| `group:runtime` | exec, bash, process |
| `group:fs` | read, write, edit, apply_patch |
| `group:sessions` | sessions_list, sessions_history, sessions_send, sessions_spawn, session_status |
| `group:ui` | browser, canvas |

默认配置允许 `group:ui`（包含 browser），但 deny 了 `canvas`。

## Sandbox Images

| Image | Contents | Use Case |
|-------|----------|----------|
| `openclaw-sandbox:bookworm-slim` | Minimal Debian | Maximum security, basic tasks |
| `openclaw-sandbox-common:bookworm-slim` | + Node, Python, Go, Rust, git | **Default** - Development tasks |
| `openclaw-sandbox-browser:bookworm-slim` | + Chromium, CDP, Xvfb | Web automation (separate container) |

## Browser Sandbox Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | 启用浏览器沙箱 |
| `autoStart` | `true` | 自动启动浏览器容器 |
| `autoStartTimeoutMs` | `30000` | 启动超时时间 (毫秒) |
| `allowHostControl` | `true` | 允许 `target="host"` 访问宿主浏览器 |

## Troubleshooting

### Browser sandbox 启动失败

检查容器日志：
```bash
docker logs openclaw-sbx-browser-agent-main-*
```

常见问题：
- `/tmp` 只读 → 确保 tmpfs 包含 `/tmp:exec,mode=1777`
- CDP 端口映射失败 → 删除旧容器重启

### 清理沙箱容器

```bash
# 删除所有沙箱容器
docker rm -f $(docker ps -aq --filter "name=openclaw-sbx") 2>/dev/null || true

# 重启 gateway
openclaw-restart
```

## Environment Variables (重要)

**沙箱容器不会继承 Gateway 的环境变量！** 如果需要在沙箱内使用 API Key，必须在 `sandbox.docker.env` 中显式配置。

### 配置位置说明

| 配置位置 | 作用域 | 示例用途 |
|---------|--------|---------|
| 顶层 `env: {}` | Gateway 进程 | Gateway 内部使用的变量 |
| `sandbox.docker.env` | Main sandbox 容器 | 代码执行时需要的 API Key |
| `sandbox.browser.env` | Browser sandbox 容器 | 浏览器自动化需要的变量 |

**三个位置是独立的，不会自动继承。**

### 正确配置示例

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "docker": {
          "env": {
            "LANG": "C.UTF-8",
            "OPENAI_API_KEY": "sk-xxx",
            "ANTHROPIC_API_KEY": "sk-ant-xxx",
            "GOOGLE_API_KEY": "AIzaSyxxx"
          }
        },
        "browser": {
          "env": {
            "LANG": "C.UTF-8",
            "OPENAI_API_KEY": "sk-xxx"
          }
        }
      }
    }
  }
}
```

### 常见错误

❌ **错误**: 在顶层 `env` 配置 API Key，期望沙箱能用

```json
{
  "env": {
    "OPENAI_API_KEY": "sk-xxx"  // 这只给 Gateway 用，沙箱看不到！
  }
}
```

✅ **正确**: 在 `sandbox.docker.env` 配置

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "docker": {
          "env": {
            "OPENAI_API_KEY": "sk-xxx"  // 沙箱容器可以使用
          }
        }
      }
    }
  }
}
```
