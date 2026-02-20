#!/bin/bash
# ============================================
# Claude Code 使用量監視スクリプト
# 10分ごとにClaude Codeの利用状況をチェックし、
# 使用量0%（リセット済み）を検知したらDiscord Webhookで通知する
# ============================================

# === 設定 ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env"
CHECK_INTERVAL=600  # 10分 (秒)
LOG_FILE="$SCRIPT_DIR/monitor.log"

# === 関数 ===

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_discord_notification() {
    local usage_info="$1"
    local payload=$(cat <<EOF
{
  "content": "🎉 **Claude Code 使用量リセット通知** 🎉",
  "embeds": [{
    "title": "使用量0% - 使えるようになりました！",
    "description": "Claude Codeの使用量がリセットされました。今すぐ使えます！",
    "color": 5763719,
    "fields": [{
      "name": "検出時刻",
      "value": "$(date '+%Y-%m-%d %H:%M:%S')",
      "inline": true
    },
    {
      "name": "出力内容",
      "value": "$(echo "$usage_info" | head -5 | sed 's/"/\\"/g')",
      "inline": false
    }],
    "footer": {
      "text": "DoreiCode Monitor"
    }
  }]
}
EOF
)

    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$DISCORD_WEBHOOK_URL")

    if [ "$response" = "204" ] || [ "$response" = "200" ]; then
        log "✅ Discord通知送信成功"
    else
        log "❌ Discord通知送信失敗 (HTTP $response)"
    fi
}

check_usage() {
    log "使用量チェック開始..."

    # CLAUDECODE環境変数をクリアして入れ子実行エラーを回避
    local output=$(unset CLAUDECODE; claude -p "/limit" 2>&1)
    local exit_code=$?

    log "出力: $output"

    # 0% を検出（使用量0% = リセット済み、使える状態）
    if echo "$output" | grep -q "0%"; then
        log "🎉 使用量0% 検出！通知を送信します"
        send_discord_notification "$output"
        return 0
    fi

    log "⏳ まだ使用中（0%ではない）"
    return 1
}

# === メインループ ===

log "=========================================="
log "Claude Code 使用量監視を開始します"
log "チェック間隔: ${CHECK_INTERVAL}秒 ($(( CHECK_INTERVAL / 60 ))分)"
log "=========================================="

# Webhook URLのチェック
if [ "$DISCORD_WEBHOOK_URL" = "YOUR_DISCORD_WEBHOOK_URL_HERE" ]; then
    log "⚠️  Discord Webhook URLが設定されていません！"
    log "スクリプト内の DISCORD_WEBHOOK_URL を設定してください"
    exit 1
fi

while true; do
    check_usage

    log "次のチェックまで ${CHECK_INTERVAL}秒 待機..."
    sleep "$CHECK_INTERVAL"
done
