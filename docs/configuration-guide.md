# OpenClaw 配置完全指南

本文档提供 OpenClaw 配置的详细说明，帮助你快速上手并根据需要自定义配置。

## 目录

- [快速开始](#快速开始)
- [配置文件位置](#配置文件位置)
- [配置格式](#配置格式)
- [最小配置](#最小配置)
- [配置模板](#配置模板)
- [常见配置场景](#常见配置场景)
- [配置项详解](#配置项详解)

---

## 快速开始

### 1. 编辑配置

**推荐方式** - 使用 `openclaw-config` 命令：

```bash
# 编辑配置（自动处理权限）
openclaw-config edit

# 查看当前配置
openclaw-config show
```

**手动方式** - 进入 VM 后编辑：

```bash
openclaw-shell
sudo nano ~/.openclaw/openclaw.json
```

### 2. 填入必要信息

- **AI API Key**: 至少配置一个 AI 提供商 (Anthropic/OpenAI/Google)
- **聊天平台**: 配置 Telegram Bot Token 或其他平台凭据
- **允许列表**: 设置允许使用机器人的用户

### 3. 重启服务

```bash
openclaw-restart
```

---

## 配置文件位置

| 路径 | 说明 |
|------|------|
| `~/.openclaw/openclaw.json` | 主配置文件 |
| `~/.openclaw/agents/<agentId>/auth-profiles.json` | 认证配置 (OAuth + API Key) |
| `~/.openclaw/credentials/` | 平台凭据目录 |
| `~/.openclaw/workspace/` | 默认工作区 |

> **环境变量**: 可通过 `OPENCLAW_STATE_DIR` 自定义状态目录

---

## 配置格式

OpenClaw 使用 **JSON5** 格式，支持：

- 单行注释: `// 这是注释`
- 多行注释: `/* 这也是注释 */`
- 尾随逗号: `{ "key": "value", }`
- 无引号键名: `{ key: "value" }`

```json5
{
  // 这是一个 JSON5 配置示例
  identity: {
    name: "OpenClaw",
    emoji: "🦞",
  },
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
    }
  }
}
```

---

## 最小配置

只需几行就能运行：

```json5
{
  agents: { defaults: { workspace: "~/.openclaw/workspace" } },
  channels: { whatsapp: { allowFrom: ["+8613800138000"] } }
}
```

---

## 配置模板

完整配置模板位于 `templates/config.json.example`，包含所有可用选项和详细注释。

### 快速配置示例

#### 推荐入门配置

```json5
{
  // 身份设置
  identity: {
    name: "小助手",
    theme: "helpful assistant",
    emoji: "🦞"
  },
  
  // Agent 配置
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: { primary: "anthropic/claude-sonnet-4-5" }
    }
  },
  
  // WhatsApp 配置
  channels: {
    whatsapp: {
      allowFrom: ["+8613800138000"],
      groups: { "*": { requireMention: true } }
    }
  }
}
```

#### 多平台配置

```json5
{
  agents: { defaults: { workspace: "~/.openclaw/workspace" } },
  channels: {
    whatsapp: { allowFrom: ["+8613800138000"] },
    telegram: {
      enabled: true,
      botToken: "123456:ABC...",
      allowFrom: ["123456789"]
    },
    discord: {
      enabled: true,
      token: "YOUR_TOKEN",
      dm: { allowFrom: ["username"] }
    }
  }
}
```

---

## 常见配置场景

### 场景 1: 个人使用 (安全优先)

```json5
{
  identity: { name: "个人助手", emoji: "🤖" },
  
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: { primary: "anthropic/claude-sonnet-4-5" },
      // 完全沙箱隔离 (浏览器需要网络，但 Mac 文件仍然隔离)
      sandbox: {
        mode: "all",
        scope: "session",
        workspaceAccess: "rw",
        docker: {
          network: "bridge",  // 浏览器自动化需要网络
          readOnlyRoot: true,
          user: "501:501"     // macOS 用户权限
        }
      }
    }
  },
  
  channels: {
    whatsapp: {
      dmPolicy: "allowlist",
      allowFrom: ["+8613800138000"],  // 只允许你自己
      groups: { "*": { requireMention: true } }
    }
  },
  
  tools: {
    elevated: {
      enabled: true,
      allowFrom: { whatsapp: ["+8613800138000"] }
    }
  }
}
```

### 场景 2: 团队使用 (多用户)

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: { primary: "anthropic/claude-sonnet-4-5" },
      sandbox: { mode: "all", workspaceAccess: "rw" }  // all 模式支持浏览器
    }
  },
  
  channels: {
    telegram: {
      enabled: true,
      botToken: "YOUR_BOT_TOKEN",
      dmPolicy: "pairing",  // 配对码模式
      groups: {
        "*": { requireMention: true },
        "-1001234567890": {  // 团队群组
          requireMention: false,
          allowFrom: ["@admin", "@member1", "@member2"]
        }
      }
    }
  },
  
  // 工具权限控制
  tools: {
    elevated: {
      enabled: true,
      allowFrom: {
        telegram: ["admin_user_id"]  // 只有管理员有提权权限
      }
    }
  }
}
```

### 场景 3: 公开机器人 (最严格限制)

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: { primary: "anthropic/claude-haiku-4" },  // 使用便宜的模型
      sandbox: {
        mode: "all",
        scope: "session",
        workspaceAccess: "none",  // 无文件访问
        docker: {
          network: "bridge",  // 即使有网络，Mac 文件仍然隔离
          memory: "512m",
          cpus: 0.5
        }
      }
    }
  },
  
  channels: {
    telegram: {
      enabled: true,
      botToken: "YOUR_BOT_TOKEN",
      dmPolicy: "open",
      allowFrom: ["*"],  // open 模式需要 *
      groups: { "*": { requireMention: true } }
    }
  },
  
  // 严格工具限制
  tools: {
    allow: ["read"],  // 只允许读取
    deny: ["exec", "write", "edit", "browser", "apply_patch"],
    elevated: { enabled: false }
  },
  
  // 会话限制
  session: {
    reset: { mode: "idle", idleMinutes: 30 }  // 30 分钟空闲自动重置
  }
}
```

### 场景 4: 多 Agent 路由

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      sandbox: { mode: "all" }  // 推荐 all 模式
    },
    list: [
      {
        id: "personal",
        default: true,
        workspace: "~/.openclaw/workspace-personal",
        model: { primary: "anthropic/claude-opus-4-5" },
        sandbox: { mode: "all" }  // 建议保持沙箱保护 Mac 文件
      },
      {
        id: "work",
        workspace: "~/.openclaw/workspace-work",
        model: { primary: "anthropic/claude-sonnet-4-5" }
      },
      {
        id: "family",
        workspace: "~/.openclaw/workspace-family",
        model: { primary: "anthropic/claude-haiku-4" },
        sandbox: { mode: "all", workspaceAccess: "ro" },
        tools: {
          deny: ["exec", "write", "edit"]  // 只读模式
        }
      }
    ]
  },
  
  // 路由规则
  bindings: [
    { agentId: "personal", match: { channel: "whatsapp", peer: { kind: "dm", id: "+8613800138000" } } },
    { agentId: "work", match: { channel: "slack" } },
    { agentId: "family", match: { channel: "whatsapp", peer: { kind: "group", id: "family-group-id" } } }
  ],
  
  channels: {
    whatsapp: { dmPolicy: "pairing" },
    slack: { enabled: true, botToken: "xoxb-..." }
  }
}
```

---

## 配置项详解

### AI 模型配置

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `model.primary` | 主模型 | `"anthropic/claude-sonnet-4-5"` |
| `model.fallbacks` | 备用模型列表 | `["anthropic/claude-haiku-4", "openai/gpt-4o"]` |
| `models` | 模型别名 | `{ "anthropic/claude-opus-4-5": { alias: "opus" } }` |
| `imageModel` | 图像处理模型 | `{ primary: "openai/gpt-4o" }` |

**支持的提供商**:
- `anthropic` - Claude 系列
- `openai` - GPT 系列
- `google` - Gemini 系列
- `openrouter` - 聚合多个提供商
- `groq` - 高速推理
- `deepseek` - DeepSeek 系列
- `minimax` - MiniMax 系列

### 聊天频道配置

#### WhatsApp

```json5
{
  channels: {
    whatsapp: {
      // DM 策略
      dmPolicy: "pairing",  // pairing | allowlist | open | disabled
      allowFrom: ["+8613800138000"],  // E.164 格式
      
      // 群组策略
      groupPolicy: "allowlist",
      groupAllowFrom: ["+8613800138000"],
      groups: {
        "*": { requireMention: true },
        "group-id": { requireMention: false }
      },
      
      // 其他设置
      sendReadReceipts: true,
      mediaMaxMb: 50
    }
  }
}
```

#### Telegram

```json5
{
  channels: {
    telegram: {
      enabled: true,
      botToken: "123456:ABC...",  // 从 @BotFather 获取
      
      dmPolicy: "pairing",
      allowFrom: ["123456789", "@username"],
      
      groups: {
        "*": { requireMention: true },
        "-1001234567890": {
          requireMention: false,
          systemPrompt: "保持回答简洁"
        }
      },
      
      historyLimit: 50,
      replyToMode: "first",
      streamMode: "partial"
    }
  }
}
```

#### Discord

```json5
{
  channels: {
    discord: {
      enabled: true,
      token: "YOUR_BOT_TOKEN",
      
      dm: {
        enabled: true,
        policy: "pairing",
        allowFrom: ["user_id", "username"]
      },
      
      guilds: {
        "server_id": {
          requireMention: false,
          channels: {
            "general": { allow: true },
            "help": { allow: true, requireMention: true }
          }
        }
      }
    }
  }
}
```

### 沙箱配置

| 配置项 | 说明 | 选项 |
|--------|------|------|
| `mode` | 沙箱模式 | `off` / `non-main` / `all` |
| `scope` | 隔离范围 | `session` / `agent` / `shared` |
| `workspaceAccess` | 工作区权限 | `none` / `ro` / `rw` |
| `docker.network` | 网络模式 | `none` / `bridge` / `host` |
| `docker.memory` | 内存限制 | `"1g"`, `"512m"` |
| `docker.cpus` | CPU 限制 | `1`, `0.5` |

**推荐配置** (OrbStack 环境):

```json5
{
  sandbox: {
    mode: "all",           // 推荐: 所有会话使用沙箱 (保护 Mac 文件)
    scope: "agent",        // 每个 Agent 独立容器
    workspaceAccess: "rw", // 读写访问
    docker: {
      image: "openclaw-sandbox-common:bookworm-slim",
      network: "bridge",   // 浏览器自动化需要网络
      readOnlyRoot: true,
      tmpfs: ["/tmp:exec,mode=1777", "/var/tmp", "/run"],  // Playwright 需要
      user: "501:501",     // macOS 用户权限
      memory: "1g",
      cpus: 1,
      // 重要: 沙箱内需要的 API Key 必须在这里配置！
      env: {
        LANG: "C.UTF-8",
        OPENAI_API_KEY: "sk-xxx",
        GOOGLE_API_KEY: "AIzaSyxxx"
      }
    },
    browser: {
      enabled: true,
      autoStart: true,
      autoStartTimeoutMs: 30000,
      // 浏览器沙箱的环境变量单独配置
      env: {
        LANG: "C.UTF-8",
        OPENAI_API_KEY: "sk-xxx"
      }
    }
  }
}
```

> **注意**: OrbStack VM 通过 `/mnt/mac` 可访问 Mac 文件，所以 Docker 容器是唯一的隔离层。
> 即使设置 `network: "bridge"`，Mac 文件仍然受到保护，因为容器只能访问挂载的 `/workspace`。

> **重要**: 沙箱容器不会继承 Gateway 的环境变量！`sandbox.docker.env` 和 `sandbox.browser.env` 需要分别配置。详见 [sandbox.md](sandbox.md#environment-variables-重要)。

### TTS 语音配置

```json5
{
  messages: {
    tts: {
      auto: "inbound",  // off | always | inbound
      provider: "edge", // edge (免费) | openai | elevenlabs
      
      edge: {
        // 中文语音
        voice: "zh-CN-XiaoxiaoNeural"  // 女声
        // voice: "zh-CN-YunxiNeural"   // 男声
      }
    }
  }
}
```

**可用语音**:

| 语言 | 语音 ID | 性别 |
|------|---------|------|
| 中文 | `zh-CN-XiaoxiaoNeural` | 女 |
| 中文 | `zh-CN-YunxiNeural` | 男 |
| 中文 | `zh-CN-YunyangNeural` | 男 |
| 英文 | `en-US-JennyNeural` | 女 |
| 英文 | `en-US-GuyNeural` | 男 |

### Memory Search 配置

Memory Search 允许 AI 搜索历史记忆。**需要配置 embedding provider 才能工作**。

#### 基本配置

```json5
{
  agents: {
    defaults: {
      memorySearch: {
        provider: "auto",  // auto | openai | gemini | local
        // auto 模式会按以下顺序尝试:
        // 1. local (如果配置了 modelPath)
        // 2. openai (如果有 API key)
        // 3. gemini (如果有 API key)
      }
    }
  }
}
```

#### 重要：配置 Embedding API Key

Memory Search 需要调用 embedding API 生成向量索引。**必须在 agent 的 auth-profiles.json 中配置 OpenAI 或 Google 的 API key**：

```bash
# 编辑 agent auth 文件
nano ~/.openclaw/agents/main/agent/auth-profiles.json
```

在 `profiles` 中添加：

```json
{
  "profiles": {
    "openai:default": {
      "type": "api_key",
      "provider": "openai",
      "key": "sk-你的OpenAI-Key"
    }
  },
  "lastGood": {
    "openai": "openai:default"
  }
}
```

#### 验证配置

```bash
openclaw memory status --deep
# 应显示 Provider: openai 而不是 "No API key found"
```

#### 构建索引

```bash
openclaw memory index
```

#### 高级配置

```json5
{
  agents: {
    defaults: {
      memorySearch: {
        provider: "openai",
        model: "text-embedding-3-small",
        // Batch API (默认开启，便宜 50% 但较慢)
        remote: {
          batch: {
            enabled: true,    // 关闭则使用实时 API (快但贵)
            concurrency: 4
          }
        },
        // 混合搜索 (向量 + 文本)
        query: {
          hybrid: {
            enabled: true,
            vectorWeight: 0.7,
            textWeight: 0.3
          }
        }
      }
    }
  }
}
```

#### 使用本地 Embedding (免费)

如果不想用 OpenAI/Google API，可以使用本地模型：

```json5
{
  agents: {
    defaults: {
      memorySearch: {
        provider: "local"
        // OpenClaw 会自动下载本地 embedding 模型
      }
    }
  }
}
```

详见 [troubleshooting.md](troubleshooting.md#5-memory-search-无法使用--索引为空) 获取更多帮助。

---

### 工具权限配置

```json5
{
  tools: {
    // 工具配置文件 (预设)
    profile: "coding",  // minimal | coding | messaging | full
    
    // 允许的工具
    allow: ["exec", "read", "write", "edit", "browser"],
    
    // 禁止的工具
    deny: ["canvas", "cron", "gateway"],
    
    // 提权配置
    elevated: {
      enabled: true,
      allowFrom: {
        whatsapp: ["+8613800138000"],
        telegram: ["123456789"]
      }
    }
  }
}
```

**工具列表**:

| 工具 | 说明 |
|------|------|
| `exec` | 执行命令 |
| `read` | 读取文件 |
| `write` | 写入文件 |
| `edit` | 编辑文件 |
| `apply_patch` | 应用补丁 |
| `browser` | 浏览器操作 |
| `sessions_*` | 会话管理 |

---

## 环境变量支持

配置文件支持环境变量替换:

```json5
{
  auth: {
    profiles: {
      "anthropic:api": {
        provider: "anthropic",
        mode: "api_key"
      }
    }
  },
  
  // 使用环境变量
  gateway: {
    auth: {
      token: "${OPENCLAW_GATEWAY_TOKEN}"
    }
  }
}
```

**常用环境变量**:

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic API Key |
| `OPENAI_API_KEY` | OpenAI API Key |
| `GOOGLE_API_KEY` | Google API Key |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token |
| `DISCORD_BOT_TOKEN` | Discord Bot Token |
| `OPENCLAW_STATE_DIR` | 状态目录 |

---

## 配置验证

OpenClaw 使用严格的配置验证。如果配置无效：

1. Gateway 不会启动
2. 运行 `openclaw doctor` 查看具体问题
3. 运行 `openclaw doctor --fix` 自动修复

```bash
# 检查配置
openclaw-doctor

# 自动修复
openclaw-shell
cd ~/openclaw && docker compose run --rm openclaw-cli doctor --fix
```

---

## 常见问题

### Q: 如何获取 Telegram Bot Token?

1. 在 Telegram 中搜索 `@BotFather`
2. 发送 `/newbot`
3. 按提示设置 bot 名称
4. 获得 Token (格式: `123456789:ABCdefGHI...`)

### Q: WhatsApp 如何登录?

```bash
openclaw-whatsapp
```
扫描显示的二维码即可。

### Q: 如何切换模型?

在聊天中发送 `/model anthropic/claude-opus-4-5` 即可临时切换。

### Q: 配置热重载支持哪些选项?

热重载 (无需重启):
- `agents.defaults.*` (大部分)
- `tools.*`
- `bindings`
- `channels.*.allowFrom`
- `skills.*`

需要重启:
- `gateway.port`
- `channels.*.botToken`
- `plugins.*`

---

## 参考资料

- [官方文档](https://docs.openclaw.ai/gateway/configuration)
- [配置示例](https://docs.openclaw.ai/gateway/configuration-examples)
- [GitHub 仓库](https://github.com/openclaw/openclaw)
