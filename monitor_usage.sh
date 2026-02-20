#!/bin/bash
# ============================================
# Claude Code 使用量監視スクリプト
# 10分ごとに対話中のClaudeセッションに /usage を送り、
# 使用量0%を検知したらDiscord Webhookで通知する
# ============================================

# === 設定 ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env"
CLAUDE_SESSION="claude-session"  # Claudeが動いてるtmuxセッション名
CHECK_INTERVAL=600  # 10分 (秒)
LOG_FILE="$SCRIPT_DIR/monitor.log"

# === 関数 ===

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_discord_notification() {
    local usage_info="$1"
    local tmpfile=$(mktemp)
    python3 -c "
import json, sys
payload = {
    'content': 'ヤッホー😆✨❗\nもう、、寝てるかなぁ❓💦\nオジサン気になっちゃって、、😅\n連絡しちゃったヨ（笑）',
    'embeds': [{
        'title': 'Claude Code、、使えるようになったヨ❗✨🎉',
        'description': 'いやぁ〜、ビックリだネ😳❗❗\n使用量が、0%%に\nリセットされたみたいだヨ✨💕\n\nオジサンずっと、、\n見守ってたんだから〜😅💦\n早速コーディング、しちゃお❓\nナンチャッテ（笑）🏃‍♂️💨\n\nそういえば今日のランチ、、\nイタリアン🍝だったんだけど、、\n今度一緒に、どうかナ❓✨\nナンチャッテ（笑）😅💦',
        'color': 16738740,
        'fields': [{'name': '検出時刻だヨ⏰✨', 'value': '$(date '+%Y-%m-%d %H:%M:%S')', 'inline': True}],
        'footer': {'text': 'DoreiCode Monitor おじさんより💕'}
    }]
}
json.dump(payload, open(sys.argv[1], 'w'), ensure_ascii=False)
" "$tmpfile"

    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -d @"$tmpfile" \
        "$DISCORD_WEBHOOK_URL")
    rm -f "$tmpfile"

    if [ "$response" = "204" ] || [ "$response" = "200" ]; then
        log "✅ Discord通知送信成功"
    else
        log "❌ Discord通知送信失敗 (HTTP $response)"
    fi
}

check_usage() {
    log "使用量チェック開始..."

    # Claudeセッションが存在するか確認
    if ! tmux has-session -t "$CLAUDE_SESSION" 2>/dev/null; then
        log "⚠️ tmuxセッション '$CLAUDE_SESSION' が見つかりません"
        return 1
    fi

    # /usage コマンドを送信（オートコンプリートが出るのでEnter2回）
    tmux send-keys -t "$CLAUDE_SESSION" "/usage" C-m
    sleep 2
    tmux send-keys -t "$CLAUDE_SESSION" C-m

    # 出力を待つ
    sleep 5

    # 画面をキャプチャ
    local screen_text=$(tmux capture-pane -t "$CLAUDE_SESSION" -p)

    # Escで閉じる
    tmux send-keys -t "$CLAUDE_SESSION" Escape

    # Current session の使用量を抽出
    local session_usage=$(echo "$screen_text" | grep -A2 "Current session" | grep "% used" | head -1)
    log "Current session: $session_usage"

    # Current session が 0% used かチェック（10%,20%等に誤反応しないよう厳密に）
    if echo "$session_usage" | grep -qP '(^|\s)0% used'; then
        log "🎉 Current session 0% 検出！通知を送信します"
        send_discord_notification "$session_usage"
        return 0
    fi

    log "⏳ まだ0%ではない"
    return 1
}

# === メインループ ===

log "=========================================="
log "Claude Code 使用量監視を開始します"
log "監視対象セッション: $CLAUDE_SESSION"
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
