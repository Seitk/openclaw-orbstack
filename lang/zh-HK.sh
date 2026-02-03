#!/bin/bash
# shellcheck disable=SC2034
# All variables are used externally via `source` in other scripts
# ============================================================================
# OpenClaw 粵語語言包
# ============================================================================

# --- 腳本頭部 ---
MSG_SCRIPT_TITLE="OpenClaw OrbStack 一鍵部署腳本 (本地安裝版)"

# --- 步驟標題 ---
MSG_STEP_1="檢查 OrbStack"
MSG_STEP_2="建立 Ubuntu VM"
MSG_STEP_3="安裝 Docker"
MSG_STEP_4="安裝 Node.js"
MSG_STEP_5="複製並建置 OpenClaw"
MSG_STEP_6="建置沙盒鏡像"
MSG_STEP_7="執行設定精靈"
MSG_STEP_8="設定服務與便捷指令"

# --- Step 1: OrbStack ---
MSG_ERR_NO_ORBSTACK="未檢測到 OrbStack"
MSG_INSTALL_ORBSTACK_1="請先安裝："
MSG_INSTALL_ORBSTACK_2="  1. 去 https://orbstack.dev 下載安裝"
MSG_INSTALL_ORBSTACK_3="  2. 啟動 OrbStack 完成初始化"
MSG_INSTALL_ORBSTACK_4="  3. 重新執行呢個腳本"
MSG_OK_ORBSTACK="OrbStack 已安裝"

# --- Step 2: VM ---
MSG_OK_VM_EXISTS="虛擬機 '%s' 已經存在"
MSG_INFO_STARTING_VM="啟動虛擬機..."
MSG_INFO_CREATING_VM="建立虛擬機: %s (%s)"
MSG_OK_VM_READY="虛擬機已準備就緒"

# --- Step 3: Docker ---
MSG_OK_DOCKER_INSTALLED="Docker 已安裝"
MSG_INFO_INSTALLING_DOCKER="安裝 Docker Engine..."
MSG_OK_DOCKER_STARTED="Docker 服務已啟動"

# --- Step 4: Node.js ---
MSG_OK_NODE_INSTALLED="Node.js 已安裝"
MSG_INFO_NODE_UPGRADE="Node.js %s 版本太舊，升級到 22.x..."
MSG_OK_NODE_UPGRADED="Node.js 已升級"
MSG_INFO_INSTALLING_NODE="安裝 Node.js 22.x..."
MSG_OK_PNPM_INSTALLED="pnpm 已安裝"
MSG_INFO_INSTALLING_PNPM="安裝 pnpm..."

# --- Step 5: Build ---
MSG_INFO_REPO_EXISTS="倉庫已經存在，拉取最新程式碼..."
MSG_INFO_CLONING="複製倉庫..."
MSG_INFO_NPM_INSTALL="安裝依賴 (npm install)..."
MSG_INFO_NPM_BUILD="編譯項目 (npm run build)..."
MSG_INFO_UI_BUILD="建置 Control UI..."
MSG_INFO_GLOBAL_INSTALL="全域安裝 CLI..."
MSG_OK_BUILD_DONE="OpenClaw 建置完成 (CLI: openclaw)"

# --- Step 6: Sandbox ---
MSG_INFO_SANDBOX_BASE="建置基礎沙盒鏡像 (sandbox-common 嘅建置依賴)..."
MSG_OK_SANDBOX_BASE="sandbox 基礎鏡像建置完成"
MSG_OK_SANDBOX_BASE_DF="sandbox 基礎鏡像建置完成 (Dockerfile)"
MSG_WARN_SANDBOX_BASE_FAIL="sandbox 基礎鏡像建置失敗，sandbox-common 可能都會失敗"
MSG_INFO_SANDBOX_BROWSER="建置瀏覽器沙盒鏡像..."
MSG_OK_SANDBOX_BROWSER="sandbox-browser 鏡像建置完成"
MSG_OK_SANDBOX_BROWSER_DF="sandbox-browser 鏡像建置完成 (Dockerfile)"
MSG_WARN_SANDBOX_BROWSER_FAIL="sandbox-browser 鏡像建置失敗，跳過"
MSG_INFO_SANDBOX_COMMON="建置 common 沙盒鏡像 (基於基礎鏡像，加裝開發工具)..."
MSG_OK_SANDBOX_COMMON="sandbox-common 鏡像建置完成"
MSG_WARN_SANDBOX_COMMON_FAIL="sandbox-common 鏡像建置失敗 (需要基礎鏡像先建置成功)"

# --- Step 7: Onboard ---
MSG_INFO_ONBOARD_INTRO="接落嚟進入互動設定精靈 (onboard)，請準備："
MSG_INFO_ONBOARD_API="  - AI 模型 API Key（支援 Anthropic / OpenAI / OpenRouter 等）"
MSG_INFO_ONBOARD_TOKEN="  - Telegram Bot Token (從 @BotFather 攞) 或其他平台憑證"
MSG_PRESS_ENTER="撳 Enter 繼續..."
MSG_OK_ONBOARD_DONE="設定精靈完成"
MSG_INFO_EXTRACTING_ENV="提取敏感資訊到 .env 檔案..."
MSG_OK_ENV_EXTRACTED="敏感資訊已提取到 ~/.openclaw/.env"
MSG_INFO_CREATING_MEMORY="建立 memory 索引目錄..."
MSG_OK_MEMORY_CREATED="memory 索引目錄已建立"

# --- Step 8: Service & Commands ---
MSG_INFO_CREATING_SERVICE="建立 systemd 服務..."
MSG_OK_GATEWAY_STARTED="Gateway 服務已啟動"
MSG_WARN_GATEWAY_ISSUE="Gateway 服務啟動可能有問題，請檢查: openclaw-logs"
MSG_OK_COMMANDS_CREATED="便捷指令已建立"
MSG_INFO_SANDBOX_CONFIG="寫入沙盒設定..."
MSG_OK_SANDBOX_CONFIG="沙盒設定已寫入"
MSG_INFO_PATH_ADDED="已將 ~/bin 加到 PATH (%s)"

# --- Mac 指令內嵌文字 ---
# openclaw
MSG_CMD_CLI_COMMENT="OpenClaw CLI - 透傳到 VM 嘅官方 CLI"

# openclaw-config
MSG_CMD_CONFIG_OPENING="開緊設定編輯器..."
MSG_CMD_CONFIG_SAVED="設定已儲存。執行 openclaw-restart 使更改生效。"
MSG_CMD_CONFIG_BACKED_UP="已備份到: %s"
MSG_CMD_CONFIG_USAGE="用法: openclaw-config [edit|show|backup]"

# openclaw-update
MSG_CMD_UPDATE_USAGE="用法: openclaw-update [--sandbox]"
MSG_CMD_UPDATE_DESC="更新 OpenClaw 應用到最新版本。"
MSG_CMD_UPDATE_OPTIONS="選項:"
MSG_CMD_UPDATE_SANDBOX_OPT="  --sandbox    同時重建沙盒 Docker 鏡像"
MSG_CMD_UPDATE_TIP="提示: 單獨重建沙盒可用 openclaw-sandbox-rebuild"
MSG_CMD_UPDATE_UPDATING="🔄 更新緊 OpenClaw..."
MSG_CMD_UPDATE_STOPPING="  停止服務..."
MSG_CMD_UPDATE_PULLING="  拉取最新程式碼..."
MSG_CMD_UPDATE_INSTALLING="  安裝依賴..."
MSG_CMD_UPDATE_BUILDING="  編譯項目..."
MSG_CMD_UPDATE_UI="  建置 Control UI..."
MSG_CMD_UPDATE_REINSTALL="  重新安裝 CLI..."
MSG_CMD_UPDATE_SANDBOX_REBUILD="  重建沙盒鏡像..."
MSG_CMD_UPDATE_SANDBOX_BASE="    建置基礎鏡像..."
MSG_CMD_UPDATE_SANDBOX_COMMON="    建置 common 鏡像..."
MSG_CMD_UPDATE_SANDBOX_BROWSER="    建置瀏覽器鏡像..."
MSG_CMD_UPDATE_SANDBOX_NOTE="  💡 已執行嘅容器仍使用舊鏡像，重啟後生效"
MSG_CMD_UPDATE_STARTING="  啟動服務..."
MSG_CMD_UPDATE_DONE="✅ 更新完成！"
MSG_CMD_UPDATE_SANDBOX_HINT="💡 如需重建沙盒鏡像: openclaw-update --sandbox"

# openclaw-sandbox-rebuild
MSG_CMD_REBUILD_START="🔨 重建緊沙盒 Docker 鏡像..."
MSG_CMD_REBUILD_BASE="  建置基礎沙盒鏡像..."
MSG_CMD_REBUILD_BASE_OK="  ✓ sandbox 基礎鏡像建置完成"
MSG_CMD_REBUILD_BASE_OK_DF="  ✓ sandbox 基礎鏡像建置完成 (Dockerfile)"
MSG_CMD_REBUILD_BASE_FAIL="  ✗ sandbox 基礎鏡像建置失敗（sandbox-common 可能都會失敗）"
MSG_CMD_REBUILD_COMMON="  建置 common 沙盒鏡像..."
MSG_CMD_REBUILD_COMMON_OK="  ✓ sandbox-common 鏡像建置完成"
MSG_CMD_REBUILD_COMMON_FAIL="  ✗ sandbox-common 鏡像建置失敗"
MSG_CMD_REBUILD_BROWSER="  建置瀏覽器沙盒鏡像..."
MSG_CMD_REBUILD_BROWSER_OK="  ✓ sandbox-browser 鏡像建置完成"
MSG_CMD_REBUILD_BROWSER_OK_DF="  ✓ sandbox-browser 鏡像建置完成 (Dockerfile)"
MSG_CMD_REBUILD_BROWSER_FAIL="  ✗ sandbox-browser 鏡像建置失敗"
MSG_CMD_REBUILD_DONE="✅ 沙盒鏡像重建完成！"
MSG_CMD_REBUILD_NOTE="💡 已執行嘅容器仍使用舊鏡像，執行 openclaw-restart 使新鏡像生效"

# openclaw-telegram
MSG_CMD_TG_COMMENT="Telegram Bot 管理"
MSG_CMD_TG_ADD_USAGE="用法: openclaw-telegram add <bot_token>"
MSG_CMD_TG_ADD_HINT="從 @BotFather 攞 token"
MSG_CMD_TG_APPROVE_USAGE="用法: openclaw-telegram approve <pairing_code>"
MSG_CMD_TG_APPROVE_HINT="輸入 Bot 發畀你嘅配對碼"
MSG_CMD_TG_TITLE="Telegram Bot 管理"
MSG_CMD_TG_USAGE="用法:"
MSG_CMD_TG_ADD_DESC="  openclaw-telegram add <bot_token>      加 Bot (從 @BotFather 攞)"
MSG_CMD_TG_APPROVE_DESC="  openclaw-telegram approve <code>       批准配對 (回執驗證碼)"
MSG_CMD_TG_ALT="或直接用:"
MSG_CMD_TG_ALT_CMD="  openclaw channels login --channel telegram"

# openclaw-whatsapp
MSG_CMD_WA_COMMENT="WhatsApp 登入 (掃碼)"

# --- 完成輸出 ---
MSG_FINAL_COMPLETE="部署完成！"
MSG_FINAL_ARCH="架構:"
MSG_FINAL_ARCH_DETAIL_1="  Mac → OrbStack → Ubuntu VM"
MSG_FINAL_ARCH_DETAIL_2="                   ├── Gateway (systemd 服務)"
MSG_FINAL_ARCH_DETAIL_3="                   └── Docker (沙盒容器)"
MSG_FINAL_ACCESS="訪問地址"
MSG_FINAL_MAC_COMMANDS="Mac 端指令:"
MSG_FINAL_CMD_CLI="CLI 入口 (透傳所有參數)"
MSG_FINAL_CMD_CONFIG="編輯設定"
MSG_FINAL_CMD_STATUS="服務狀態"
MSG_FINAL_CMD_LOGS="即時日誌"
MSG_FINAL_CMD_RESTART="重啟服務"
MSG_FINAL_CMD_UPDATE="更新版本 (僅應用，--sandbox 重建鏡像)"
MSG_FINAL_CMD_REBUILD="重建沙盒鏡像"
MSG_FINAL_CMD_DOCTOR="執行診斷"
MSG_FINAL_CMD_SHELL="進入 VM"
MSG_FINAL_SANDBOX_TITLE="沙盒容器 (由 Gateway 按需建立):"
MSG_FINAL_SANDBOX_COMMON="  - openclaw-sandbox-common   程式碼執行 (bridge 網絡)"
MSG_FINAL_SANDBOX_BROWSER="  - openclaw-sandbox-browser  瀏覽器自動化"

# --- refresh-mac-commands.sh ---
MSG_REFRESH_START="🔄 重新生成緊 Mac 端便捷指令..."
MSG_REFRESH_DONE="✅ Mac 端便捷指令已更新！"
MSG_REFRESH_LIST_HEADER="已生成以下指令:"
MSG_REFRESH_CMD_CLI="  openclaw                CLI 透傳"
MSG_REFRESH_CMD_STATUS="  openclaw-status         服務狀態"
MSG_REFRESH_CMD_LOGS="  openclaw-logs           即時日誌"
MSG_REFRESH_CMD_RESTART="  openclaw-restart        重啟服務"
MSG_REFRESH_CMD_STARTSTOP="  openclaw-stop/start     停止/啟動"
MSG_REFRESH_CMD_SHELL="  openclaw-shell          進入 VM"
MSG_REFRESH_CMD_CONFIG="  openclaw-config         設定管理"
MSG_REFRESH_CMD_UPDATE="  openclaw-update         更新版本"
MSG_REFRESH_CMD_REBUILD="  openclaw-sandbox-rebuild 重建沙盒鏡像"
MSG_REFRESH_CMD_TELEGRAM="  openclaw-telegram       Telegram 管理"
MSG_REFRESH_CMD_WHATSAPP="  openclaw-whatsapp       WhatsApp 登入"
MSG_REFRESH_PATH_HINT="確保 ~/bin 喺 PATH 入面: export PATH=\"\$HOME/bin:\$PATH\""

# --- repair-existing-install.sh ---
MSG_REPAIR_TITLE="OpenClaw 安裝修復"
MSG_REPAIR_DETECTING="檢測緊安裝狀態..."
MSG_REPAIR_NOT_NEEDED="安裝已係最新狀態，唔使修復。"
MSG_REPAIR_VM_MIGRATING="遷移 VM 服務（系統級 → 用戶級）..."
MSG_REPAIR_VM_STOP_SYSTEM="停止系統級服務..."
MSG_REPAIR_VM_DISABLE_SYSTEM="禁用並刪除系統級服務..."
MSG_REPAIR_VM_KILL_PORT="清理端口同 lock 檔案..."
MSG_REPAIR_VM_ENABLE_LINGER="啟用 lingering（允許用戶服務喺未登入時執行）..."
MSG_REPAIR_VM_ENABLE_USER="啟用用戶級 gateway 服務..."
MSG_REPAIR_VM_START="啟動 gateway..."
MSG_REPAIR_VM_DONE="VM 服務遷移完成"
MSG_REPAIR_MAC_UPDATING="更新 Mac 端指令..."
MSG_REPAIR_MAC_DONE="Mac 端指令已更新"
MSG_REPAIR_VERIFY="驗證 gateway 狀態..."
MSG_REPAIR_DONE="修復完成！"
MSG_REPAIR_COMMANDS_HINT="而家可以用以下指令管理 gateway："
MSG_REPAIR_FULL_REFRESH_HINT="如需重新生成所有 Mac 指令: bash scripts/refresh-mac-commands.sh"

# --- openclaw-update 自動修復 ---
MSG_UPDATE_AUTO_UPGRADE="🔧 檢測到舊版服務設定，自動修復緊..."
MSG_UPDATE_AUTO_UPGRADE_DONE="✓ 服務設定已修復，繼續更新..."
MSG_UPDATE_ENV_CREATED="✓ 已建立 ~/.openclaw/.env（Bonjour 設定）"
