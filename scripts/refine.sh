#!/bin/bash
# 手動トリガー用: think_refine_request を notifications/ に書き込む
# 使い方: bash refine.sh {IDEA_DIR} "#001 #002"

IDEA_DIR="${1:?引数エラー: IDEA_DIR を指定してください}"
APPROVED_IDS="${2:?引数エラー: APPROVED_IDS を指定してください}"

THINK_ROOT="$HOME/claude/claudeflow-think"
CLAUDEFLOW_ROOT="$HOME/claude/claudeflow"
NOTIFICATIONS_DIR="$CLAUDEFLOW_ROOT/notifications"
VAULT_DIR="$CLAUDEFLOW_ROOT/vault"
LOG="$THINK_ROOT/logs/watcher.log"
YQ=/opt/homebrew/bin/yq

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
mkdir -p "$NOTIFICATIONS_DIR"

CONFIG="$IDEA_DIR/.claudeflow-think.yaml"
[[ ! -f "$CONFIG" ]] && { log "ERROR: .claudeflow-think.yaml が見つかりません: $CONFIG"; exit 1; }

IDEA_SLUG="$(basename "$IDEA_DIR")"
IDEA_NAME=$($YQ '.name' "$CONFIG")
IDEA_FILE="$IDEA_DIR/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
REFINE_PROMPT=$($YQ '.refine_prompt' "$CONFIG")
VAULT_REVIEW_PATH="$VAULT_DIR/reviews/think/$IDEA_SLUG/REVIEW.md"

NOTIF="$NOTIFICATIONS_DIR/think_refine_$(date '+%Y%m%d_%H%M%S').json"
python3 -c "
import json
payload = {
  'type': 'think_refine_request',
  'idea_slug': '$IDEA_SLUG',
  'idea_name': '$IDEA_NAME',
  'idea_dir': '$IDEA_DIR',
  'idea_file': '$IDEA_FILE',
  'review_file': '$IDEA_DIR/REVIEW.md',
  'vault_review_path': '$VAULT_REVIEW_PATH',
  'refine_prompt': '''$REFINE_PROMPT''',
  'approved_ids': '$APPROVED_IDS',
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"

log "[$IDEA_NAME] think_refine_request 書き込み完了: $NOTIF ($APPROVED_IDS)"
echo "✅ think_refine_request を書き込みました: $APPROVED_IDS"
echo "   メインセッション（claude-discord）が次のターンで処理します"
