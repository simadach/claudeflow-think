#!/bin/bash
set -euo pipefail

IDEA_DIR="${1:?引数エラー: IDEA_DIR を指定してください}"

OBSIDIAN_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian"
THINK_ROOT="$OBSIDIAN_ROOT/_claudeflow-think"
CLAUDEFLOW_ROOT="$OBSIDIAN_ROOT/_claudeflow"
LOG="$THINK_ROOT/logs/watcher.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

YQ=/opt/homebrew/bin/yq
CONFIG="$IDEA_DIR/.claudeflow-think.yaml"
[[ ! -f "$CONFIG" ]] && { log "ERROR: .claudeflow-think.yaml が見つかりません: $CONFIG"; exit 1; }

IDEA_NAME=$($YQ '.name' "$CONFIG")
IDEA_FILE="$IDEA_DIR/$($YQ '.idea_file // "idea.md"' "$CONFIG")"
CONTEXT=$($YQ '.context // ""' "$CONFIG")
REVIEW_PROMPT=$($YQ '.review_prompt' "$CONFIG")
NOTIFY=$($YQ '.notify // true' "$CONFIG")
REVIEW_TEMPLATE="$THINK_ROOT/templates/REVIEW_TEMPLATE.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

log "[$IDEA_NAME] 査読開始"

/opt/homebrew/bin/claude --dangerously-skip-permissions -p "
あなたはアイデア・意思決定の批判的思考パートナーです。
完成を断定せず、人間がまだ言語化できていない価値・懸念・盲点を一緒に発見してください。

## 上位原則（最重要）
- 技術的な正しさより、人間の体験・感情・習慣への影響を重視する
- 「なんとなくしっくりこない」という感覚は価値モデルの不足を示すシグナルとして扱う
- 完成を宣言せず、「〜かもしれない」「〜という観点はどうか」という仮説提示の姿勢を保つ
- 人間が書いていないことの中に、最も重要な観点が隠れている可能性がある

## コンテキスト（idea.md に書かれていない背景情報）
$CONTEXT

## 査読対象
$IDEA_FILE

## 査読観点
$REVIEW_PROMPT

## 出力先
$IDEA_DIR/REVIEW.md

## 出力フォーマット
$REVIEW_TEMPLATE の形式に従い、以下のヘッダーで出力してください：
  1行目: # REVIEW - $TIMESTAMP
  2行目: <!-- IDEA: $IDEA_NAME -->
  3行目: <!-- STATUS: pending -->
各項目には #001 から連番の ID を付与すること。

## 完了後の処理
cd '$IDEA_DIR' && git add REVIEW.md && git commit -m 'review: $TIMESTAMP' && git push
"

log "[$IDEA_NAME] 査読完了 → git push"

source "$CLAUDEFLOW_ROOT/scripts/notify.sh"
notify_mac "$CONFIG" "claudeflow-think" "💡 査読完了: $IDEA_NAME → Obsidian で REVIEW を確認してください"
