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
