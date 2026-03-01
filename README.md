# DoreiCode

Claude Code の使用量を自動監視し、Current session の使用量が 0%（リセット済み）になったら Discord におじさん構文で通知するスクリプト。

cron で10分ごとに実行するため、監視用の tmux セッションが不要。

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

### 4. cron に登録

```bash
crontab -e
```

以下を追加（パスは環境に合わせて変更）:

```
*/10 * * * * /home/user/DoreiCode/monitor_usage.sh
```

### 5. 動作確認

```bash
# cron が動いてるか確認
systemctl status cron

# ログをリアルタイム確認
tail -f monitor.log

# 手動で1回テスト実行
./monitor_usage.sh
```

## 仕組み

1. cron が10分ごとにスクリプトを起動
2. `flock` で重複実行を防止
3. `tmux send-keys` で `claude-session` に `/usage` コマンドを送信
4. `tmux capture-pane` で画面をキャプチャ
5. Current session の使用量が `0% used` なら Discord Webhook でおじさん構文通知
6. スクリプト終了（待機中のメモリ消費ゼロ）
7. ログは `monitor.log`、使用量推移は `usage_history.csv` に記録
