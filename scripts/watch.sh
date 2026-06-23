#!/bin/bash
set -euo pipefail

OBSIDIAN_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian"
IDEAS_ROOT="$OBSIDIAN_ROOT/ideas"
THINK_ROOT="$OBSIDIAN_ROOT/_claudeflow-think"
LOG="$THINK_ROOT/logs/watcher.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
log "claudeflow-think watcher 起動"

/opt/homebrew/bin/fswatch \
  --recursive \
  --exclude='\.git' \
  --include='REVIEW\.md$' \
  --event=Updated \
  "$IDEAS_ROOT" | while read -r changed_file; do

  [[ "$(basename "$changed_file")" != "REVIEW.md" ]] && continue

  IDEA_DIR="$(dirname "$changed_file")"
  IDEA_SLUG="$(basename "$IDEA_DIR")"
  CONFIG="$IDEA_DIR/.claudeflow-think.yaml"
  [[ ! -f "$CONFIG" ]] && continue

  APPROVED=$(grep -E '^\- \[x\] #[0-9]+' "$changed_file" \
             | grep -v '反映済み' \
             | grep -oE '#[0-9]+' | tr '\n' ' ' | xargs)

  if [[ -z "$APPROVED" ]]; then
    log "[$IDEA_SLUG] 承認項目なし - スキップ"
    continue
  fi

  log "[$IDEA_SLUG] 承認項目検知: $APPROVED → refine.sh 起動"
  bash "$THINK_ROOT/scripts/refine.sh" "$IDEA_DIR" "$APPROVED" >> "$LOG" 2>&1 &
done
