#!/bin/bash
set -euo pipefail

OBSIDIAN_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian"
IDEAS_ROOT="$OBSIDIAN_ROOT/ideas"
THINK_ROOT="$OBSIDIAN_ROOT/_claudeflow-think"

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
sed "s|{{NAME}}|$IDEA_NAME|g; s|YYYY-MM-DD|$TODAY|g" \
  "$THINK_ROOT/templates/idea_template.md" \
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
echo "  4. idea.md を記述して push → 10分以内に自動査読スタート"
echo ""
echo "ヒント:"
echo "  - idea.md には「まだ言語化できていないこと」も書いてみる"
echo "  - コンテキスト（背景）は .claudeflow-think.yaml の context に書ける"
