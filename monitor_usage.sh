#!/bin/bash
# ============================================
# Claude Code 使用量監視スクリプト (cron対応版)
# cronから10分ごとに呼び出し、
# 対話中のClaudeセッションに /usage を送り、
# 使用量0%を検知したらDiscord Webhookで通知する
#
# crontab設定例:
#   */10 * * * * /home/user/DoreiCode/monitor_usage.sh
# ============================================

# === 設定 ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env"
CLAUDE_SESSION="claude-session"  # Claudeが動いてるtmuxセッション名
LOG_FILE="$SCRIPT_DIR/monitor.log"
CSV_FILE="$SCRIPT_DIR/usage_history.csv"
LOCK_FILE="/tmp/doreicode_monitor.lock"

# === 重複実行防止 (flock) ===
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ 前回の実行がまだ終わっていません。スキップします" >> "$LOG_FILE"
    exit 0
fi

# === 関数 ===

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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

    # /usage コマンドを送信（オートコンプリート確定のEnter1回のみ）
    tmux send-keys -t "$CLAUDE_SESSION" "/usage" C-m
    sleep 2
    # オートコンプリート確定
    tmux send-keys -t "$CLAUDE_SESSION" C-m

    # ダイアログ表示を待つ
    sleep 5

    # 画面をキャプチャ
    local screen_text=$(tmux capture-pane -t "$CLAUDE_SESSION" -p)

    # Escで閉じる
    tmux send-keys -t "$CLAUDE_SESSION" Escape

    # Current session の使用量を抽出
    local session_usage=$(echo "$screen_text" | grep -A2 "Current session" | grep "% used" | head -1)
    local percent=$(echo "$session_usage" | grep -oP '\d+(?=% used)')
    log "Current session: ${percent:-取得失敗}% used"

    # CSVに記録
    if [ -n "$percent" ]; then
        # ヘッダーがなければ作成
        [ ! -f "$CSV_FILE" ] && echo "timestamp,percent" > "$CSV_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$percent" >> "$CSV_FILE"
    fi

    # Current session が 0% used かチェック（10%,20%等に誤反応しないよう厳密に）
    if echo "$session_usage" | grep -qP '(^|\s)0% used'; then
        log "🎉 Current session 0% 検出！通知を送信します"
        send_discord_notification "$session_usage"
        return 0
    fi

    log "⏳ まだ0%ではない"
    return 1
}

# === メイン（1回実行して終了） ===

# Webhook URLのチェック
if [ "$DISCORD_WEBHOOK_URL" = "YOUR_DISCORD_WEBHOOK_URL_HERE" ]; then
    log "⚠️  Discord Webhook URLが設定されていません！"
    exit 1
fi

check_usage
