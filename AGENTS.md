# OpenClawOrb - Agent Instructions

OpenClaw OrbStack deployment toolkit. One-click deployment of OpenClaw chatbot platform on macOS via OrbStack.

## Architecture

```
Mac
└── OrbStack
    └── Ubuntu VM (openclaw-vm)
        ├── Gateway process (Node.js, systemd)
        └── Docker (sandbox only)
            ├── sandbox-common
            └── sandbox-browser
```

**Key**: Gateway runs directly on VM (not in Docker), uses Docker CLI to manage sandbox containers.

## Quick Reference

| Component | Technology |
|-----------|------------|
| Runtime | Bash scripts (macOS + Linux VM) |
| Virtualization | OrbStack (lightweight VMs on macOS) |
| Gateway | Node.js 22.x (systemd service) |
| Sandbox | Docker containers |
| Config | `~/.openclaw/openclaw.json` (JSON5) |

## Project Structure

```
OpenClawOrb/
├── openclaw-orbstack-setup.sh    # Main deployment script (8 steps)
├── README.md                     # User documentation
├── AGENTS.md                     # This file
├── templates/
│   └── openclaw.json.example     # OpenClaw config template
├── docs/
│   ├── commands.md               # CLI reference (11 Mac commands + 150 official)
│   ├── architecture.md           # System diagrams
│   ├── configuration-guide.md    # Config guide (Chinese)
│   ├── sandbox.md                # Sandbox security
│   ├── development.md            # Code style
│   └── voice-tts.md              # Voice/TTS features
└── .opencode/                    # OpenCode stubs
```

## Documentation Index

| Doc | Contents |
|-----|----------|
| [docs/commands.md](docs/commands.md) | **CLI reference** - 11 OrbStack commands + 150 official |
| [docs/configuration-guide.md](docs/configuration-guide.md) | Complete config guide (Chinese) |
| [docs/architecture.md](docs/architecture.md) | System overview, deployment flow |
| [docs/troubleshooting.md](docs/troubleshooting.md) | **Troubleshooting** - Bonjour conflicts, port issues |
| [docs/sandbox.md](docs/sandbox.md) | Sandbox security model |

## Key Points for Agents

1. **Main script**: `openclaw-orbstack-setup.sh` (8 deployment steps)
2. **VM name**: `openclaw-vm` (Ubuntu LTS on OrbStack)
3. **Gateway**: systemd service, `node dist/entry.js gateway --port 18789`
4. **CLI**: Globally installed, `openclaw <command>`
5. **Access URL**: `http://openclaw-vm.orb.local:18789`
6. **Config file**: `~/.openclaw/openclaw.json`
7. **Sandbox images**: `sandbox-common`, `sandbox-browser`
8. **Security**: `network: bridge`, `readOnlyRoot: true`, `capDrop: ALL` (Docker containers protect Mac files)
9. **Bonjour disabled**: `OPENCLAW_DISABLE_BONJOUR=1` in systemd to prevent mDNS conflicts with macOS

## Mac Commands (11)

| Command | Function |
|---------|----------|
| `openclaw` | CLI passthrough (all 150+ official commands) |
| `openclaw-telegram` | Telegram management (add/approve) |
| `openclaw-whatsapp` | WhatsApp login |
| `openclaw-config` | Config management |
| `openclaw-status` | Service status |
| `openclaw-logs` | Live logs |
| `openclaw-restart` | Restart service |
| `openclaw-stop/start` | Stop/start service |
| `openclaw-shell` | Enter VM |
| `openclaw-update` | Update version |
