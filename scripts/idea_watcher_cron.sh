#!/bin/bash
# ideas/*/idea.md 変更 → think_review_request
# vault REVIEW.md [x] 変更 → think_refine_request

THINK_ROOT="$HOME/claude/claudeflow-think"
CLAUDEFLOW_ROOT="$HOME/claude/claudeflow"
VAULT_DIR="$CLAUDEFLOW_ROOT/vault"
NOTIFICATIONS_DIR="$CLAUDEFLOW_ROOT/notifications"
IDEAS_ROOT="$THINK_ROOT/ideas"
STATE_DIR="$THINK_ROOT/state"
LOG="$THINK_ROOT/logs/watcher.log"
YQ=/opt/homebrew/bin/yq

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
mkdir -p "$STATE_DIR" "$NOTIFICATIONS_DIR"

file_hash() { shasum "$1" 2>/dev/null | cut -d' ' -f1; }

# --- ① vault の think 配下 REVIEW.md [x] 変更を検知 → think_refine_request ---
if [[ -d "$VAULT_DIR/.git" ]]; then
  cd "$VAULT_DIR"
  git fetch origin main 2>/dev/null
  git pull --rebase origin main 2>/dev/null || true

  for REVIEW_PATH in reviews/think/*/REVIEW.md; do
    FULL_PATH="$VAULT_DIR/$REVIEW_PATH"
    [[ ! -f "$FULL_PATH" ]] && continue

    IDEA_SLUG="$(echo "$REVIEW_PATH" | cut -d/ -f3)"
    IDEA_DIR="$IDEAS_ROOT/$IDEA_SLUG"
    CONFIG="$IDEA_DIR/.claudeflow-think.yaml"
    [[ ! -f "$CONFIG" ]] && continue

    STATE_FILE="$STATE_DIR/review_hash_${IDEA_SLUG}"
    CURRENT_HASH=$(file_hash "$FULL_PATH")
    LAST_HASH=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    [[ "$CURRENT_HASH" == "$LAST_HASH" ]] && continue

    APPROVED=$(python3 -c "
import re
lines = open('$FULL_PATH').readlines()
ids = [re.search(r'#\d+', l).group() for l in lines if '- [x] #' in l and '反映済み' not in l and re.search(r'#\d+', l)]
print(' '.join(ids))
" 2>/dev/null)

    if [[ -n "$APPROVED" ]]; then
      IDEA_NAME=$($YQ '.name' "$CONFIG")
      IDEA_FILE="$IDEA_DIR/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
      REFINE_PROMPT=$($YQ '.refine_prompt' "$CONFIG")

      cp "$FULL_PATH" "$IDEA_DIR/REVIEW.md"

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
  'think_root': '$THINK_ROOT',
  'vault_review_path': '$FULL_PATH',
  'refine_prompt': '''$REFINE_PROMPT''',
  'approved_ids': '$APPROVED',
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"

      log "[$IDEA_SLUG] REVIEW.md [x] 検知: $APPROVED → think_refine_request"
      echo "$CURRENT_HASH" > "$STATE_FILE"
    else
      echo "$CURRENT_HASH" > "$STATE_FILE"
    fi
  done
fi

# --- ② claudeflow-think モノレポの ideas/*/idea.md 変更を検知 → think_review_request ---
cd "$THINK_ROOT"
git fetch origin main 2>/dev/null || exit 0

for CONFIG_PATH in ideas/*/.claudeflow-think.yaml; do
  [[ ! -f "$CONFIG_PATH" ]] && continue

  IDEA_SLUG="$(echo "$CONFIG_PATH" | cut -d/ -f2)"
  IDEA_DIR="$IDEAS_ROOT/$IDEA_SLUG"
  CONFIG="$IDEA_DIR/.claudeflow-think.yaml"

  IDEA_NAME=$($YQ '.name' "$CONFIG")
  IDEA_FILE_REL="ideas/$IDEA_SLUG/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
  AUTO_REVIEW=$($YQ '.auto_review // true' "$CONFIG")
  [[ "$AUTO_REVIEW" != "true" ]] && continue

  # そのファイルを最後に変更したコミット SHA
  REMOTE_FILE_SHA=$(git log origin/main -1 --format="%H" -- "$IDEA_FILE_REL" 2>/dev/null)
  [[ -z "$REMOTE_FILE_SHA" ]] && continue

  STATE_FILE="$STATE_DIR/idea_sha_${IDEA_SLUG}"
  LAST_FILE_SHA=$(cat "$STATE_FILE" 2>/dev/null || echo "")
  [[ "$REMOTE_FILE_SHA" == "$LAST_FILE_SHA" ]] && continue

  # refine コミットはスキップ（無限ループ防止）
  LAST_MSG=$(git log origin/main -1 --format="%s" -- "$IDEA_FILE_REL" 2>/dev/null)
  if echo "$LAST_MSG" | grep -qE '^(refine:|apply:)'; then
    log "[$IDEA_SLUG] refine による変更のためスキップ"
    echo "$REMOTE_FILE_SHA" > "$STATE_FILE"
    git pull origin main 2>/dev/null
    continue
  fi

  log "[$IDEA_SLUG] $IDEA_FILE_REL 変更検知 (${REMOTE_FILE_SHA:0:8}) → think_review_request"
  echo "$REMOTE_FILE_SHA" > "$STATE_FILE"
  git pull origin main 2>/dev/null

  IDEA_FILE="$IDEA_DIR/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
  CONTEXT=$($YQ '.context // ""' "$CONFIG")
  REVIEW_PROMPT=$($YQ '.review_prompt' "$CONFIG")
  VAULT_REVIEW_DIR="$VAULT_DIR/reviews/think/$IDEA_SLUG"

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
done
