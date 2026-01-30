# OpenClawOrb - Agent Instructions

OpenClaw OrbStack deployment toolkit. One-click deployment of OpenClaw chatbot platform on macOS via OrbStack + Docker.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Bash scripts (macOS + Linux VM) |
| Virtualization | OrbStack (lightweight VMs on macOS) |
| Containerization | Docker, Docker Compose |
| Target OS | Ubuntu LTS (in OrbStack VM) |
| Config format | JSON (config files), YAML (docker-compose) |

## Project Structure

```
OpenClawOrb/
├── openclaw-orbstack-setup.sh    # Main deployment script (8 steps)
├── README-openclaw-orbstack.md   # Chinese documentation
├── opencode.json.example        # OpenCode project config template
├── .opencode/                   # OpenCode agent/skill/command stubs
│   ├── agents/                  # Custom agent definitions (empty)
│   ├── commands/                # Custom slash commands (empty)
│   ├── skills/                  # Custom skills (empty)
│   ├── plugins/                 # OpenCode plugins (empty)
│   └── oh-my-opencode.json.example
├── .claude/                     # Claude Code configuration stubs
│   ├── agents/                  # Custom agents (empty)
│   ├── commands/                # Custom commands (empty)
│   ├── rules/                   # Custom rules (empty)
│   ├── skills/                  # Custom skills (empty)
│   └── settings.json.example
└── AGENTS.md                    # This file
```

## Development Commands

### No Build/Test System

This is a deployment toolkit - no compilation, linting, or test framework.

```bash
# Validate bash syntax (manual check)
bash -n openclaw-orbstack-setup.sh

# Run shellcheck (if installed)
shellcheck openclaw-orbstack-setup.sh

# Execute deployment (interactive)
bash openclaw-orbstack-setup.sh
```

### OrbStack VM Management (after deployment)

```bash
# Mac-side commands (created by script in ~/bin/)
openclaw-status    # Container status
openclaw-logs      # Live logs
openclaw-restart   # Restart gateway
openclaw-stop      # Stop all containers
openclaw-start     # Start containers
openclaw-shell     # SSH into VM
openclaw-doctor    # Diagnostics

# Direct OrbStack commands
orb list                          # List VMs
orb -m openclaw-vm bash            # Enter VM shell
orb -m openclaw-vm bash -c "..."   # Execute command in VM
```

## Code Style Guidelines

### Bash Scripts

**Shebang & Safety**
```bash
#!/bin/bash
set -e  # Exit on error (REQUIRED)
```

**Variable Naming**
```bash
# Constants: UPPER_SNAKE_CASE
VM_NAME="openclaw-vm"
TOTAL_STEPS=8

# Local variables: lower_snake_case
local config_path="$HOME/.openclaw/config.json"
```

**Function Naming**
```bash
# Short utility functions: lowercase
step()  { echo -e "\n${CYAN}[$1/$TOTAL_STEPS] $2${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
err()   { echo -e "${RED}  ✗ $1${NC}"; }

# Complex functions: snake_case
vm_exec() {
    orb -m "$VM_NAME" bash -c "$1"
}
```

**Color Output**
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Usage
echo -e "${GREEN}Success${NC}"
```

**Quoting**
```bash
# ALWAYS quote variables (especially paths)
vm_exec "cd $HOME/openclaw && docker build ."  # WRONG
vm_exec "cd ~/openclaw && docker build ."      # CORRECT (~ expands in remote shell)

# Use single quotes for literal strings
cat << 'EOF'    # Variables NOT expanded
cat << EOF      # Variables expanded
```

**Heredocs for Multi-line Content**
```bash
# Embed JSON/config in script
cat > config.json << 'EOFCONFIG'
{
  "key": "value"
}
EOFCONFIG
```

### JSON Configuration

**Formatting**
- 2-space indentation
- No trailing commas
- Comments via `//` only in .json files that support them (opencode.json)

**Example Pattern**
```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "docker": {
          "memory": "1g",
          "cpus": 1
        }
      }
    }
  }
}
```

### Documentation

- README files: Chinese (primary audience is Chinese-speaking users)
- Code comments: English
- Inline help in scripts: Chinese for user-facing, English for developer comments

## Error Handling

### Bash Error Patterns

```bash
# Check command exists
if ! command -v orb &> /dev/null; then
    err "未检测到 OrbStack"
    exit 1
fi

# Conditional execution with fallback
vm_exec "some_command" || true  # Don't fail if command fails

# Check file/directory exists
if vm_exec "test -d ~/openclaw"; then
    # directory exists
fi
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Prerequisite missing (OrbStack not installed) |
| Non-zero | Any command failure (due to `set -e`) |

## Security Considerations

### Sandbox Configuration (Reference)

The deployment script creates a secure sandbox config with these defaults:

| Setting | Value | Purpose |
|---------|-------|---------|
| `mode` | `non-main` | Isolate non-primary sessions |
| `network` | `none` | No network access |
| `readOnlyRoot` | `true` | Immutable root filesystem |
| `capDrop` | `ALL` | Drop all Linux capabilities |
| `user` | `1000:1000` | Non-root execution |
| `memory` | `1g` | Memory limit |
| `pidsLimit` | `256` | Process limit |

### Sensitive Files

```bash
# NEVER commit these
.claude/settings.local.json  # Local Claude settings
.opencode/*.local.*          # Local OpenCode settings
~/.openclaw/config.json      # Contains API keys (in VM)
```

## Adding New Features

### New Bash Functions

```bash
# Place helper functions after color definitions, before step functions
new_helper() {
    local arg1="$1"
    # Implementation
}
```

### New Deployment Steps

1. Increment `TOTAL_STEPS` constant
2. Add step with `step N "Description"`
3. Add success message with `ok "Done message"`
4. Test idempotency (script should be re-runnable)

### New Configuration Options

1. Add to `sandbox-config.json` heredoc in script
2. Document in README table
3. Add override example to README "Custom Configuration" section

## Testing Changes

```bash
# Dry run - check syntax only
bash -n openclaw-orbstack-setup.sh

# Full deployment test (requires OrbStack)
# WARNING: Creates real VM and containers
bash openclaw-orbstack-setup.sh

# Clean slate test
orb delete openclaw-vm  # Remove VM
bash openclaw-orbstack-setup.sh  # Fresh install
```

## Common Patterns

### VM Command Execution

```bash
# Simple command
vm_exec "docker ps"

# Multi-line script via heredoc
orb -m "$VM_NAME" bash << 'REMOTE_EOF'
cd ~/openclaw
docker compose up -d
REMOTE_EOF
```

### Docker in VM

```bash
# Use `sg docker` to run as docker group member
vm_exec "sg docker -c 'docker build -t myimage .'"
```

### Idempotent Operations

```bash
# Check before creating
if orb list 2>/dev/null | grep -q "$VM_NAME"; then
    ok "VM already exists"
else
    orb create "$VM_DISTRO" "$VM_NAME"
fi
```

## Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `orb: command not found` | OrbStack not installed | Install from orbstack.dev |
| Docker permission denied | User not in docker group | `sudo usermod -aG docker $USER` |
| EBUSY on rename | Bind mount conflict | Script pre-sets `OPENCLAW_STATE_DIR` to skip migration |
| Container won't start | Config merge failed | Check `openclaw-logs` output |

### Debug Mode

```bash
# Verbose execution
bash -x openclaw-orbstack-setup.sh

# Check VM state
orb -m openclaw-vm bash -c "docker compose -f ~/openclaw/docker-compose.yml config"
```
