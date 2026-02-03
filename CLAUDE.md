# CLAUDE.md - Project Guide for Claude Code

**Project:** OpenClaw OrbStack — one-click OpenClaw AI chatbot deployment on macOS via OrbStack VM.
**Version:** v2026.2.1 | **License:** MIT

## Architecture

```
☁️  Cloud AI (Anthropic/OpenAI/Google)  ← AI brain
     ↑ API calls
Mac ──────────────────────────────────────
└── OrbStack
    └── Ubuntu VM (openclaw-vm)
        ├── Gateway (Node.js, systemd)    ← orchestrator, NOT in Docker
        └── Docker
            ├── sandbox-common            ← code execution
            └── sandbox-browser           ← Chromium
```

Gateway runs directly on VM. Docker containers are the only isolation protecting Mac files (VM has `/mnt/mac` access).

## Project Structure

- `openclaw-orbstack-setup.sh` — Main entry point (8-step installer, ~715 lines)
- `lang/en.sh`, `lang/zh-CN.sh`, `lang/zh-HK.sh` — i18n message strings (`$MSG_*` variables)
- `templates/openclaw.json.example` — Full JSON5 config template
- `scripts/refresh-mac-commands.sh` — Regenerate `~/bin/openclaw-*` wrappers
- `docs/` — Architecture, commands, config guide, troubleshooting, sandbox, dev guide
- `local/` — Runtime config (gitignored)
- `VERSION` — Current version tracking

## Key Facts

| Item | Value |
|------|-------|
| VM name | `openclaw-vm` |
| Gateway port | `18789` |
| Web console | `http://openclaw-vm.orb.local:18789` |
| Config (in VM) | `~/.openclaw/openclaw.json` |
| Secrets (in VM) | `~/.openclaw/.env` |
| Node.js | 22.x LTS |
| Service | `systemctl --user` (`openclaw-gateway.service`) |
| Gateway cmd | `node dist/entry.js gateway --port 18789` |

## Build / Test / Run

```bash
# Install (interactive language selection)
bash openclaw-orbstack-setup.sh

# Skip language prompt
OPENCLAW_LANG=en bash openclaw-orbstack-setup.sh

# Validate
bash -n openclaw-orbstack-setup.sh          # syntax check
shellcheck openclaw-orbstack-setup.sh       # lint

# Clean reinstall
orb delete openclaw-vm && OPENCLAW_LANG=en bash openclaw-orbstack-setup.sh
```

No automated test suite. Validation is syntax checks + shellcheck + manual testing.

## Coding Conventions

### Bash
- Always `set -e` at top of scripts
- Constants: `UPPER_SNAKE_CASE`
- Functions: `lowercase` for utils, `snake_case` for complex logic
- Quoted heredoc delimiters (`'EOF'`) to prevent expansion; unquoted for expansion
- User-facing text: use `$MSG_*` variables from `lang/*.sh`, never hardcode
- Code comments: English

### JSON Configuration
- Format: JSON5 (comments and trailing commas allowed)
- Indentation: 2 spaces
- Dynamic edits: use `jq`, never sed for JSON/YAML

### i18n
- All user-facing text goes through `lang/*.sh` message strings
- `OPENCLAW_LANG` env var selects language (`en`, `zh-CN`, or `zh-HK`)
- Falls back to English if language file missing

## Anti-Patterns (avoid these)

| Don't | Why | Do Instead |
|-------|-----|------------|
| `sandbox.mode: "off"` | AI accesses Mac via `/mnt/mac` | Keep `mode: "all"` |
| API keys in top-level `env: {}` | Sandbox doesn't inherit Gateway env | Use `sandbox.docker.env` |
| `TELEGRAM_BOT_TOKEN` in sandbox | Reserved by Gateway | Use `TG_BOT_TOKEN` |
| `DISCORD_BOT_TOKEN` in sandbox | Reserved by Gateway | Use `DISCORD_TOKEN` |
| Missing `set -e` | Errors silently continue | Always `set -e` |
| sed for YAML/JSON edits | Silently fails on complex structures | Use `jq` or Python |

## Environment Variable Scopes

Three independent scopes — they do NOT inherit from each other:

| Scope | Config Location | Reaches |
|-------|----------------|---------|
| Gateway | Top-level `env: {}` | Gateway process only |
| Code sandbox | `sandbox.docker.env` | Code execution container |
| Browser sandbox | `sandbox.browser.env` | Browser container |

## Secrets Management (.env)

- `~/.openclaw/.env` stores sensitive values (API keys, bot tokens, Bonjour settings)
- Generated **automatically** during Step 7 (after `openclaw onboard`) by a Python3 extraction script
- Config file (`openclaw.json`) references secrets via `${VAR}` syntax (e.g., `"token": "${TG_BOT_TOKEN}"`)
- Gateway reads `.env` at startup via systemd `EnvironmentFile`
- `openclaw-update` only creates a minimal `.env` (Bonjour vars) if the file is missing — it does NOT re-extract secrets
- File permissions: `chmod 600` (owner-only read/write)

## Reference Docs

| Topic | URL |
|-------|-----|
| OpenCode Zen models | https://opencode.ai/docs/zen/ |
| OpenClaw config | https://docs.openclaw.ai/gateway/configuration |
| OpenClaw model providers | https://docs.openclaw.ai/concepts/model-providers |
| OpenClaw Moonshot provider | https://docs.openclaw.ai/providers/moonshot |

## Git

```bash
# Push with gh token
git push https://aaajiao:$(gh auth token)@github.com/aaajiao/openclaw-orbstack.git main
```

## CI

GitHub Actions runs shellcheck on shell scripts (`.github/workflows/shellcheck.yml`).
