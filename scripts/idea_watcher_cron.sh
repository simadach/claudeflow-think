#!/bin/bash
# ideas/*/idea.md 変更 → think_review_request
# ideas/*/REVIEW.md [x] 変更 → think_refine_request
# ideas/*/REVIEW.md '> 返答:' 追加 → think_rereview_request

THINK_ROOT="$HOME/claude/claudeflow-think"
CLAUDEFLOW_ROOT="$HOME/claude/claudeflow"
NOTIFICATIONS_DIR="$CLAUDEFLOW_ROOT/notifications"
IDEAS_ROOT="$THINK_ROOT/ideas"
STATE_DIR="$THINK_ROOT/state"
LOG="$THINK_ROOT/logs/watcher.log"
YQ=/opt/homebrew/bin/yq

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
mkdir -p "$STATE_DIR" "$NOTIFICATIONS_DIR"

file_hash() { shasum "$1" 2>/dev/null | cut -d' ' -f1; }

DISCORD_DM_CHANNEL="1500493137104343081"
DISCORD_BOT_TOKEN=$(grep "^DISCORD_BOT_TOKEN=" "$HOME/.claude/channels/discord/.env" 2>/dev/null | cut -d= -f2-)

discord_dm() {
  local msg="$1"
  [[ -z "$DISCORD_BOT_TOKEN" ]] && return
  curl -s -X POST "https://discord.com/api/v10/channels/$DISCORD_DM_CHANNEL/messages" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$msg")}" \
    > /dev/null 2>&1 || true
}

tmux_wake() {
  local msg="${1:-キューを確認してください}"
  tmux has-session -t claude-discord 2>/dev/null || return
  tmux send-keys -t claude-discord "$msg" Enter
}

# --- claudeflow-think モノレポを pull して idea.md・REVIEW.md 変更を検知 ---
cd "$THINK_ROOT"
git fetch origin main 2>/dev/null || exit 0
git pull --rebase origin main 2>/dev/null || true

for CONFIG_PATH in ideas/*/.claudeflow-think.yaml; do
  [[ ! -f "$CONFIG_PATH" ]] && continue

  IDEA_SLUG="$(echo "$CONFIG_PATH" | cut -d/ -f2)"
  IDEA_DIR="$IDEAS_ROOT/$IDEA_SLUG"
  CONFIG="$IDEA_DIR/.claudeflow-think.yaml"

  IDEA_NAME=$($YQ '.name' "$CONFIG")
  IDEA_FILE_NAME="$($YQ '.idea_file // "idea.md"' "$CONFIG")"
  IDEA_FILE="$IDEA_DIR/$IDEA_FILE_NAME"
  IDEA_FILE_REL="ideas/$IDEA_SLUG/$IDEA_FILE_NAME"
  REVIEW_FILE="$IDEA_DIR/REVIEW.md"

  # --- ①-a REVIEW.md 返答（> 返答:）検知 → think_rereview_request ---
  if [[ -f "$REVIEW_FILE" ]]; then
    REPLY_COUNT=$(grep -c '> 返答:' "$REVIEW_FILE" 2>/dev/null || echo "0")
    if [[ "$REPLY_COUNT" -gt 0 ]]; then
      REPLY_STATE_FILE="$STATE_DIR/reply_hash_${IDEA_SLUG}"
      REPLY_HASH=$(grep '> 返答:' "$REVIEW_FILE" | shasum | cut -d' ' -f1)
      LAST_REPLY_HASH=$(cat "$REPLY_STATE_FILE" 2>/dev/null || echo "")

      if [[ "$REPLY_HASH" != "$LAST_REPLY_HASH" ]]; then
        REPLY_TMP=$(mktemp)
        python3 "$THINK_ROOT/scripts/detect_replies.py" "$REVIEW_FILE" > "$REPLY_TMP" 2>/dev/null

        if [[ -s "$REPLY_TMP" ]]; then
          RESPONDED_IDS=$(python3 -c "import json; d=json.load(open('$REPLY_TMP')); print(' '.join(d.keys()))" 2>/dev/null)
          NOTIF="$NOTIFICATIONS_DIR/think_rereview_$(date '+%Y%m%d_%H%M%S').json"
          python3 -c "
import json
responses = json.load(open('$REPLY_TMP'))
payload = {
  'type': 'think_rereview_request',
  'idea_slug': '$IDEA_SLUG',
  'idea_name': '$IDEA_NAME',
  'idea_dir': '$IDEA_DIR',
  'idea_file': '$IDEA_FILE',
  'review_file': '$REVIEW_FILE',
  'think_root': '$THINK_ROOT',
  'responded_ids': '$RESPONDED_IDS',
  'responses': responses,
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"
          log "[$IDEA_SLUG] REVIEW.md 返答検知: $RESPONDED_IDS → think_rereview_request"
          echo "$REPLY_HASH" > "$REPLY_STATE_FILE"
          discord_dm "🔔 claudeflow-think: **$IDEA_NAME** に返答あり（$RESPONDED_IDS）"
          tmux_wake "🔔 claudeflow-think: $IDEA_NAME に返答あり（$RESPONDED_IDS）。キューを確認してください"
        fi
        rm -f "$REPLY_TMP"
      fi
    fi

    # --- ①-b 追加の疑問（❓）検知 → think_newquestion_request ---
    Q_STATE_FILE="$STATE_DIR/question_hash_${IDEA_SLUG}"
    Q_HASH=$(grep -A 999 '## ❓ 追加の疑問' "$REVIEW_FILE" 2>/dev/null | shasum | cut -d' ' -f1)
    LAST_Q_HASH=$(cat "$Q_STATE_FILE" 2>/dev/null || echo "")
    if [[ "$Q_HASH" != "$LAST_Q_HASH" ]]; then
      Q_TMP=$(mktemp)
      python3 "$THINK_ROOT/scripts/detect_new_questions.py" "$REVIEW_FILE" > "$Q_TMP" 2>/dev/null
      if [[ -s "$Q_TMP" ]]; then
        NOTIF="$NOTIFICATIONS_DIR/think_newquestion_$(date '+%Y%m%d_%H%M%S').json"
        python3 -c "
import json
questions = json.load(open('$Q_TMP'))
payload = {
  'type': 'think_newquestion_request',
  'idea_slug': '$IDEA_SLUG',
  'idea_name': '$IDEA_NAME',
  'idea_dir': '$IDEA_DIR',
  'idea_file': '$IDEA_FILE',
  'review_file': '$REVIEW_FILE',
  'think_root': '$THINK_ROOT',
  'questions': questions,
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"
        log "[$IDEA_SLUG] REVIEW.md 追加の疑問検知 → think_newquestion_request"
        discord_dm "🔔 claudeflow-think: **$IDEA_NAME** に追加の疑問あり"
        tmux_wake "🔔 claudeflow-think: $IDEA_NAME に追加の疑問あり。キューを確認してください"
      fi
      echo "$Q_HASH" > "$Q_STATE_FILE"
      rm -f "$Q_TMP"
    fi

    # --- ①-c [x] 検知 → think_refine_request ---
    REFINE_HASH_FILE="$STATE_DIR/refine_hash_${IDEA_SLUG}"
    REFINE_HASH=$(grep '^\- \[x\] #' "$REVIEW_FILE" 2>/dev/null | grep -v '反映済み\|対象外' | shasum | cut -d' ' -f1)
    LAST_REFINE_HASH=$(cat "$REFINE_HASH_FILE" 2>/dev/null || echo "")

    REFINE_PROMPT=$($YQ '.refine_prompt' "$CONFIG")
    APPROVED=$(python3 -c "
import re
lines = open('$REVIEW_FILE').readlines()
ids = [re.search(r'#\d+', l).group() for l in lines
       if '- [x] #' in l and '反映済み' not in l and '対象外' not in l and re.search(r'#\d+', l)]
print(' '.join(ids))
" 2>/dev/null)

    if [[ -n "$APPROVED" && "$REFINE_HASH" != "$LAST_REFINE_HASH" ]]; then
      NOTIF="$NOTIFICATIONS_DIR/think_refine_$(date '+%Y%m%d_%H%M%S').json"
      python3 -c "
import json
payload = {
  'type': 'think_refine_request',
  'idea_slug': '$IDEA_SLUG',
  'idea_name': '$IDEA_NAME',
  'idea_dir': '$IDEA_DIR',
  'idea_file': '$IDEA_FILE',
  'review_file': '$REVIEW_FILE',
  'think_root': '$THINK_ROOT',
  'refine_prompt': '''$REFINE_PROMPT''',
  'approved_ids': '$APPROVED',
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"
      log "[$IDEA_SLUG] REVIEW.md [x] 検知: $APPROVED → think_refine_request"
      echo "$REFINE_HASH" > "$REFINE_HASH_FILE"
      discord_dm "🔔 claudeflow-think: **$IDEA_NAME** の承認あり（$APPROVED）"
      tmux_wake "🔔 claudeflow-think: $IDEA_NAME の承認あり（$APPROVED）。キューを確認してください"
    elif [[ -z "$APPROVED" ]]; then
      echo "" > "$REFINE_HASH_FILE"
    fi
  fi

  # --- ② idea.md 変更検知 → think_review_request ---
  AUTO_REVIEW=$($YQ '.auto_review // true' "$CONFIG")
  [[ "$AUTO_REVIEW" != "true" ]] && continue

  if [[ -d "$IDEA_DIR/.git" ]]; then
    cd "$IDEA_DIR"
    git fetch origin main 2>/dev/null || true
    REMOTE_FILE_SHA=$(git log origin/main -1 --format="%H" -- "$IDEA_FILE_NAME" 2>/dev/null)
    LAST_MSG=$(git log origin/main -1 --format="%s" -- "$IDEA_FILE_NAME" 2>/dev/null)
    cd "$THINK_ROOT"
  else
    REMOTE_FILE_SHA=$(git log origin/main -1 --format="%H" -- "$IDEA_FILE_REL" 2>/dev/null)
    LAST_MSG=$(git log origin/main -1 --format="%s" -- "$IDEA_FILE_REL" 2>/dev/null)
  fi
  [[ -z "$REMOTE_FILE_SHA" ]] && continue

  STATE_FILE="$STATE_DIR/idea_sha_${IDEA_SLUG}"
  LAST_FILE_SHA=$(cat "$STATE_FILE" 2>/dev/null || echo "")
  [[ "$REMOTE_FILE_SHA" == "$LAST_FILE_SHA" ]] && continue

  if echo "$LAST_MSG" | grep -qE '^(refine: #|apply:|rereview:|fix:|chore:|review:)'; then
    log "[$IDEA_SLUG] Claude自動コミット（$LAST_MSG）のためスキップ"
    echo "$REMOTE_FILE_SHA" > "$STATE_FILE"
    if [[ -d "$IDEA_DIR/.git" ]]; then
      cd "$IDEA_DIR" && git pull origin main 2>/dev/null; cd "$THINK_ROOT"
    else
      git pull origin main 2>/dev/null
    fi
    continue
  fi

  log "[$IDEA_SLUG] $IDEA_FILE_REL 変更検知 (${REMOTE_FILE_SHA:0:8}) → think_review_request"
  echo "$REMOTE_FILE_SHA" > "$STATE_FILE"
  if [[ -d "$IDEA_DIR/.git" ]]; then
    cd "$IDEA_DIR" && git pull origin main 2>/dev/null; cd "$THINK_ROOT"
  else
    git pull origin main 2>/dev/null
  fi

  CONTEXT=$($YQ '.context // ""' "$CONFIG")
  REVIEW_PROMPT=$($YQ '.review_prompt' "$CONFIG")

  NOTIF="$NOTIFICATIONS_DIR/think_review_$(date '+%Y%m%d_%H%M%S').json"
  discord_dm "🔔 claudeflow-think: **$IDEA_NAME** の査読リクエスト"
  tmux_wake "🔔 claudeflow-think: $IDEA_NAME の査読リクエスト。キューを確認してください"
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
  'context': '''$CONTEXT''',
  'review_prompt': '''$REVIEW_PROMPT''',
  'timestamp': '$(date \"+%Y-%m-%d %H:%M\")'
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
" > "$NOTIF"
done
