# Sandbox System

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Sandbox System                                                              │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Gateway Process (Host)                                                 ││
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
│  │  - Go, Rust                     │  │  Security:                      │  │
│  │  - git, curl, jq                │  │  - Separate from main sandbox   │  │
│  │                                 │  │  - Own network namespace        │  │
│  │  Security:                      │  │                                 │  │
│  │  - network: none                │  │                                 │  │
│  │  - readOnlyRoot: true           │  │                                 │  │
│  │  - user: 1000:1000              │  │                                 │  │
│  │  - capDrop: ALL                 │  │                                 │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                              │
│  Sandbox Images Built:                                                       │
│  1. openclaw-sandbox:bookworm-slim        - Minimal base image              │
│  2. openclaw-sandbox-common:bookworm-slim - With dev tools (DEFAULT)        │
│  3. openclaw-sandbox-browser:bookworm-slim - With Chromium browser          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Default Configuration

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "scope": "agent",
        "workspaceAccess": "rw",
        "workspaceRoot": "~/.openclaw/sandboxes",
        "docker": {
          "image": "openclaw-sandbox-common:bookworm-slim",
          "network": "none",
          "readOnlyRoot": true,
          "user": "1000:1000",
          "capDrop": ["ALL"],
          "memory": "1g",
          "cpus": 1,
          "pidsLimit": 256,
          "env": {
            "LANG": "C.UTF-8",
            "OPENCLAW_GATEWAY_TOKEN": "${OPENCLAW_GATEWAY_TOKEN}"
          }
        },
        "browser": {
          "enabled": true,
          "image": "openclaw-sandbox-browser:bookworm-slim",
          "env": {
            "LANG": "C.UTF-8",
            "OPENCLAW_GATEWAY_TOKEN": "${OPENCLAW_GATEWAY_TOKEN}"
          }
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
        "allow": ["exec", "process", "read", "write", "edit", "apply_patch", 
                  "sessions_*", "browser"],
        "deny": ["canvas", "nodes", "cron", "discord", "gateway"]
      }
    }
  }
}
```

**重要**: 沙箱容器需要 `OPENCLAW_GATEWAY_TOKEN` 环境变量才能与网关通信。部署脚本会自动配置此项。

## Security Model

| Setting | Security Benefit | Capability Trade-off |
|---------|-----------------|---------------------|
| `network: none` | No internet, no data exfiltration | Can't download packages at runtime |
| `readOnlyRoot: true` | Can't modify system files | Can't install software |
| `user: 1000:1000` | No root privileges | Can't access protected files |
| `capDrop: ALL` | No special Linux capabilities | Limited system calls |
| `workspaceAccess: rw` | - | Can read/write workspace files |
| `common` image | - | Has Node/Python/Go/Rust pre-installed |
| Separate browser sandbox | Browser isolated from main sandbox | - |

## Sandbox Images

| Image | Contents | Use Case |
|-------|----------|----------|
| `openclaw-sandbox:bookworm-slim` | Minimal Debian | Maximum security, basic tasks |
| `openclaw-sandbox-common:bookworm-slim` | + Node, Python, Go, Rust, git | **Default** - Development tasks |
| `openclaw-sandbox-browser:bookworm-slim` | + Chromium, CDP, Xvfb | Web automation (separate container) |
