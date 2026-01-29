# Learnings - Fix EBUSY Error

## Session ses_3f4c2a0a4ffePlCovxOdZf4xYa - 2026-01-29T21:02:14.860Z

### Research Findings

**Root Cause Identified**:
- Moltbot's automatic migration from `.clawdbot` → `.moltbot` fails when `.clawdbot` is a Docker bind mount
- The migration happens during container startup, before any override files can take effect

**Official Solution** (PR #3513):
- Set `MOLTBOT_STATE_DIR=/home/node/.clawdbot` BEFORE docker-setup.sh runs
- Pre-create directories with uid 1000 ownership (container node user)

**Previous Failed Attempts**:
- Override file after docker-setup.sh - too late, containers already started
- docker compose down + recreate - EBUSY already logged
- Nested heredocs for override creation - parsing issues

**Key Insight**:
- docker-setup.sh reads `.env` file and merges it with environment
- Pre-populating `.env` with `MOLTBOT_STATE_DIR` prevents migration on first start

## Implementation Complete - 2026-01-29T21:04

### Changes Made

**Approach**: Pre-configuration instead of post-fix workarounds

**File Changes**:
1. Step 7 now pre-creates `.env` with `MOLTBOT_STATE_DIR=/home/node/.clawdbot`
2. Pre-creates directories with uid 1000 ownership BEFORE docker-setup.sh
3. Removed 45 lines of workaround code (docker compose down, override file, etc.)
4. Simplified all convenience commands (no more override detection)

**Result**: Script reduced from 416 lines to 399 lines

**Key Pattern**: When dealing with init scripts that auto-start services, configure environment BEFORE the init script runs, not after.

## [2026-01-29T22:01:56Z] Final Implementation - Session ses_3f4c2a0a4ffePlCovxOdZf4xYa

### Solution: sed patching approach

**Commit**: 5b52bbc - `fix(setup): patch docker-compose.yml directly since -f flag ignores override files`

**Why this works**:
1. docker-setup.sh uses explicit `-f` flags: `docker compose -f docker-compose.yml -f docker-compose.extra.yml up -d`
2. Explicit `-f` flags bypass automatic loading of docker-compose.override.yml
3. Only solution: patch docker-compose.yml AFTER docker-setup.sh creates it

**Implementation**:
```bash
# After docker-setup.sh runs:
vm_exec 'cd ~/moltbot && sg docker -c "docker compose stop"'
vm_exec "cd ~/moltbot && sed -i '/moltbot-gateway:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml"
vm_exec "cd ~/moltbot && sed -i '/moltbot-cli:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml"
vm_exec 'cd ~/moltbot && sg docker -c "docker compose up -d"'
```

**Key Learning**: When upstream scripts use explicit `-f` flags, you cannot rely on Docker Compose's automatic override file loading. You must patch the generated files directly.

### Failed Attempts Summary

| Attempt | Why It Failed | Commit |
|---------|---------------|--------|
| `.env` file | Only does variable substitution in compose file, doesn't pass env vars to containers | 80c8361 |
| `docker-compose.override.yml` | docker-setup.sh uses `-f` flag which ignores override files | 182affa |
| sed patching | ✅ SUCCESS - patches after docker-setup.sh creates the file | 5b52bbc |

### Pattern for Future Reference

**When dealing with third-party setup scripts that use docker compose**:
1. Check if they use explicit `-f` flags (look for `docker compose -f ...`)
2. If yes, override files won't work - you must patch the generated compose file
3. Use sed with proper YAML indentation to inject environment variables
4. Restart containers after patching

**sed pattern for adding env vars to docker-compose.yml**:
```bash
sed -i '/service-name:/,/^  [a-z]/{/environment:/a\      ENV_VAR: value}' docker-compose.yml
```

This matches from the service definition to the next service, finds the environment section, and appends the new variable.
