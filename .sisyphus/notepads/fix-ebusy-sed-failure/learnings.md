# Learnings - Fix EBUSY sed Failure

## [2026-01-29T22:16:35Z] Session Start

### Problem Discovery
User deployed with commit 5b52bbc and still got EBUSY warning.
Diagnostic showed: `grep MOLTBOT_STATE_DIR ~/moltbot/docker-compose.yml` returned nothing.

### Root Cause
The sed command silently failed:
```bash
sed -i '/moltbot-gateway:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml
```

**Why it failed**:
1. Regex `/^  [a-z]/` doesn't match actual YAML structure
2. Multiple bash layers corrupting escape sequences
3. GNU sed `a\` append syntax issues

### Solution
Replace sed with Python + PyYAML for proper YAML manipulation.


## [2026-01-29T22:18:00Z] Implementation Complete

### Changes Made

**Commit**: d219a81 - `fix(setup): use Python instead of sed for YAML patching (sed silently failed)`

**Replaced**:
```bash
vm_exec "cd ~/moltbot && sed -i '/moltbot-gateway:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml"
vm_exec "cd ~/moltbot && sed -i '/moltbot-cli:/,/^  [a-z]/{/environment:/a\\      MOLTBOT_STATE_DIR: /home/node/.clawdbot}' docker-compose.yml"
```

**With**:
```bash
vm_exec 'cd ~/moltbot && python3 << "PYEOF"
import yaml

with open("docker-compose.yml", "r") as f:
    data = yaml.safe_load(f)

for svc in ["moltbot-gateway", "moltbot-cli"]:
    if svc in data.get("services", {}):
        if "environment" not in data["services"][svc]:
            data["services"][svc]["environment"] = {}
        data["services"][svc]["environment"]["MOLTBOT_STATE_DIR"] = "/home/node/.clawdbot"

with open("docker-compose.yml", "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print("✓ MOLTBOT_STATE_DIR added to docker-compose.yml")
PYEOF'
```

### Verification Results
- ✅ bash -n: exit 0
- ✅ sed -i removed: 0 matches
- ✅ import yaml present: 1 match  
- ✅ MOLTBOT_STATE_DIR present: 4 matches

### Key Pattern Learned

**For YAML modification in bash scripts**:
- ❌ DON'T use sed with complex regex (fragile, silent failures)
- ✅ DO use Python with PyYAML (reliable, explicit errors)

**Heredoc syntax for Python in vm_exec**:
```bash
vm_exec 'cd ~/dir && python3 << "PYEOF"
python code here
PYEOF'
```

Single quotes + quoted delimiter prevents all variable expansion.
