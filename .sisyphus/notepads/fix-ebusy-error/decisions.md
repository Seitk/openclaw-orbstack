# Decisions - Fix EBUSY Error

## Session ses_3f4c2a0a4ffePlCovxOdZf4xYa - 2026-01-29T21:02:14.860Z

### Approach: Pre-configuration vs Post-fix

**Decision**: Use pre-configuration approach (set env vars BEFORE docker-setup.sh)

**Rationale**:
- Official PR #3513 uses this pattern
- Simpler and more reliable than post-setup workarounds
- Follows the principle of "configure before execute"

**Rejected Alternatives**:
- Post-setup override file: timing issues, containers already started
- docker compose down + recreate: error already logged, adds complexity
- Patching docker-setup.sh: too invasive, breaks updates

## [2026-01-29T22:01:56Z] Final Decision - Session ses_3f4c2a0a4ffePlCovxOdZf4xYa

### Decision: sed patching after docker-setup.sh

**Rationale**:
- docker-setup.sh source code analysis revealed explicit `-f` flags
- This makes all pre-setup approaches (override files, .env) ineffective
- Post-setup patching is the only viable solution

**Trade-offs**:
- ✅ Pro: Works reliably regardless of docker-setup.sh implementation
- ✅ Pro: Simple sed commands, easy to understand
- ⚠️ Con: EBUSY warning will be logged once during first start (acceptable)
- ⚠️ Con: Depends on docker-compose.yml structure (but structure is stable)

**Rejected Alternatives**:
1. Fork and modify docker-setup.sh - too invasive, breaks updates
2. Pre-populate .env file - doesn't pass env vars to containers
3. Create override file before docker-setup.sh - ignored by -f flags
4. Modify docker-setup.sh to add -f docker-compose.override.yml - too invasive

**Final approach**: Accept one EBUSY warning during initial setup, then patch and restart to prevent future warnings.
