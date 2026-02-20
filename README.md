# DoreiCode

Claude Code の使用量を自動監視し、使用量が 0%（リセット済み）になったら Discord に通知するスクリプト。

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

### 3. tmux で起動

```bash
tmux new -s claude-monitor
./monitor_usage.sh
# Ctrl+b → d でデタッチ
```

### 4. 後で確認・復帰

```bash
tmux attach -s claude-monitor
```

## 仕組み

- 10分ごとに `claude -p "/limit"` を実行
- 出力に `0%` が含まれていたら Discord Webhook で通知
- ログは `monitor.log` に記録
