# Fix EBUSY Error - sed Command Failed

## TL;DR

> **Quick Summary**: The sed command to patch docker-compose.yml silently failed. Replace it with Python-based YAML modification which is more reliable.
> 
> **Deliverables**:
> - Modified `moltbot-orbstack-setup.sh` replacing sed with Python for YAML patching
> 
> **Estimated Effort**: Quick
> **Critical Path**: Edit lines 289-301 → Validate → Commit → User Test

---

## Context

### Problem Discovery

User ran deployment and `moltbot-doctor` still shows EBUSY warning. Diagnostic commands revealed:

```bash
orb -m moltbot-vm bash -c "grep MOLTBOT_STATE_DIR ~/moltbot/docker-compose.yml"
# Result: ❌ 没找到 (not found)
```

**The sed command silently failed** - `MOLTBOT_STATE_DIR` was never added to docker-compose.yml.

### Why sed Failed

The sed command in commit 5b52bbc:
```bash
sed -i '/moltbot-gateway:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml
```

Potential failure reasons:
1. **Regex mismatch**: `/^  [a-z]/` pattern may not match actual YAML structure
2. **Escaping issues**: Multiple bash layers corrupting the command
3. **GNU sed syntax**: The `a\` append syntax may behave differently

### The Solution

**Use Python with PyYAML** instead of sed. Python is:
- Already installed in the VM
- Understands YAML structure properly
- More reliable than regex-based text manipulation
- Won't silently fail

---

## Work Objectives

### Core Objective
Replace the failing sed commands with Python-based YAML modification.

### Definition of Done
- [x] Fix implemented (commit d219a81)
- [x] Agent work complete - awaiting user testing

**User Acceptance Test** (not agent-executable):
- 👤 `MOLTBOT_STATE_DIR` appears in docker-compose.yml after deployment
- 👤 `moltbot-doctor` shows no EBUSY warning

---

## TODOs

- [x] 1. Replace sed commands with Python YAML modification

  **What to do**:
  
  In `moltbot-orbstack-setup.sh`, replace lines 289-301:

  **REMOVE** (broken sed approach):
  ```bash
  # Fix EBUSY: docker-setup.sh uses -f flag which ignores override files
  # So we patch docker-compose.yml directly and restart containers
  info "修复 EBUSY 迁移错误..."
  vm_exec 'cd ~/moltbot && sg docker -c "docker compose stop"'

  # Add MOLTBOT_STATE_DIR to both services in docker-compose.yml
  # This tells moltbot to skip the .clawdbot -> .moltbot migration
  vm_exec "cd ~/moltbot && sed -i '/moltbot-gateway:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml"
  vm_exec "cd ~/moltbot && sed -i '/moltbot-cli:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml"

  # Restart with the patched config
  vm_exec 'cd ~/moltbot && sg docker -c "docker compose up -d"'
  ok "EBUSY 修复完成"
  ```

  **REPLACE WITH** (Python YAML approach):
  ```bash
  # Fix EBUSY: docker-setup.sh uses -f flag which ignores override files
  # So we patch docker-compose.yml directly using Python (more reliable than sed for YAML)
  info "修复 EBUSY 迁移错误..."
  vm_exec 'cd ~/moltbot && sg docker -c "docker compose stop"'

  # Add MOLTBOT_STATE_DIR to both services using Python
  # This is more reliable than sed for modifying YAML structure
  vm_exec 'cd ~/moltbot && python3 << "PYEOF"
import yaml

with open("docker-compose.yml", "r") as f:
    data = yaml.safe_load(f)

# Add MOLTBOT_STATE_DIR to both services
for svc in ["moltbot-gateway", "moltbot-cli"]:
    if svc in data.get("services", {}):
        if "environment" not in data["services"][svc]:
            data["services"][svc]["environment"] = {}
        data["services"][svc]["environment"]["MOLTBOT_STATE_DIR"] = "/home/node/.clawdbot"

with open("docker-compose.yml", "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print("✓ MOLTBOT_STATE_DIR added to docker-compose.yml")
PYEOF'

  # Restart with the patched config
  vm_exec 'cd ~/moltbot && sg docker -c "docker compose up -d"'
  ok "EBUSY 修复完成"
  ```

  **Must NOT do**:
  - Keep the sed commands (they don't work)
  - Use complex escaping (Python heredoc is cleaner)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file edit, clear before/after code blocks
  - **Skills**: [`git-master`]
    - `git-master`: For commit after edit

  **Parallelization**:
  - **Can Run In Parallel**: NO (only one task)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `moltbot-orbstack-setup.sh:289-301` - Current broken sed implementation
  - Python yaml module docs: https://pyyaml.org/wiki/PyYAMLDocumentation

  **Acceptance Criteria**:

  **Automated Verification (agent-executable):**
  ```bash
  # Verify bash syntax is valid
  bash -n moltbot-orbstack-setup.sh
  # Assert: Exit code 0
  
  # Verify sed commands are removed
  grep -c "sed -i" moltbot-orbstack-setup.sh
  # Assert: Output is 0 (no sed commands)
  
  # Verify Python approach is present
  grep -c "import yaml" moltbot-orbstack-setup.sh
  # Assert: Output is 1
  
  # Verify MOLTBOT_STATE_DIR is in the Python code
  grep -c "MOLTBOT_STATE_DIR" moltbot-orbstack-setup.sh
  # Assert: Output >= 1
  ```

  **Commit**: YES
  - Message: `fix(setup): use Python instead of sed for YAML patching (sed silently failed)`
  - Files: `moltbot-orbstack-setup.sh`
  - Pre-commit: `bash -n moltbot-orbstack-setup.sh`

---

## Success Criteria

### Automated Verification
```bash
bash -n moltbot-orbstack-setup.sh  # Expected: exit 0
grep -c "sed -i" moltbot-orbstack-setup.sh  # Expected: 0
grep -c "import yaml" moltbot-orbstack-setup.sh  # Expected: 1
```

### Manual Verification (USER MUST RUN)
```bash
orb delete moltbot-vm
bash moltbot-orbstack-setup.sh
# Complete wizard

# Verify Python patch worked:
orb -m moltbot-vm bash -c "grep MOLTBOT_STATE_DIR ~/moltbot/docker-compose.yml"
# Expected: Shows 2 matches

# Final verification:
moltbot-doctor
# Expected: No EBUSY warning
```

---

## Technical Notes

### Why Python is Better Than sed for YAML

| sed | Python |
|-----|--------|
| Text-based regex matching | Understands YAML structure |
| Silently fails on regex mismatch | Explicit errors on failure |
| Fragile with indentation | Preserves proper indentation |
| Escaping nightmare with heredocs | Clean heredoc syntax |

### Python PyYAML Approach

```python
import yaml

with open("docker-compose.yml", "r") as f:
    data = yaml.safe_load(f)

# Modify in-memory data structure
data["services"]["moltbot-gateway"]["environment"]["MOLTBOT_STATE_DIR"] = "/home/node/.clawdbot"
data["services"]["moltbot-cli"]["environment"]["MOLTBOT_STATE_DIR"] = "/home/node/.clawdbot"

with open("docker-compose.yml", "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
```

This:
1. Parses YAML into Python dict
2. Modifies the dict (proper key insertion)
3. Writes back as valid YAML
4. Preserves structure and indentation

### Heredoc Syntax in bash

```bash
vm_exec 'cd ~/moltbot && python3 << "PYEOF"
python code here
PYEOF'
```

- `<< "PYEOF"`: Quoted delimiter prevents variable expansion
- Single quotes around `vm_exec` argument: Prevents local shell expansion
- Python code runs in VM with full indentation preserved
