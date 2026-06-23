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

cd "$IDEA_DIR"
git init
git branch -M main
cat > .gitignore << 'EOF'
.DS_Store
archive/
EOF

git add .
git commit -m "initial: $IDEA_NAME"

echo ""
echo "✅ アイデア作成完了: $IDEA_DIR"
echo ""
echo "次のステップ:"
echo "  1. GitHub でリポジトリを作成"
echo "  2. git remote add origin git@github.com:simadach/$IDEA_SLUG.git"
echo "  3. git push -u origin main"
echo "  4. idea.md を記述して push"
echo "     → idea_watcher_cron.sh が検知 → think_review_request 書き込み"
echo "     → メインセッションが査読を実行"
