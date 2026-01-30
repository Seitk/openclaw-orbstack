# OpenClaw Upgrade - MoltbotOrb to OpenClawOrb

## TL;DR

> **Quick Summary**: Complete rebranding from Moltbot to OpenClaw naming, add all 3 sandbox images (basic, browser, common), and enable browser tool by default.
> 
> **Deliverables**:
> - Renamed script: `openclaw-orbstack-setup.sh`
> - Renamed README: `README-openclaw-orbstack.md`
> - Updated AGENTS.md
> - All references changed: moltbot → openclaw, clawdbot → openclaw
> - 3 sandbox images built, browser enabled
> - 7 Mac convenience commands renamed
> 
> **Estimated Effort**: Medium (2-3 hours)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4 → Task 5

---

## Context

### Original Request
User saw https://docs.openclaw.ai/install/docker showing the project has been completely upgraded. Requested updating MoltbotOrb to use the new OpenClaw structure.

### Interview Summary
**Key Discussions**:
- Naming: All references will be renamed to openclaw-* (VM, commands, images, paths)
- Sandbox images: Build all 3 (basic, browser, common)
- Browser: Enable by default
- Migration: Not needed (fresh install only)
- Security: Keep basic config (no seccomp/apparmor)

**Research Findings**:
- New repo: `openclaw/openclaw` on GitHub
- New config structure with `~/.openclaw/` path
- New sandbox scripts: `sandbox-setup.sh`, `sandbox-browser-setup.sh`, `sandbox-common-setup.sh`
- Browser sandbox uses Chromium with CDP

### Metis Review
**Identified Gaps** (addressed):
- Gap: Example config files in `.claude/`, `.opencode/` → Addressed: Out of scope for this upgrade
- Gap: Old Mac commands remain after install → Addressed: Document only, no auto-cleanup
- Gap: Port 18789 unchanged? → Addressed: Yes, keep same port
- Gap: Browser networking → Addressed: No port exposure needed for browser tool

---

## Work Objectives

### Core Objective
Complete rebranding from Moltbot/Clawdbot to OpenClaw naming throughout the deployment toolkit, including support for all 3 sandbox images and browser tool enabled by default.

### Concrete Deliverables
- `openclaw-orbstack-setup.sh` - Main deployment script
- `README-openclaw-orbstack.md` - User documentation (Chinese)
- Updated `AGENTS.md` - Developer documentation

### Definition of Done
- [ ] `grep -rn "moltbot" *.sh *.md | grep -v "\.sisyphus"` returns no matches
- [ ] `grep -rn "clawdbot" *.sh *.md | grep -v "\.sisyphus"` returns no matches
- [ ] `bash -n openclaw-orbstack-setup.sh` exits 0 (valid syntax)

### Must Have
- Complete rebranding: all moltbot/clawdbot → openclaw
- Build all 3 sandbox images in script
- Browser enabled in sandbox config
- 7 Mac convenience commands with openclaw-* prefix
- Chinese documentation preserved

### Must NOT Have (Guardrails)
- Migration/upgrade paths from old installation
- seccomp/apparmor security profiles
- noVNC or browser preview UI
- Multi-agent profile configuration
- setupCommand in sandbox config
- Extra mounts or DNS configuration
- New convenience commands beyond existing 7
- Changes to .claude/ or .opencode/ directories
- CI/CD or automated testing

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (bash scripts, no test framework)
- **User wants tests**: Manual-only
- **Framework**: none

### Automated Verification (Agent-Executable)

Each TODO includes verification commands the agent executes directly:

**By Deliverable Type:**

| Type | Verification Tool | Automated Procedure |
|------|------------------|---------------------|
| **Bash Script** | Bash syntax check | `bash -n script.sh` |
| **File Rename** | `test -f` / `test ! -f` | Agent checks file existence |
| **Content Replace** | `grep -c pattern file` | Agent counts matches (expect 0 for old patterns) |
| **Shellcheck** | shellcheck (if available) | Agent runs linter |

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Rename and update main script
└── Task 2: Rename and update README (can parallel since different files)

Wave 2 (After Wave 1):
├── Task 3: Update AGENTS.md
└── Task 4: Verify no orphaned references

Wave 3 (After Wave 2):
└── Task 5: Final syntax and consistency check

Critical Path: Task 1 → Task 3 → Task 5
Parallel Speedup: Tasks 1+2 parallel, Tasks 3+4 parallel
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4, 5 | 2 |
| 2 | None | 4, 5 | 1 |
| 3 | 1 | 5 | 4 |
| 4 | 1, 2 | 5 | 3 |
| 5 | 3, 4 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 2 | delegate_task(category="unspecified-high", ..., run_in_background=true) |
| 2 | 3, 4 | dispatch parallel after Wave 1 |
| 3 | 5 | final verification task |

---

## TODOs

- [ ] 1. Rename and update main deployment script

  **What to do**:
  - Rename `moltbot-orbstack-setup.sh` to `openclaw-orbstack-setup.sh`
  - Apply ALL replacement mappings (see table below)
  - Add browser sandbox image build in Step 5
  - Add common sandbox image build in Step 5
  - Update sandbox config in Step 6 to enable browser
  - Update all Mac convenience commands in Step 8 to use `openclaw-*` prefix

  **Replacement Mappings (EXACT)**:
  | Old Value | New Value |
  |-----------|-----------|
  | `moltbot-vm` | `openclaw-vm` |
  | `moltbot:local` | `openclaw:local` |
  | `moltbot-sandbox:bookworm-slim` | `openclaw-sandbox:bookworm-slim` |
  | `moltbot-gateway` | `openclaw-gateway` |
  | `moltbot-cli` | `openclaw-cli` |
  | `moltbot-sbx-` | `openclaw-sbx-` |
  | `~/.clawdbot/` | `~/.openclaw/` |
  | `~/clawd` | `~/.openclaw/workspace` |
  | `moltbot_home` | `openclaw_home` |
  | `MOLTBOT_STATE_DIR` | `OPENCLAW_STATE_DIR` |
  | `CLAWDBOT_HOME_VOLUME` | `OPENCLAW_HOME_VOLUME` |
  | `moltbot/moltbot.git` | `openclaw/openclaw.git` |
  | `~/moltbot` | `~/openclaw` |
  | `moltbot-status` | `openclaw-status` |
  | `moltbot-logs` | `openclaw-logs` |
  | `moltbot-restart` | `openclaw-restart` |
  | `moltbot-stop` | `openclaw-stop` |
  | `moltbot-start` | `openclaw-start` |
  | `moltbot-shell` | `openclaw-shell` |
  | `moltbot-doctor` | `openclaw-doctor` |
  | `moltbot-sandbox-config` | `openclaw-sandbox-config` |
  | `Moltbot` (display name) | `OpenClaw` |

  **New sandbox image builds to add (Step 5)**:
  ```bash
  info "Build browser sandbox image openclaw-sandbox-browser:bookworm-slim ..."
  vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-browser-setup.sh'" 2>/dev/null || \
  vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .'" || true
  ok "Browser sandbox image built"

  info "Build common sandbox image openclaw-sandbox-common:bookworm-slim ..."
  vm_exec "cd ~/openclaw && sg docker -c './scripts/sandbox-common-setup.sh'" 2>/dev/null || \
  vm_exec "cd ~/openclaw && sg docker -c 'docker build -t openclaw-sandbox-common:bookworm-slim -f Dockerfile.sandbox-common .'" || true
  ok "Common sandbox image built"
  ```

  **Browser config to add (Step 6 sandbox config)**:
  ```json
  "browser": {
    "enabled": true,
    "image": "openclaw-sandbox-browser:bookworm-slim"
  }
  ```

  **Must NOT do**:
  - Do not change the 8-step structure
  - Do not add new convenience commands
  - Do not add migration logic
  - Do not add seccomp/apparmor config
  - Do not add setupCommand
  - Do not change port 18789

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Large file with many changes, requires careful attention to all mappings
  - **Skills**: [`git-master`]
    - `git-master`: May need to track file rename in git

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 3, 4, 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Source File**:
  - `/workspace/MoltbotOrb/moltbot-orbstack-setup.sh` - Current script to rename and modify (426 lines)

  **Pattern References (from OpenClaw docs)**:
  - New sandbox config structure: `agents.defaults.sandbox.browser.enabled: true`
  - New sandbox scripts: `./scripts/sandbox-setup.sh`, `./scripts/sandbox-browser-setup.sh`, `./scripts/sandbox-common-setup.sh`
  - Environment variable: `OPENCLAW_HOME_VOLUME` instead of `CLAWDBOT_HOME_VOLUME`

  **Acceptance Criteria**:

  **File Operations:**
  - [ ] Old file removed: `test ! -f /workspace/MoltbotOrb/moltbot-orbstack-setup.sh`
  - [ ] New file exists: `test -f /workspace/MoltbotOrb/openclaw-orbstack-setup.sh`

  **No Orphaned References (Agent runs grep):**
  ```bash
  # Agent executes:
  grep -c "moltbot" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: 0

  grep -c "clawdbot" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: 0

  grep -c "MOLTBOT_" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: 0

  grep -c "CLAWDBOT_" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: 0
  ```

  **New Content Present:**
  ```bash
  # Agent executes:
  grep -c "openclaw-vm" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: > 0

  grep -c "openclaw-sandbox-browser" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: > 0

  grep -c "openclaw-sandbox-common" /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: > 0

  grep -c '"browser":' /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: > 0 (browser config present)

  grep -c '"enabled": true' /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected output: > 0 (browser enabled)
  ```

  **Syntax Validation:**
  ```bash
  # Agent executes:
  bash -n /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  # Expected: Exit code 0, no output (valid bash syntax)
  ```

  **Commit**: NO (group with Task 2)

---

- [ ] 2. Rename and update README documentation

  **What to do**:
  - Rename `README-moltbot-orbstack.md` to `README-openclaw-orbstack.md`
  - Apply all replacement mappings
  - Update sandbox image references to include all 3 images
  - Update Mac commands table to use `openclaw-*` prefix
  - Keep Chinese language throughout

  **Must NOT do**:
  - Do not translate to English
  - Do not add new sections
  - Do not remove any existing documentation sections

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation update, need to preserve tone and structure
  - **Skills**: []
    - No special skills needed for markdown editing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Source File**:
  - `/workspace/MoltbotOrb/README-moltbot-orbstack.md` - Current README to rename and modify (162 lines)

  **Acceptance Criteria**:

  **File Operations:**
  - [ ] Old file removed: `test ! -f /workspace/MoltbotOrb/README-moltbot-orbstack.md`
  - [ ] New file exists: `test -f /workspace/MoltbotOrb/README-openclaw-orbstack.md`

  **No Orphaned References:**
  ```bash
  # Agent executes:
  grep -c "moltbot" /workspace/MoltbotOrb/README-openclaw-orbstack.md
  # Expected output: 0

  grep -c "clawdbot" /workspace/MoltbotOrb/README-openclaw-orbstack.md
  # Expected output: 0
  ```

  **Commit**: NO (group with Task 1)

---

- [ ] 3. Update AGENTS.md developer documentation

  **What to do**:
  - Update project description: "Moltbot OrbStack deployment toolkit" → "OpenClaw OrbStack deployment toolkit"
  - Update all code examples with new naming
  - Update project structure section
  - Update development commands section
  - Update OrbStack VM management commands
  - Update troubleshooting section

  **Must NOT do**:
  - Do not change the overall structure of AGENTS.md
  - Do not add new sections
  - Do not remove existing guidance

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation update
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1 (needs to reference final script name)

  **References**:

  **Source File**:
  - `/workspace/MoltbotOrb/AGENTS.md` - Developer documentation (~250 lines)

  **Acceptance Criteria**:

  **No Orphaned References:**
  ```bash
  # Agent executes:
  grep -c "moltbot" /workspace/MoltbotOrb/AGENTS.md
  # Expected output: 0

  grep -c "clawdbot" /workspace/MoltbotOrb/AGENTS.md
  # Expected output: 0

  grep -c "Moltbot" /workspace/MoltbotOrb/AGENTS.md
  # Expected output: 0 (case sensitive check)
  ```

  **New Content Present:**
  ```bash
  # Agent executes:
  grep -c "OpenClaw" /workspace/MoltbotOrb/AGENTS.md
  # Expected output: > 0

  grep -c "openclaw-orbstack-setup.sh" /workspace/MoltbotOrb/AGENTS.md
  # Expected output: > 0
  ```

  **Commit**: YES
  - Message: `refactor: rename MoltbotOrb to OpenClawOrb with full rebranding`
  - Files: `openclaw-orbstack-setup.sh`, `README-openclaw-orbstack.md`, `AGENTS.md`
  - Pre-commit: `bash -n openclaw-orbstack-setup.sh`

---

- [ ] 4. Verify no orphaned references across project

  **What to do**:
  - Run comprehensive grep across all files
  - Report any remaining moltbot/clawdbot/Moltbot/Clawdbot references
  - Exclude .git/ and .sisyphus/ directories

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple verification task
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 3)
  - **Blocks**: Task 5
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Files to Check**:
  - All `.sh` files in project root
  - All `.md` files in project root (excluding .sisyphus/)
  - `opencode.json.example` if exists

  **Acceptance Criteria**:

  ```bash
  # Agent executes comprehensive check:
  cd /workspace/MoltbotOrb && grep -rn --include="*.sh" --include="*.md" "moltbot\|clawdbot\|Moltbot\|Clawdbot" . | grep -v ".sisyphus" | grep -v ".git"
  # Expected output: (empty - no matches)

  # If any matches found, list them for fixing
  ```

  **Commit**: NO (verification only)

---

- [ ] 5. Final syntax and consistency validation

  **What to do**:
  - Run bash syntax check on main script
  - Run shellcheck if available
  - Verify all file renames completed
  - Create summary of changes

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple validation task
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final)
  - **Blocks**: None (final task)
  - **Blocked By**: Tasks 3, 4

  **References**:

  **Files to Validate**:
  - `/workspace/MoltbotOrb/openclaw-orbstack-setup.sh`
  - `/workspace/MoltbotOrb/README-openclaw-orbstack.md`
  - `/workspace/MoltbotOrb/AGENTS.md`

  **Acceptance Criteria**:

  **Bash Syntax Valid:**
  ```bash
  # Agent executes:
  bash -n /workspace/MoltbotOrb/openclaw-orbstack-setup.sh
  echo "Exit code: $?"
  # Expected: Exit code: 0
  ```

  **Shellcheck (if available):**
  ```bash
  # Agent executes:
  which shellcheck && shellcheck /workspace/MoltbotOrb/openclaw-orbstack-setup.sh || echo "shellcheck not installed, skipping"
  # Expected: No errors, or "shellcheck not installed"
  ```

  **All Files Present:**
  ```bash
  # Agent executes:
  test -f /workspace/MoltbotOrb/openclaw-orbstack-setup.sh && echo "Script: OK"
  test -f /workspace/MoltbotOrb/README-openclaw-orbstack.md && echo "README: OK"
  test -f /workspace/MoltbotOrb/AGENTS.md && echo "AGENTS.md: OK"
  # Expected: All three "OK" messages
  ```

  **Old Files Removed:**
  ```bash
  # Agent executes:
  test ! -f /workspace/MoltbotOrb/moltbot-orbstack-setup.sh && echo "Old script removed: OK"
  test ! -f /workspace/MoltbotOrb/README-moltbot-orbstack.md && echo "Old README removed: OK"
  # Expected: Both "OK" messages
  ```

  **Commit**: NO (Task 3 already committed)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 3 | `refactor: rename MoltbotOrb to OpenClawOrb with full rebranding` | openclaw-orbstack-setup.sh, README-openclaw-orbstack.md, AGENTS.md | `bash -n openclaw-orbstack-setup.sh` |

---

## Success Criteria

### Verification Commands
```bash
# All must pass:
bash -n /workspace/MoltbotOrb/openclaw-orbstack-setup.sh  # Exit 0
grep -c "moltbot" /workspace/MoltbotOrb/*.sh /workspace/MoltbotOrb/*.md 2>/dev/null | grep -v ":0$" | wc -l  # Output: 0
grep -c "clawdbot" /workspace/MoltbotOrb/*.sh /workspace/MoltbotOrb/*.md 2>/dev/null | grep -v ":0$" | wc -l  # Output: 0
test -f /workspace/MoltbotOrb/openclaw-orbstack-setup.sh  # Exit 0
test -f /workspace/MoltbotOrb/README-openclaw-orbstack.md  # Exit 0
```

### Final Checklist
- [ ] All "Must Have" present (rebranding complete, 3 images, browser enabled)
- [ ] All "Must NOT Have" absent (no migration, no seccomp, no new commands)
- [ ] Bash syntax valid
- [ ] No orphaned moltbot/clawdbot references
