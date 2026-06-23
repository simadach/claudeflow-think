# claudeflow-think 仕様書

**バージョン**: 1.0.0
**作成日**: 2026-06-23
**対象環境**: Mac mini M4 / macOS / Apple Silicon

---

## 0. 上位原則

本システムは [claudeflow の PHILOSOPHY.md](https://github.com/simadach/claudeflow/blob/main/PHILOSOPHY.md) に従う。

- 人間の体験の質を最上位の価値とする
- 「なんとなく気になる」「まだ言語化できていない」感覚を無視しない
- Claude は完成を宣言する存在ではなく、人間と共に理想像を探索するパートナーである

---

## 1. 概要

アイデア・意思決定を `idea.md` に書くと、Claude が多角的な懸念・盲点・未確認の前提を
`REVIEW.md` として生成する。iPhone Obsidian で各項目を判断し、`refine.sh` が
`idea.md` を更新する（深化ループ）。

```
idea.md 記述
  → idea_watcher_cron.sh が変更検知（10分ごと）
  → review.sh → REVIEW.md 生成 → git push
  → iCloud → iPhone Obsidian で確認・判断
  → watch.sh が [x] を検知 → refine.sh 起動
  → idea.md を更新 → git push
  → ループ（idea が深まるほど REVIEW も深まる）
```

---

## 2. ディレクトリ構造

```
~/icloud/Obsidian/
├── _claudeflow/           ← claudeflow 本体（共通ユーティリティを共有）
│   └── scripts/notify.sh  ← 通知ヘルパーを流用
│
├── _claudeflow-think/     ← 本フレームワーク（独立 Git リポジトリ）
│   ├── SPEC.md
│   ├── README.md
│   ├── scripts/
│   │   ├── watch.sh              # REVIEW.md 変更監視
│   │   ├── review.sh             # REVIEW.md 生成（Claude Code）
│   │   ├── refine.sh             # idea.md 更新（Claude Code）
│   │   ├── new-idea.sh           # 新規アイデア作成
│   │   └── idea_watcher_cron.sh  # idea.md 変更検知（cron）
│   ├── templates/
│   │   ├── idea_template.md
│   │   ├── REVIEW_TEMPLATE.md
│   │   └── project_template.yaml
│   └── logs/              ← .gitignore 対象
│
└── ideas/                 ← アイデア・意思決定プロジェクト群
    └── {idea-slug}/       ← 各アイデア（独立 Git リポジトリ）
        ├── .claudeflow-think.yaml
        ├── idea.md        ← 人間が記述するアイデア・意思決定ドキュメント
        ├── REVIEW.md      ← Claude が生成する懸念・盲点リスト
        └── archive/       ← idea.md の過去スナップショット
```

> **パス定義**
> `THINK_ROOT` = `$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/_claudeflow-think`
> `IDEAS_ROOT` = `$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/ideas`

---

## 3. .claudeflow-think.yaml スキーマ

```yaml
name: string              # アイデア表示名（例: "副業戦略2026"）
idea_file: "idea.md"      # アイデアファイル（通常は idea.md 固定）

# Claude へのコンテキスト（省略可）
context: |
  このアイデアを評価する際の背景情報。
  例：家族構成・財務状況・制約条件など、
  idea.md に書かないが Claude に知っておいてほしいこと。

# 査読プロンプト（カスタマイズ推奨）
review_prompt: |
  以下の観点で idea.md を分析し、人間がまだ気づいていない視点を提示してください。
  デフォルトの観点は SPEC.md §4 を参照。

# 精錬プロンプト（通常はデフォルトのまま）
refine_prompt: |
  REVIEW.md の承認済み項目を idea.md に反映してください。
  詳細は SPEC.md §5 の refine.sh 仕様を参照。

notify: true
auto_review: true
```

---

## 4. REVIEW.md フォーマット仕様

```markdown
# REVIEW - YYYY-MM-DD HH:MM
<!-- IDEA: {idea-name} -->
<!-- STATUS: pending | partial | completed -->

## 🔴 見落としている重大なリスク
<!-- このまま進むと取り返しのつかないことになりうる観点 -->

## 🟡 検討すべきトレードオフ・代替案
<!-- 別の選択肢や、得るものと失うものの整理 -->

## ❓ 確認すべき前提・仮定
<!-- 「これが成り立つ」と暗黙に仮定しているが、本当にそうか？ -->

## 💭 まだ言語化されていない感覚
<!-- 体験・感情・習慣・人間関係への影響。正しいかより、心地よいか -->

## ✅ 十分に整理されている観点
<!-- よく考えられている部分（チェックボックスなし） -->
```

### 承認操作ルール

| Obsidian での操作 | 記法 | refine.sh の挙動 |
|---|---|---|
| この懸念を反映する | `- [x] #001` | idea.md の該当セクションを更新 |
| 意識的に却下する | `- [x] #002 ❌ 理由：〇〇のため` | idea.md の「意識的に却下した観点」に記録 |
| 保留 | `- [ ] #003` | 次回 REVIEW でも再掲 |
| 反映済み | `- [x] #001 ✅ 反映済み` | refine.sh が自動更新 |

> ❌ の使い方がコード版 claudeflow と異なる点に注意。
> ここでの ❌ は「無視」ではなく「**意識的に考慮した上で却下**」を意味し、
> その理由が idea.md に記録される。

---

## 5. スクリプト仕様

### 5-1. watch.sh

`ideas/` 以下の全 `REVIEW.md` を fswatch で監視し、`[x]` が付いたら `refine.sh` を呼ぶ。

```bash
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
```

### 5-2. review.sh

`idea.md` を読み込み `REVIEW.md` を生成する。

```bash
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
[[ ! -f "$CONFIG" ]] && { log "ERROR: .claudeflow-think.yaml が見つかりません"; exit 1; }

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

## 上位原則
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

## 査読スタイルの指針
- 🔴 は「このまま進むと後悔するかもしれない」という重大な見落とし
- 🟡 は「別の選択肢や、得るものと失うもの」のトレードオフ
- ❓ は「〜と仮定しているが、本当にそうか？」という前提への問い
- 💭 は体験・感情・習慣・人間関係への影響（正しいかより、心地よいか）
- 指摘は断定ではなく「〜という懸念があるかもしれません」の形式で
- ✅ は本当によく考えられている部分のみ（無理に埋めなくてよい）

## 完了後の処理
cd '$IDEA_DIR' && git add REVIEW.md && git commit -m 'review: $TIMESTAMP' && git push
"

log "[$IDEA_NAME] 査読完了 → git push"

source "$CLAUDEFLOW_ROOT/scripts/notify.sh"
notify_mac "$CONFIG" "claudeflow-think" "💡 査読完了: $IDEA_NAME → Obsidian で REVIEW を確認してください"
```

### 5-3. refine.sh

承認された懸念を `idea.md` に反映する。

```bash
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

## 精錬ルール
承認済みID（$APPROVED_IDS）のそれぞれについて：

【[x] のみの項目（懸念を反映する）】
- idea.md の最も適切なセクションを更新・追記する
- 元の文章の意図を保ちつつ、懸念・観点を自然に組み込む
- 「## 既知の懸念・トレードオフ」「## 前提条件」「## 次のアクション」等を適宜更新

【[x] ❌ の項目（意識的に却下する）】
- idea.md の「## 意識的に考慮したが却下した観点」セクションに追記する
- REVIEW.md に記載された却下理由も一緒に記録する
- フォーマット: 「- #XXX {REVIEW の概要}: {却下理由}」

【共通】
- 反映完了後、REVIEW.md の該当行を「- [x] #XXX ✅ 反映済み」に更新する
- STATUS コメントを「completed」または「partial」に更新する
- idea.md の「**最終更新**」日付を今日に更新する

## 完了後の処理
cd '$IDEA_DIR' && git add -A && git commit -m 'refine: $APPROVED_IDS' && git push
"

log "[$IDEA_NAME] 精錬完了: $APPROVED_IDS → git push"

source "$CLAUDEFLOW_ROOT/scripts/notify.sh"
notify_mac "$CONFIG" "claudeflow-think ($IDEA_NAME)" "✨ 精錬完了: $APPROVED_IDS"
```

### 5-4. new-idea.sh

新規アイデアプロジェクトを作成する。

```bash
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
sed "s|{{NAME}}|$IDEA_NAME|g" \
  "$THINK_ROOT/templates/idea_template.md" \
  > "$IDEA_DIR/idea.md"

cd "$IDEA_DIR"
git init
git branch -M main
echo ".DS_Store" > .gitignore
echo "archive/" >> .gitignore

git add .
git commit -m "initial: $IDEA_NAME"

echo ""
echo "✅ アイデア作成完了: $IDEA_DIR"
echo "次のステップ:"
echo "  1. GitHub でリポジトリを作成"
echo "  2. git remote add origin git@github.com:simadach/$IDEA_SLUG.git"
echo "  3. git push -u origin main"
echo "  4. idea.md を記述して push → 自動査読スタート"
```

### 5-5. idea_watcher_cron.sh

`idea.md` が GitHub 上で更新されていたら `review.sh` を起動する。

```bash
#!/bin/bash

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
```

---

## 6. launchd 設定

`~/Library/LaunchAgents/com.claudeflow-think.watcher.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.claudeflow-think.watcher</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/YOUR_USER/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/_claudeflow-think/scripts/watch.sh</string>
  </array>

  <key>KeepAlive</key>
  <true/>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/YOUR_USER/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/_claudeflow-think/logs/watcher.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/YOUR_USER/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/_claudeflow-think/logs/watcher.error.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key>
    <string>/Users/YOUR_USER</string>
  </dict>
</dict>
</plist>
```

---

## 7. cron 設定

```bash
# 10分ごとに idea.md の変更を検知して自動査読
*/10 * * * * /Users/YOUR_USER/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian/_claudeflow-think/scripts/idea_watcher_cron.sh
```

---

## 8. テンプレートファイル

§9 参照。

---

## 9. セットアップ手順

```
### Step 1: ディレクトリ作成
OBSIDIAN_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian"
mkdir -p "$OBSIDIAN_ROOT/_claudeflow-think/scripts"
mkdir -p "$OBSIDIAN_ROOT/_claudeflow-think/templates"
mkdir -p "$OBSIDIAN_ROOT/_claudeflow-think/logs"
mkdir -p "$OBSIDIAN_ROOT/ideas"

### Step 2: リポジトリ clone
cd "$OBSIDIAN_ROOT"
git clone https://github.com/simadach/claudeflow-think.git _claudeflow-think

### Step 3: スクリプト権限設定
chmod +x "$OBSIDIAN_ROOT/_claudeflow-think/scripts/"*.sh

### Step 4: launchd 登録
# §6 の plist を ~/Library/LaunchAgents/ に配置（YOUR_USER を置換）
launchctl load ~/Library/LaunchAgents/com.claudeflow-think.watcher.plist

### Step 5: cron 登録
crontab -e
# §7 の cron エントリを追加（YOUR_USER を置換）

### Step 6: 動作確認
tail -f "$OBSIDIAN_ROOT/_claudeflow-think/logs/watcher.log"
```

---

## 10. 運用チェックリスト

```
新規アイデア作成時:
  □ new-idea.sh で作成
  □ GitHub リポジトリ作成・push
  □ idea.md に核心・背景・現在の考えを記述して push
  □ 10分以内に自動査読が走る

日常ループ:
  □ idea.md を更新して push
  □ iPhone Obsidian で REVIEW.md を確認
  □ [x] = 反映する、[x] ❌ 理由：〇〇 = 意識的却下
  □ 保存 → 自動精錬 → idea.md が深まる

指針:
  □ 「全部 [x]」にしなくてよい。保留は次回も残る
  □ ❌ は積極的に使う（考えた証拠が残る）
  □ idea.md のステータスを「探索中」→「深化中」→「決定済み」と進める
```
