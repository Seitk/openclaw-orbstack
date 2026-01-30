# OpenClaw OrbStack 部署

在 Mac 上通过 OrbStack 一键部署 OpenClaw，自带 Docker 沙箱安全隔离。

## 前置条件

- macOS 12.3+
- [OrbStack](https://orbstack.dev) 已安装并启动

## 安装

三种方式任选其一：

**方式 1 — 在终端里输入命令**

打开「终端」（在启动台搜索"终端"或"Terminal"），输入：

```bash
bash openclaw-orbstack-setup.sh
```

> 如果脚本不在当前目录，把文件直接拖进终端窗口，会自动填入完整路径。

**方式 2 — 拖进终端窗口**

1. 打开「终端」
2. 输入 `bash `（注意 bash 后面有个空格）
3. 把 `openclaw-orbstack-setup.sh` 文件从 Finder 拖进终端窗口
4. 按回车

**方式 3 — 右键打开**

1. 在 Finder 中右键点击 `openclaw-orbstack-setup.sh`
2. 选择「打开方式」>「终端」
3. 如果看不到终端选项，先运行一次 `chmod +x openclaw-orbstack-setup.sh`

## 可选环境变量

安装前可设置环境变量来自定义配置：

```bash
# 额外挂载目录 (逗号分隔)
export OPENCLAW_EXTRA_MOUNTS="$HOME/.ssh:/home/node/.ssh:ro,$HOME/projects:/home/node/projects:rw"

# 额外安装的 apt 包 (空格分隔)
export OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg imagemagick"

# 沙箱启动时执行的命令
export OPENCLAW_SETUP_COMMAND="apt-get update && apt-get install -y git curl"

# 自定义 DNS 服务器 (逗号分隔)
export OPENCLAW_DNS="1.1.1.1,8.8.8.8"

# 额外 hosts 映射 (逗号分隔)
export OPENCLAW_EXTRA_HOSTS="myservice:192.168.1.100"

# 然后运行安装
bash openclaw-orbstack-setup.sh
```

## 脚本做了什么

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1/8 | 检查 OrbStack | 确认 `orb` 命令可用 |
| 2/8 | 创建 Ubuntu VM | OrbStack 轻量虚拟机 `openclaw-vm` |
| 3/8 | 安装 Docker | VM 内安装 Docker Engine（官方脚本） |
| 4/8 | 克隆 OpenClaw | 从 GitHub 拉取源码到 `~/openclaw` |
| 5/8 | 构建镜像 | `openclaw:local` + 3 个沙箱镜像 |
| 6/8 | 写入沙箱配置 | 容器隔离、资源限制、工具权限 |
| 7/8 | 配置向导 | 输入 AI 模型 API Key 和聊天平台凭据 |
| 8/8 | 合并 + 便捷命令 | 配置合并，创建 Mac 端快捷命令 |

### 构建的镜像

| 镜像名称 | 用途 |
|---------|------|
| `openclaw:local` | 主程序（网关 + CLI） |
| `openclaw-sandbox:bookworm-slim` | 基础沙箱环境 |
| `openclaw-sandbox-browser:bookworm-slim` | 浏览器沙箱（含 Chromium） |
| `openclaw-sandbox-common:bookworm-slim` | 通用沙箱（含开发工具） |

## 沙箱安全配置

配置文件: `~/.openclaw/config.json`（VM 内）

| 设置项 | 值 | 含义 |
|--------|-----|------|
| mode | `non-main` | 非主会话在沙箱中执行 |
| scope | `agent` | 每个 Agent 一个独立容器 |
| workspaceAccess | `none` | 沙箱不访问宿主工作区 |
| network | `none` | 容器无网络访问 |
| readOnlyRoot | `true` | 根文件系统只读 |
| capDrop | `ALL` | 放弃所有 Linux capabilities |
| user | `1000:1000` | 非 root 用户运行 |
| memory | `1g`（swap `2g`） | 内存限制 |
| cpus | `1` | CPU 限制 |
| pidsLimit | `256` | 最大进程数 |
| ulimits.nofile | `1024/2048` | 文件描述符限制 |
| prune | `24h idle / 7d max` | 自动清理空闲容器 |
| browser | `enabled: true` | 浏览器工具已启用 |

### 工具权限

**允许:** exec, process, read, write, edit, apply_patch, sessions_*, browser

**禁止:** canvas, nodes, cron, discord, gateway

## 日常管理

### Mac 端命令

安装后会在 `~/bin/` 创建以下命令（需将 `~/bin` 加入 PATH）：

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

#### 服务管理

| 命令 | 功能 |
|------|------|
| `openclaw-status` | 查看服务状态 |
| `openclaw-logs` | 实时日志 |
| `openclaw-restart` | 重启服务 |
| `openclaw-stop` | 停止服务 |
| `openclaw-start` | 启动服务 |
| `openclaw-shell` | 进入 VM 终端 |
| `openclaw-doctor` | 运行诊断 |
| `openclaw-health` | 健康检查 |

#### 频道管理

| 命令 | 功能 |
|------|------|
| `openclaw-channels` | 列出所有频道 |
| `openclaw-whatsapp` | WhatsApp 登录（扫码） |
| `openclaw-telegram <token>` | 添加 Telegram Bot |
| `openclaw-discord <token>` | 添加 Discord Bot |

### 访问地址

Web 控制台: `http://openclaw-vm.orb.local:18789`

## 自定义配置

进入 VM 后编辑 `~/.openclaw/config.json`：

```bash
# 进入 VM
openclaw-shell

# 编辑配置
nano ~/.openclaw/config.json
```

常见调整：

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "workspaceAccess": "rw",
        "docker": {
          "network": "bridge",
          "memory": "2g",
          "setupCommand": "apt-get update && apt-get install -y git curl jq",
          "dns": ["1.1.1.1", "8.8.8.8"]
        },
        "browser": {
          "enabled": true,
          "headless": false
        }
      }
    }
  }
}
```

修改后重启：

```bash
openclaw-restart
```

## 多代理配置

可以为不同 Agent 设置不同的沙箱配置：

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main"
      }
    },
    "list": [
      {
        "id": "personal",
        "sandbox": {
          "workspaceAccess": "rw",
          "docker": { "network": "bridge" }
        }
      },
      {
        "id": "public",
        "sandbox": {
          "workspaceAccess": "none",
          "docker": { "network": "none" }
        },
        "tools": {
          "sandbox": {
            "tools": {
              "deny": ["exec", "write", "edit"]
            }
          }
        }
      }
    ]
  }
}
```

## 故障排查

### Docker 权限问题

```bash
openclaw-shell
sudo usermod -aG docker $USER
newgrp docker
```

### 镜像构建失败

```bash
openclaw-shell
docker system prune -a
cd ~/openclaw && docker build -t openclaw:local -f Dockerfile .
```

### 服务无法启动

```bash
openclaw-logs      # 查看日志
openclaw-doctor    # 运行诊断
openclaw-health    # 健康检查
```

### 沙箱容器问题

```bash
openclaw-shell

# 查看沙箱容器
docker ps -a | grep openclaw-sbx

# 清理所有沙箱容器
docker rm -f $(docker ps -aq --filter "name=openclaw-sbx")

# 重建沙箱镜像
cd ~/openclaw && ./scripts/sandbox-setup.sh
```
