#!/bin/bash
set -euo pipefail

IDEA_DIR="${1:?引数エラー: IDEA_DIR を指定してください}"
APPROVED_IDS="${2:?引数エラー: APPROVED_IDS を指定してください}"

OBSIDIAN_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian"
THINK_ROOT="$OBSIDIAN_ROOT/_claudeflow-think"
CLAUDEFLOW_ROOT="$OBSIDIAN_ROOT/_claudeflow"
LOG="$THINK_ROOT/logs/watcher.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

YQ=/opt/homebrew/bin/yq
CONFIG="$IDEA_DIR/.claudeflow-think.yaml"
IDEA_NAME=$($YQ '.name' "$CONFIG")
IDEA_FILE="$IDEA_DIR/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
REFINE_PROMPT=$($YQ '.refine_prompt' "$CONFIG")
NOTIFY=$($YQ '.notify // true' "$CONFIG")

log "[$IDEA_NAME] 精錬開始: $APPROVED_IDS"

# 精錬前に idea.md をアーカイブ
ARCHIVE_DIR="$IDEA_DIR/archive"
mkdir -p "$ARCHIVE_DIR"
cp "$IDEA_FILE" "$ARCHIVE_DIR/idea_$(date '+%Y-%m-%d_%H-%M').md"

/opt/homebrew/bin/claude --dangerously-skip-permissions -p "
あなたはアイデア精錬の担当者です。以下のタスクを実行してください。

## 対象ファイル
- idea.md: $IDEA_FILE
- REVIEW.md: $IDEA_DIR/REVIEW.md
- 承認済みID: $APPROVED_IDS

## 実行内容
$REFINE_PROMPT

## 精錬ルール（詳細）
承認済みID（$APPROVED_IDS）のそれぞれについて：

【[x] のみの項目（懸念を反映する）】
- idea.md の最も適切なセクションを更新・追記する
- 元の文章の意図を保ちつつ、懸念・観点を自然に組み込む
- 必要に応じて「## 既知の懸念・トレードオフ」「## 前提条件」「## 次のアクション」を更新

【[x] ❌ の項目（意識的に却下する）】
- idea.md の「## 意識的に考慮したが却下した観点」セクションに追記する
- REVIEW.md に記述された却下理由も一緒に記録する
- フォーマット: 「- #XXX {懸念の概要}: {却下理由}（{YYYY-MM-DD}）」

【共通ルール】
- 反映完了後、REVIEW.md の該当行を「- [x] #XXX ✅ 反映済み」に更新する
- すべて完了したら STATUS を「completed」に、一部なら「partial」に更新する
- idea.md の「**最終更新**」日付を今日（$(date '+%Y-%m-%d')）に更新する
- idea.md のステータスが「探索中」のまま懸念が深まっていたら「深化中」に更新することを検討する

## 完了後の処理
cd '$IDEA_DIR' && git add -A && git commit -m 'refine: $APPROVED_IDS' && git push
"

log "[$IDEA_NAME] 精錬完了: $APPROVED_IDS → git push"

source "$CLAUDEFLOW_ROOT/scripts/notify.sh"
notify_mac "$CONFIG" "claudeflow-think ($IDEA_NAME)" "✨ 精錬完了: $APPROVED_IDS"
