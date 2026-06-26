#!/bin/bash
set -euo pipefail

THINK_ROOT="$HOME/claude/claudeflow-think"
IDEAS_ROOT="$THINK_ROOT/ideas"

echo "=== claudeflow-think 新規アイデア作成 ==="
read -p "スラッグ（ディレクトリ名・英数字ハイフン）: " IDEA_SLUG
read -p "表示名: " IDEA_NAME
echo "コンテキスト（idea.md に書かないが Claude に伝えたい背景、空でも可）:"
read -p "> " IDEA_CONTEXT

IDEA_DIR="$IDEAS_ROOT/$IDEA_SLUG"
[[ -d "$IDEA_DIR" ]] && { echo "ERROR: $IDEA_DIR はすでに存在します"; exit 1; }

mkdir -p "$IDEA_DIR/archive"

# .claudeflow-think.yaml 生成
sed "s|{{NAME}}|$IDEA_NAME|g; s|{{CONTEXT}}|$IDEA_CONTEXT|g" \
  "$THINK_ROOT/templates/project_template.yaml" \
  > "$IDEA_DIR/.claudeflow-think.yaml"

# idea.md 生成
TODAY=$(date '+%Y-%m-%d')
sed "s|{{NAME}}|$IDEA_NAME|g" \
  "$THINK_ROOT/templates/idea_template.md" \
  | sed "s|YYYY-MM-DD|$TODAY|g" \
  > "$IDEA_DIR/idea.md"

# モノレポとして commit & push
cd "$THINK_ROOT"
git add "ideas/$IDEA_SLUG/"
git commit -m "idea: add $IDEA_SLUG"
git push

echo ""
echo "✅ アイデア作成完了: $IDEA_DIR"
echo "   idea.md を記述して push → 10分以内に自動査読スタート"
