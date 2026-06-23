#!/bin/bash
# idea.md が GitHub 上で更新されていたら review.sh を起動する

OBSIDIAN_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian"
IDEAS_ROOT="$OBSIDIAN_ROOT/ideas"
THINK_ROOT="$OBSIDIAN_ROOT/_claudeflow-think"
CLAUDEFLOW_ROOT="$OBSIDIAN_ROOT/_claudeflow"
LOG="$THINK_ROOT/logs/watcher.log"
YQ=/opt/homebrew/bin/yq

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

for CONFIG in "$IDEAS_ROOT"/*/.claudeflow-think.yaml; do
  [[ ! -f "$CONFIG" ]] && continue

  IDEA_DIR="$(dirname "$CONFIG")"
  IDEA_NAME=$($YQ '.name' "$CONFIG")
  IDEA_FILE=$($YQ '.idea_file // "idea.md"' "$CONFIG")
  AUTO_REVIEW=$($YQ '.auto_review // true' "$CONFIG")

  [[ "$AUTO_REVIEW" != "true" ]] && continue

  cd "$IDEA_DIR" || continue
  git fetch origin main 2>/dev/null || continue
  DIFF=$(git diff HEAD origin/main --name-only 2>/dev/null)

  if echo "$DIFF" | grep -q "^${IDEA_FILE}$"; then
    log "[$IDEA_NAME] $IDEA_FILE 変更検知 → pull → review.sh 起動"
    git pull origin main
    source "$CLAUDEFLOW_ROOT/scripts/notify.sh"
    notify_mac "$CONFIG" "claudeflow-think" "🔍 変更検知: $IDEA_NAME → 査読開始"
    bash "$THINK_ROOT/scripts/review.sh" "$IDEA_DIR" >> "$LOG" 2>&1 &
  fi
done
