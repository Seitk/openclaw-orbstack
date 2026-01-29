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
