# Fix EBUSY Error in Moltbot OrbStack Deployment

## TL;DR

> **Quick Summary**: Fix the EBUSY error by setting `MOLTBOT_STATE_DIR` environment variable BEFORE `docker-setup.sh` runs, preventing the `.clawdbot` → `.moltbot` migration that fails on bind mounts.
> 
> **Deliverables**:
> - Modified `moltbot-orbstack-setup.sh` with pre-configuration approach
> - Remove unnecessary post-setup workarounds
> 
> **Estimated Effort**: Quick
> **Critical Path**: Single file modification

---

## Context

### Original Request
Fix the persistent EBUSY error:
```
Failed to move legacy state dir (/home/node/.clawdbot → /home/node/.moltbot): 
Error: EBUSY: resource busy or locked, rename '/home/node/.clawdbot' -> '/home/node/.moltbot'
```

### Research Findings

**GitHub Issue**: [#3480](https://github.com/moltbot/moltbot/issues/3480) - Docker install permission/EBUSY error
**Official Fix**: [PR #3513](https://github.com/moltbot/moltbot/pull/3513) - Add MOLTBOT_STATE_DIR to resolve error

**Root Cause**:
1. `docker-setup.sh` creates directories and starts containers
2. Container starts → Moltbot tries to migrate `.clawdbot` → `.moltbot`
3. `.clawdbot` is a bind mount point → `fs.renameSync()` fails with EBUSY
4. Our previous fix (override file AFTER docker-setup.sh) was too late

**Solution from PR #3513**:
- Set `MOLTBOT_STATE_DIR` environment variable BEFORE containers start
- This tells Moltbot to skip the migration entirely

### Why Previous Attempts Failed

| Attempt | Why It Failed |
|---------|---------------|
| Override file after docker-setup.sh | Too late - containers already started |
| docker compose down + recreate | EBUSY already logged during first start |
| CLAWDBOT_STATE_DIR in override | Same timing issue |

---

## Work Objectives

### Core Objective
Set `MOLTBOT_STATE_DIR=/home/node/.clawdbot` in `.env` file BEFORE `docker-setup.sh` runs.

### Definition of Done
- [ ] `moltbot doctor` shows no EBUSY warning on fresh install
- [ ] No manual intervention required

### Must Have
- Pre-create `.env` with `MOLTBOT_STATE_DIR` before docker-setup.sh
- Pre-create directories with correct permissions (uid 1000)

### Must NOT Have
- Post-setup workarounds (override file, docker compose down, etc.)
- Complex timing-dependent fixes

---

## TODOs

- [x] 1. Modify step 7 in moltbot-orbstack-setup.sh

  **What to do**:
  
  Replace the entire step 7 section (lines ~281-325) with:
  
  ```bash
  step 7 "运行配置向导"

  echo ""
  info "接下来进入交互式配置，请准备："
  info "  - AI 模型 API Key（支持 OpenCode Zen / Anthropic / OpenAI 等）"
  info "  - Telegram Bot Token (从 @BotFather 获取) 或其他平台凭据"
  echo ""
  echo -e "${YELLOW}按 Enter 继续...${NC}"
  read -r

  # Pre-configure .env to prevent EBUSY (PR #3513 approach)
  info "预配置环境变量（防止 EBUSY 迁移错误）..."
  vm_exec "echo 'MOLTBOT_STATE_DIR=/home/node/.clawdbot' >> ~/moltbot/.env"

  # Pre-create directories with correct ownership (container node user = uid 1000)
  vm_exec "mkdir -p ~/.clawdbot ~/.clawdbot/credentials ~/clawd"
  vm_exec "sudo chown -R 1000:1000 ~/.clawdbot ~/clawd"

  vm_exec "cd ~/moltbot && export CLAWDBOT_HOME_VOLUME=moltbot_home && sg docker -c './docker-setup.sh'"
  ok "配置向导完成"
  ```

  **Must NOT do**:
  - Keep the old docker compose down workaround
  - Keep the override file creation
  - Keep the post-setup permission fix (it's now pre-setup)

  **References**:
  - PR #3513: https://github.com/moltbot/moltbot/pull/3513
  - paths.ts line 46-58: `MOLTBOT_STATE_DIR` takes precedence
  - state-migrations.ts: skips migration if env var is set

  **Acceptance Criteria**:
  - [ ] Run `orb delete moltbot-vm && bash moltbot-orbstack-setup.sh`
  - [ ] Complete the interactive wizard
  - [ ] Run `moltbot-doctor` from Mac
  - [ ] Verify: NO "Failed to move legacy state dir" warning appears

  **Commit**: YES
  - Message: `fix(setup): prevent EBUSY by pre-setting MOLTBOT_STATE_DIR`

---

- [x] 2. Remove obsolete workaround code

  **What to do**:
  
  Remove these sections that are no longer needed:
  
  1. Remove `vm_compose()` helper function (lines ~50-57) - no longer needed
  2. Remove all the post-docker-setup.sh workaround code:
     - "停止容器以应用迁移修复" section
     - Override file creation
     - Permission fix after docker-setup.sh
  
  3. Simplify step 8 to just:
  ```bash
  step 8 "合并配置 + 创建便捷命令"
  
  info "将沙箱配置合并到容器内..."
  # ... keep the sandbox config merge code ...
  ok "沙箱配置已合并"
  
  # Keep convenience commands but simplify them (no override detection needed)
  ```

  **References**:
  - Current lines 297-325: all the workaround code to remove
  - vm_compose() at lines 50-57

  **Acceptance Criteria**:
  - [ ] Script is simpler with fewer moving parts
  - [ ] No override file is created
  - [ ] Convenience commands work without override detection

  **Commit**: YES (same commit as above)

---

- [x] 3. Simplify convenience commands

  **What to do**:
  
  Since we no longer need override file detection, simplify all convenience commands to just use `docker compose` directly:
  
  ```bash
  cat > ~/bin/moltbot-status << 'EOF'
  #!/bin/bash
  orb -m moltbot-vm bash -c "cd ~/moltbot && sg docker -c 'docker compose ps'"
  EOF
  
  cat > ~/bin/moltbot-logs << 'EOF'
  #!/bin/bash
  orb -m moltbot-vm bash -c "cd ~/moltbot && sg docker -c 'docker compose logs -f moltbot-gateway'"
  EOF
  
  # ... similar for other commands ...
  ```

  **Acceptance Criteria**:
  - [ ] All moltbot-* commands work
  - [ ] No complex override detection logic
  - [ ] `moltbot-doctor` shows clean output

---

- [x] 4. Update AGENTS.md documentation

  **What to do**:
  
  Update the troubleshooting section to explain the fix:
  
  ```markdown
  | EBUSY on rename | Bind mount conflict | Script pre-sets `MOLTBOT_STATE_DIR` to skip migration |
  ```

  **Acceptance Criteria**:
  - [ ] Documentation accurately reflects the fix

---

## Verification Commands

```bash
# Full test
orb delete moltbot-vm
bash moltbot-orbstack-setup.sh
# Complete the wizard
moltbot-doctor

# Expected: No EBUSY warning
```

## Success Criteria

- [ ] Fresh install completes without EBUSY warning
- [ ] `moltbot doctor` shows clean output (no migration errors)
- [ ] Script is simpler than before (fewer workarounds)
