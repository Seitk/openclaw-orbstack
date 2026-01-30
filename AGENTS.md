# OpenClawOrb - Agent Instructions

**Generated:** 2026-01-30 | **Commit:** ff012af | **Branch:** main

OpenClaw OrbStack deployment toolkit. One-click OpenClaw chatbot deployment on macOS via OrbStack VM.

## Architecture

```
Mac
└── OrbStack
    └── Ubuntu VM (openclaw-vm)
        ├── Gateway process (Node.js, systemd)  ← NOT in Docker
        └── Docker (sandbox only)
            ├── sandbox-common (code execution)
            └── sandbox-browser (Chromium)
```

**Critical**: Gateway runs directly on VM. Docker containers are the ONLY isolation layer protecting Mac files (VM has `/mnt/mac` access).

## Structure

```
OpenClawOrb/
├── openclaw-orbstack-setup.sh    # Main entry (573 lines, 8-step installer)
├── README.md                     # User docs (Chinese)
├── AGENTS.md                     # This file
├── templates/
│   └── openclaw.json.example     # Config template (JSON5, 899 lines)
├── docs/
│   ├── commands.md               # CLI reference (11 Mac + 150 official)
│   ├── architecture.md           # System diagrams
│   ├── configuration-guide.md    # Config guide (Chinese)
│   ├── sandbox.md                # Sandbox security model
│   ├── troubleshooting.md        # Known issues + fixes
│   ├── development.md            # Code style guide
│   └── voice-tts.md              # Voice/TTS features
└── local/                        # Runtime config (gitignored)
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| **Main logic** | `openclaw-orbstack-setup.sh` | Single monolithic script |
| **Mac CLI wrappers** | Lines 287-428 in setup script | Generated to `~/bin/` at install |
| **systemd service** | Lines 248-270 in setup script | Embedded as heredoc |
| **Sandbox config** | Lines 433-485 in setup script | JSON merged via embedded Python |
| **Config template** | `templates/openclaw.json.example` | Full JSON5 with comments |
| **Troubleshooting** | `docs/troubleshooting.md` | Bonjour fix, port conflicts |
| **Security model** | `docs/sandbox.md` | Docker isolation, env vars |

## Key Facts

| Item | Value |
|------|-------|
| VM name | `openclaw-vm` |
| Gateway port | `18789` |
| Access URL | `http://openclaw-vm.orb.local:18789` |
| Config file | `~/.openclaw/openclaw.json` (in VM) |
| Gateway command | `node dist/entry.js gateway --port 18789` |
| Node.js version | 22.x LTS |

## Mac Commands (11)

| Command | Function |
|---------|----------|
| `openclaw` | CLI passthrough (all 150+ official commands) |
| `openclaw-telegram` | Telegram management (add/approve) |
| `openclaw-whatsapp` | WhatsApp QR login |
| `openclaw-config` | Config management (edit/show/backup) |
| `openclaw-status` | Service status |
| `openclaw-logs` | Live logs |
| `openclaw-restart` | Restart service |
| `openclaw-stop/start` | Stop/start service |
| `openclaw-shell` | Enter VM terminal |
| `openclaw-update` | Update version |

## Conventions

### Bash Scripts
```bash
#!/bin/bash
set -e                           # REQUIRED - exit on error

# Constants: UPPER_SNAKE_CASE
VM_NAME="openclaw-vm"

# Functions: lowercase for utils, snake_case for complex
step()    { echo -e "..."; }
vm_exec() { orb -m "$VM_NAME" bash -c "$1"; }

# Heredocs: quoted delimiter = no expansion
cat > file << 'EOF'
$VAR stays literal
EOF
```

### JSON Configuration
- Format: JSON5 (comments + trailing commas OK)
- Indentation: 2 spaces
- Dynamic edits: use `jq`

### Documentation
- README/user-facing: Chinese
- Code comments: English

## Anti-Patterns (NEVER DO)

| Anti-Pattern | Why | Correct Approach |
|--------------|-----|------------------|
| `sandbox.mode: "off"` | AI accesses Mac via `/mnt/mac` | Keep `mode: "all"` |
| API keys in top-level `env: {}` | Sandbox doesn't inherit Gateway env | Use `sandbox.docker.env` |
| `TELEGRAM_BOT_TOKEN` in sandbox | Reserved by Gateway | Use `TG_BOT_TOKEN` |
| `DISCORD_BOT_TOKEN` in sandbox | Reserved by Gateway | Use `DISCORD_TOKEN` |
| Missing `set -e` in bash | Errors silently continue | Always `set -e` |
| sed for YAML modification | Silently fails on complex YAML | Use Python + PyYAML |

## Environment Variables

### Three Independent Scopes
| Scope | Location | Reaches |
|-------|----------|---------|
| Gateway | Top-level `env: {}` | Gateway process only |
| Main sandbox | `sandbox.docker.env` | Code execution container |
| Browser sandbox | `sandbox.browser.env` | Browser container |

**They do NOT inherit from each other.**

### Deployment Variables
| Variable | Purpose | Default |
|----------|---------|---------|
| `OPENCLAW_VM_NAME` | VM name | `openclaw-vm` |
| `OPENCLAW_PORT` | Gateway port | `18789` |
| `OPENCLAW_DISABLE_BONJOUR` | Prevent mDNS conflicts | `1` (set in systemd) |

## Git Operations

```bash
# Push using gh token (avoids credential issues)
git push https://aaajiao:$(gh auth token)@github.com/aaajiao/openclaw-orbstack.git main
```

## Testing

No automated tests. Validation approach:
```bash
bash -n openclaw-orbstack-setup.sh     # Syntax check
shellcheck openclaw-orbstack-setup.sh  # Lint (if installed)
bash -x openclaw-orbstack-setup.sh     # Debug trace
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Bonjour hostname conflict | Already fixed via `OPENCLAW_DISABLE_BONJOUR=1` in systemd |
| Port 18789 in use | `sudo pkill -9 openclaw && sudo systemctl start openclaw` |
| Memory directory error | `mkdir -p ~/.openclaw/memory && chmod 755 ~/.openclaw/memory` |
| Browser sandbox fails | Ensure `tmpfs: ["/tmp:exec,mode=1777"]` in config |

See [docs/troubleshooting.md](docs/troubleshooting.md) for full guide.
