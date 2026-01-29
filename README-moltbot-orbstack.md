# Moltbot OrbStack 部署

在 Mac 上通过 OrbStack 一键部署 Moltbot，自带 Docker 沙箱安全隔离。

## 前置条件

- macOS 12.3+
- [OrbStack](https://orbstack.dev) 已安装并启动

## 安装

三种方式任选其一：

**方式 1 — 在终端里输入命令**

打开「终端」（在启动台搜索"终端"或"Terminal"），输入：

```bash
bash moltbot-orbstack-setup.sh
```

> 如果脚本不在当前目录，把文件直接拖进终端窗口，会自动填入完整路径。

**方式 2 — 拖进终端窗口**

1. 打开「终端」
2. 输入 `bash `（注意 bash 后面有个空格）
3. 把 `moltbot-orbstack-setup.sh` 文件从 Finder 拖进终端窗口
4. 按回车

**方式 3 — 右键打开**

1. 在 Finder 中右键点击 `moltbot-orbstack-setup.sh`
2. 选择「打开方式」>「终端」
3. 如果看不到终端选项，先运行一次 `chmod +x moltbot-orbstack-setup.sh`

## 脚本做了什么

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1/8 | 检查 OrbStack | 确认 `orb` 命令可用 |
| 2/8 | 创建 Ubuntu VM | OrbStack 轻量虚拟机 `moltbot-vm` |
| 3/8 | 安装 Docker | VM 内安装 Docker Engine（官方脚本） |
| 4/8 | 克隆 Moltbot | 从 GitHub 拉取源码到 `~/moltbot` |
| 5/8 | 构建镜像 | `moltbot:local` + `moltbot-sandbox:bookworm-slim` |
| 6/8 | 写入沙箱配置 | 容器隔离、资源限制、工具权限（见下表） |
| 7/8 | 配置向导 | 输入 AI 模型 API Key（OpenCode Zen / Anthropic / OpenAI 等）和聊天平台凭据 |
| 8/8 | 合并 + 便捷命令 | 配置合并，创建 Mac 端快捷命令 |

## 沙箱安全配置

配置文件: `~/.clawdbot/sandbox-config.json`（VM 内）

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

### 工具权限

**允许:** exec, process, read, write, edit, apply_patch, sessions_*

**禁止:** browser, canvas, nodes, cron, discord, gateway

## 日常管理

### Mac 端命令

安装后会在 `~/bin/` 创建以下命令（需将 `~/bin` 加入 PATH）：

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

| 命令 | 功能 |
|------|------|
| `moltbot-status` | 查看服务状态 |
| `moltbot-logs` | 实时日志 |
| `moltbot-restart` | 重启服务 |
| `moltbot-stop` | 停止服务 |
| `moltbot-start` | 启动服务 |
| `moltbot-shell` | 进入 VM 终端 |
| `moltbot-doctor` | 运行诊断 |

### 访问地址

Web 控制台: `http://moltbot-vm.orb.local:18789`

## 自定义配置

进入 VM 后编辑 `~/.clawdbot/config.json`：

```bash
# 进入 VM
moltbot-shell

# 编辑配置
nano ~/.clawdbot/config.json
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
          "memory": "2g"
        },
        "browser": {
          "enabled": true
        }
      }
    }
  }
}
```

修改后重启：

```bash
docker compose restart moltbot-gateway
```

## 故障排查

### Docker 权限问题

```bash
moltbot-shell
sudo usermod -aG docker $USER
newgrp docker
```

### 镜像构建失败

```bash
moltbot-shell
docker system prune -a
cd ~/moltbot && docker build -t moltbot:local -f Dockerfile .
```

### 服务无法启动

```bash
moltbot-logs      # 查看日志
moltbot-doctor    # 运行诊断
```
