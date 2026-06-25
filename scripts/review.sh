#!/bin/bash
# 手動トリガー: bash review.sh {idea-slug}
set -euo pipefail

IDEA_SLUG="${1:?引数エラー: idea-slug を指定してください}"

THINK_ROOT="$HOME/claude/claudeflow-think"
CLAUDEFLOW_ROOT="$HOME/claude/claudeflow"
NOTIFICATIONS_DIR="$CLAUDEFLOW_ROOT/notifications"
VAULT_DIR="$CLAUDEFLOW_ROOT/vault"
LOG="$THINK_ROOT/logs/watcher.log"
YQ=/opt/homebrew/bin/yq

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
mkdir -p "$NOTIFICATIONS_DIR"

IDEA_DIR="$THINK_ROOT/ideas/$IDEA_SLUG"
CONFIG="$IDEA_DIR/.claudeflow-think.yaml"
[[ ! -f "$CONFIG" ]] && { echo "ERROR: $CONFIG が見つかりません"; exit 1; }

IDEA_NAME=$($YQ '.name' "$CONFIG")
IDEA_FILE="$IDEA_DIR/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
CONTEXT=$($YQ '.context // ""' "$CONFIG")
REVIEW_PROMPT=$($YQ '.review_prompt' "$CONFIG")
VAULT_REVIEW_DIR="$VAULT_DIR/reviews/claudeflow-think/$IDEA_SLUG"

NOTIF="$NOTIFICATIONS_DIR/think_review_$(date '+%Y%m%d_%H%M%S').json"
python3 -c "
import json
payload = {
  'type': 'think_review_request',
  'idea_slug': '$IDEA_SLUG',
  'idea_name': '$IDEA_NAME',
  'idea_dir': '$IDEA_DIR',
  'idea_file': '$IDEA_FILE',
  'review_file': '$IDEA_DIR/REVIEW.md',
  'think_root': '$THINK_ROOT',
  'vault_review_dir': '$VAULT_REVIEW_DIR',
  'context': '''$CONTEXT''',
  'review_prompt': '''$REVIEW_PROMPT''',
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"

log "[$IDEA_NAME] think_review_request 書き込み完了: $NOTIF"
echo "✅ think_review_request を書き込みました → メインセッションが次ターンで処理します"
