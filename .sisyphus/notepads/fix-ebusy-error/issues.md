# Issues - Fix EBUSY Error

## Session ses_3f4c2a0a4ffePlCovxOdZf4xYa - 2026-01-29T21:02:14.860Z

### Issue: Nested Heredocs Fail Silently

**Symptom**: Override file not created when using nested heredocs:
```bash
orb -m "$VM_NAME" bash << 'REMOTE_EOF'
cat > file << 'EOFOVERRIDE'
content
EOFOVERRIDE
REMOTE_EOF
```

**Solution**: Use vm_exec with single heredoc layer
