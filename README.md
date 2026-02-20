# DoreiCode

Claude Code の使用量を自動監視し、Current session の使用量が 0%（リセット済み）になったら Discord におじさん構文で通知するスクリプト。

## セットアップ

### 1. `.env` を作成

```bash
cp .env.example .env
```

`.env` に Discord Webhook URL を設定:

```
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxxx/yyyyy"
```

### 2. 実行権限を付与

```bash
chmod +x monitor_usage.sh
```

### 3. Claude Code の対話セッションを起動

```bash
tmux new -s claude-session
claude
# Ctrl+b → d でデタッチ
```

### 4. 監視スクリプトを起動

```bash
tmux new -s claude-monitor
./monitor_usage.sh
# Ctrl+b → d でデタッチ
```

### 5. 後で確認・復帰

```bash
tmux attach -s claude-monitor   # 監視スクリプト
tmux attach -s claude-session   # Claude対話セッション
tail -f monitor.log             # ログをリアルタイム確認
```

## 仕組み

1. `tmux send-keys` で `claude-session` に `/usage` コマンドを送信
2. `tmux capture-pane` で画面をキャプチャ
3. Current session の使用量が `0% used` なら Discord Webhook で通知
4. 10分ごとに繰り返し
5. ログは `monitor.log` に記録
