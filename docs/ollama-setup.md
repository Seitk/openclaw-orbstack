# Ollama Setup Guide for OpenClaw OrbStack

**Version:** v2026.2.1
**Last Updated:** 2026-02-03
**Tested Models:** GPT-OSS 20B, Gemma3 4B, LLaVA 7B

## Overview

This guide shows how to configure OpenClaw (running in OrbStack VM) to use Ollama models running on your Mac. This setup provides:

- ✅ **Free local inference** - No API costs
- ✅ **Privacy** - All data stays on your Mac
- ✅ **Offline capability** - Works without internet (after model download)
- ✅ **GPU acceleration** - Uses Apple Silicon or discrete GPU

## Architecture

```
Mac (your computer)
├── Ollama (port 11434)          ← Model inference engine
├── Open WebUI (port 3000)       ← Optional web interface
└── OrbStack
    └── Ubuntu VM (openclaw-vm)
        ├── Gateway (systemd)    ← OpenClaw orchestrator
        │   └── Connects via host.orb.internal:11434
        └── Docker
            ├── sandbox-common   ← Code execution
            └── sandbox-browser  ← Browser automation
```

**Key Connection:** VM accesses Mac's Ollama via `host.orb.internal:11434`

## Prerequisites

1. **OrbStack** installed and running
2. **Ollama** installed on Mac
   ```bash
   brew install ollama
   ```
3. **Models pulled** in Ollama
   ```bash
   ollama pull gpt-oss:20b
   ollama pull gemma3:4b
   ollama pull llava:7b
   ```
4. **Ollama server running**
   ```bash
   ollama serve
   # Or it auto-starts on Mac
   ```
5. **OpenClaw OrbStack** installed via `bash openclaw-orbstack-setup.sh`

## Configuration

### Step 1: Configure Gateway Service

Edit the systemd service to add Ollama environment variables:

**File:** `~/.config/systemd/user/openclaw-gateway.service` (inside VM)

```ini
[Unit]
Description=OpenClaw Gateway (v2026.2.1)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/home/philip/openclaw/gateway-wrapper.sh
Restart=always
RestartSec=5
KillMode=process
Environment=HOME=/home/philip
Environment="PATH=/home/philip/.local/bin:/home/philip/.npm-global/bin:/home/philip/bin:/home/philip/.nvm/current/bin:/home/philip/.fnm/current/bin:/home/philip/.volta/bin:/home/philip/.asdf/shims:/home/philip/.local/share/pnpm:/home/philip/.bun/bin:/usr/local/bin:/usr/bin:/bin"
Environment=OPENCLAW_GATEWAY_PORT=18789
Environment=OPENCLAW_GATEWAY_TOKEN=9d49e1adf4fbbc6715d9ab9753e60c7e11055f47dbd8483b
Environment="OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
Environment=OPENCLAW_SERVICE_MARKER=openclaw
Environment=OPENCLAW_SERVICE_KIND=gateway
Environment=OPENCLAW_SERVICE_VERSION=2026.2.1
Environment=OLLAMA_BASE_URL=http://host.orb.internal:11434
Environment=OLLAMA_API_KEY=ollama-local

[Install]
WantedBy=default.target
```

**Key additions:**
- `OLLAMA_BASE_URL=http://host.orb.internal:11434`
- `OLLAMA_API_KEY=ollama-local`

### Step 2: Create Gateway Wrapper Script

The gateway needs Docker group permissions to manage sandbox containers.

**File:** `~/openclaw/gateway-wrapper.sh` (inside VM)

```bash
#!/bin/bash
exec sg docker -c "/usr/bin/node /home/philip/openclaw/dist/index.js gateway --port 18789"
```

Make it executable:
```bash
chmod +x ~/openclaw/gateway-wrapper.sh
```

### Step 3: Configure Ollama Provider

**File:** `~/.openclaw/openclaw.json` (inside VM)

Add the Ollama provider to the `models` section:

```json5
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://host.orb.internal:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions",  // CRITICAL: must be "openai-completions"
        "authHeader": false,           // Ollama doesn't need auth headers
        "models": [
          {
            "id": "gpt-oss:20b",
            "name": "GPT-OSS 20B",
            "reasoning": false,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 128000,
            "maxTokens": 32000
          },
          {
            "id": "gemma3:4b",
            "name": "Gemma 3 4B",
            "reasoning": false,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 8192,
            "maxTokens": 4096
          },
          {
            "id": "llava:7b",
            "name": "LLaVA 7B (Vision)",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 4096,
            "maxTokens": 2048
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/gpt-oss:20b"  // Set your preferred model
      }
    }
  }
}
```

**Critical Settings:**
- `"api": "openai-completions"` - NOT "openai-responses" (common mistake)
- `"authHeader": false` - Ollama doesn't use authorization headers
- `"baseUrl"` - Must include `/v1` suffix
- Model prefix: `ollama/model-name` format

### Step 4: Reload and Restart

Inside the VM:

```bash
# Reload systemd configuration
systemctl --user daemon-reload

# Restart gateway
systemctl --user restart openclaw-gateway

# Check status
systemctl --user status openclaw-gateway

# Watch logs
journalctl --user -u openclaw-gateway -f
```

## Verification

### 1. Test Ollama Connection from VM

```bash
# Inside VM
curl http://host.orb.internal:11434/v1/models

# Expected output: JSON list of available models
```

### 2. Test Chat Completion

```bash
# Inside VM
curl -s http://host.orb.internal:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss:20b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }' | python3 -m json.tool
```

### 3. Check Gateway Logs

Look for successful model loading:

```bash
journalctl --user -u openclaw-gateway -n 20 | grep "agent model"

# Expected output:
# [gateway] agent model: ollama/gpt-oss:20b
```

### 4. Test via Telegram

Send a message to your bot:
```
Hello! Can you help me write a Python script?
```

The bot should respond using your local Ollama model.

## Troubleshooting

### Error: "Unknown model: ollama/gpt-oss:20b"

**Cause:** Agent-specific config overriding main config

**Solution:** Check and remove/update agent-specific models file

```bash
# Inside VM
ls -la ~/.openclaw/agents/main/agent/models.json

# If exists, either delete it or ensure it has the same Ollama config
rm ~/.openclaw/agents/main/agent/models.json

# Restart
systemctl --user restart openclaw-gateway
```

### Error: "Connection refused" or "Cannot connect to Ollama"

**Cause:** Ollama not running on Mac or wrong URL

**Solutions:**

1. **Check Ollama is running on Mac:**
   ```bash
   # On Mac
   curl http://localhost:11434/v1/models
   ```

2. **Verify VM can reach Mac:**
   ```bash
   # Inside VM
   ping host.orb.internal
   curl http://host.orb.internal:11434/api/tags
   ```

3. **Restart Ollama on Mac:**
   ```bash
   # On Mac
   pkill ollama
   ollama serve
   ```

### Error: "permission denied while trying to connect to docker socket"

**Cause:** Gateway doesn't have Docker group permissions

**Solution:** Ensure gateway wrapper script uses `sg docker -c`

```bash
# Inside VM
cat ~/openclaw/gateway-wrapper.sh

# Should contain:
# exec sg docker -c "/usr/bin/node /home/philip/openclaw/dist/index.js gateway --port 18789"

# Make sure it's executable
chmod +x ~/openclaw/gateway-wrapper.sh

# Restart
systemctl --user restart openclaw-gateway
```

### Error: "405 Method Not Allowed" or Empty Responses

**Cause:** Wrong `api` type in configuration

**Solution:** Ensure `"api": "openai-completions"` (NOT "openai-responses")

```bash
# Inside VM
grep -A 5 '"api"' ~/.openclaw/openclaw.json

# Should show:
# "api": "openai-completions"
```

### OrbStack CLI Panicking ("timed out waiting for services to start")

**Cause:** OrbStack's internal services crashed

**Solution:** Full OrbStack restart

```bash
# On Mac
killall -9 OrbStack "OrbStack Helper"
sleep 5
open -a OrbStack

# Wait 30 seconds, then test
orb list
```

## Switching Models

### Via Config File

Edit `~/.openclaw/openclaw.json`:

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/gemma3:4b"  // Change model here
      }
    }
  }
}
```

Restart gateway:
```bash
systemctl --user restart openclaw-gateway
```

### Via Chat Command

In Telegram or any chat:
```
/model ollama/gemma3:4b
/model ollama/llava:7b
```

### List Available Models

```
/model list
```

## Performance Tips

1. **Use appropriate quantization:**
   - Q3_K_M: Good balance (used in examples)
   - Q4_K_M: Better quality, more VRAM
   - Q5_K_M: Best quality, most VRAM

2. **Monitor resource usage:**
   ```bash
   # On Mac
   ollama ps

   # Check memory usage
   top -pid $(pgrep ollama)
   ```

3. **Adjust context window:**
   - Larger context = more VRAM
   - Default 2048 is usually sufficient
   - 8192+ needed for long conversations

4. **Model recommendations by use case:**
   - **Coding:** gpt-oss:20b, qwen2.5-coder:32b
   - **General chat:** gemma3:4b, llama3.3:70b
   - **Vision tasks:** llava:7b, llava:13b

## Advanced Configuration

### Auto-Discovery Method

Instead of explicit model configuration, use environment variables only:

**File:** `~/.config/systemd/user/openclaw-gateway.service`

```ini
Environment=OLLAMA_BASE_URL=http://host.orb.internal:11434
Environment=OLLAMA_API_KEY=ollama-local
```

**File:** `~/.openclaw/openclaw.json`

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/gpt-oss:20b"
      }
    }
  }
  // No models.providers section needed
}
```

OpenClaw will auto-discover models from Ollama via `/api/tags` and `/api/show`.

### Multiple Ollama Instances

To use multiple Ollama servers (e.g., remote server + local):

```json5
{
  "models": {
    "providers": {
      "ollama-local": {
        "baseUrl": "http://host.orb.internal:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions",
        "authHeader": false,
        "models": [/* local models */]
      },
      "ollama-remote": {
        "baseUrl": "http://remote-server:11434/v1",
        "apiKey": "ollama-remote",
        "api": "openai-completions",
        "authHeader": false,
        "models": [/* remote models */]
      }
    }
  }
}
```

## References

- [OpenClaw Ollama Provider Documentation](https://docs.openclaw.ai/providers/ollama)
- [Working Ollama Setup GitHub Gist](https://gist.github.com/Hegghammer/86d2070c0be8b3c62083d6653ad27c23)
- [Ollama Official Documentation](https://ollama.com/docs)
- [OpenClaw Model Providers](https://docs.openclaw.ai/concepts/model-providers)

## Quick Reference Commands

### Mac Commands

```bash
# Check Ollama status
ollama list

# Pull new model
ollama pull llama3.3

# Start Ollama server
ollama serve

# Test Ollama API
curl http://localhost:11434/v1/models
```

### VM Commands (via `orb -m openclaw-vm bash -c '...'`)

```bash
# Restart gateway
systemctl --user restart openclaw-gateway

# View logs
journalctl --user -u openclaw-gateway -f

# Check status
systemctl --user status openclaw-gateway

# Test Ollama connection
curl http://host.orb.internal:11434/v1/models

# Edit config
nano ~/.openclaw/openclaw.json
```

### OrbStack Commands

```bash
# List VMs
orb list

# Enter VM
orb -m openclaw-vm

# Restart VM
orb restart openclaw-vm

# Full OrbStack restart
killall -9 OrbStack && open -a OrbStack
```

## Summary Checklist

- [ ] Ollama installed and running on Mac
- [ ] Models pulled (`ollama pull model-name`)
- [ ] Gateway wrapper script created with `sg docker -c`
- [ ] systemd service has `OLLAMA_BASE_URL` and `OLLAMA_API_KEY`
- [ ] `openclaw.json` has Ollama provider with `"api": "openai-completions"`
- [ ] Primary model set to `ollama/model-name`
- [ ] No agent-specific `models.json` overriding config
- [ ] Gateway restarted after config changes
- [ ] Logs show `agent model: ollama/...` with no errors
- [ ] Test message sent and received via Telegram

---

**Success Criteria:** Bot responds to Telegram messages using local Ollama model with no errors in logs.
