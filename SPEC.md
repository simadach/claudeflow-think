# claudeflow-think 仕様書

**バージョン**: 2.0.0
**作成日**: 2026-06-23
**更新日**: 2026-06-23
**対象環境**: Mac mini M4 / macOS / Apple Silicon

> **思想原則**: 本仕様書は [claudeflow PHILOSOPHY.md](https://github.com/simadach/claudeflow/blob/main/PHILOSOPHY.md) の実現手段である。
> 「仕様通りに動くこと」と「人間にとって心地よい思考の場であること」は別問題であり、
> 関与するすべての AI エージェントは PHILOSOPHY.md を最上位の判断基準とすること。

---

## 1. 概要

アイデア・意思決定を `idea.md` に書くと、Claude がまだ言語化されていない懸念・盲点・前提を
`REVIEW.md` として生成する。iPhone Obsidian で各項目を判断し、メインセッションが `idea.md` を更新する（深化ループ）。

```
idea.md 記述 → GitHub push
  → idea_watcher_cron.sh が変更検知（10分ごと）
  → notifications/think_review_*.json 書き込み
  → メインセッション（claude-discord）が次ターンで査読実行
  → REVIEW.md 生成 → idea repo git push
  → vault reviews/think/{slug}/ に push
  → iPhone Obsidian Git が自動 pull
  → [x] / [x] ❌ 理由：〇〇 を付けて保存 → Obsidian Git が自動 push
  → idea_watcher_cron.sh が vault REVIEW.md 変化を検知
  → notifications/think_refine_*.json 書き込み
  → メインセッションが次ターンで idea.md を更新
  → idea repo git push → vault 更新
  → ループ（idea が深まるほど REVIEW も深まる）
```

### v2.0.0 変更点（サブプロセス廃止 + iCloud 廃止）

claudeflow 本体の v2.7〜v2.8 設計思想を踏襲。

| 項目 | v1.x（旧） | v2.0（現行） |
|------|-----------|-------------|
| Claude 実行主体 | review.sh / refine.sh が `claude -p` を直接起動 | notifications/ に JSON 書き込み → メインセッションが処理 |
| ファイル監視 | fswatch（watch.sh） | idea_watcher_cron.sh が 10 分ごとにポーリング |
| スクリプト置き場 | `~/Obsidian/_claudeflow-think/`（iCloud） | `~/claude/claudeflow-think/`（非 iCloud） |
| アイデア置き場 | `~/Obsidian/ideas/`（iCloud） | `~/claude/claudeflow-think/ideas/`（非 iCloud） |
| vault 同期 | iCloud コピー | `simadach/claudeflow` vault repo へ git push |

**設計理由（サブプロセス廃止）**: launchd サブシェルからの `claude -p` は interactive approval なし・API 制約でサイレントクラッシュしやすい。常駐メインセッション内で直接実行することで安定化する。

**設計理由（iCloud 廃止）**: `bird`（iCloud sync daemon）が `.git` ディレクトリをロックするため、git 操作がすべて "Resource deadlock avoided" で失敗する。

---

## 2. ディレクトリ構造

```
~/claude/claudeflow/             ← claudeflow 本体（共通インフラ）
├── notifications/               ← ★ 通知 JSON の置き場（メインセッションが監視）
│   ├── think_review_*.json      ←   idea_watcher_cron.sh / review.sh が書き込む
│   └── think_refine_*.json      ←   idea_watcher_cron.sh / refine.sh が書き込む
├── vault/                       ← simadach/claudeflow（Obsidian Git vault）
│   └── reviews/
│       └── think/
│           └── {idea-slug}/
│               ├── idea.md      ← メインセッションがコピー
│               └── REVIEW.md    ← メインセッションがコピー → iPhone に配信
└── logs/

~/claude/claudeflow-think/       ← 本フレームワーク（独立 Git リポジトリ）
├── SPEC.md
├── README.md
├── scripts/
│   ├── idea_watcher_cron.sh     # idea.md 変更 / vault [x] 変更を検知 → JSON 書き込み
│   ├── review.sh                # 手動トリガー用（→ JSON 書き込み）
│   ├── refine.sh                # 手動トリガー用（→ JSON 書き込み）
│   └── new-idea.sh              # 新規アイデア作成
├── templates/
│   ├── idea_template.md
│   ├── REVIEW_TEMPLATE.md
│   └── project_template.yaml
├── ideas/                       ← アイデア・意思決定プロジェクト群
│   └── {idea-slug}/             ← 各アイデア（独立 Git リポジトリ）
│       ├── .claudeflow-think.yaml
│       ├── idea.md              ← 人間が記述するアイデア・意思決定ドキュメント
│       ├── REVIEW.md            ← メインセッションが生成
│       └── archive/             ← idea.md の過去スナップショット
├── state/                       ← SHA・ハッシュ管理（.gitignore 対象）
└── logs/                        ← ログ（.gitignore 対象）
```

---

## 3. .claudeflow-think.yaml スキーマ

```yaml
name: string              # アイデア表示名（例: "副業戦略2026"）
idea_file: "idea.md"      # アイデアファイル（通常は idea.md 固定）

# Claude へのコンテキスト（省略可）
# idea.md に書かないが Claude に知っておいてほしい背景情報
context: |
  家族構成・財務状況・制約条件など

review_prompt: |          # 査読観点（カスタマイズ推奨）
refine_prompt: |          # 精錬指示（通常はデフォルトのまま）

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
- [ ] #001 説明（「〜かもしれません」の仮説提示形式で）

## 🟡 検討すべきトレードオフ・代替案
- [ ] #002 説明

## ❓ 確認すべき前提・仮定
- [ ] #003 説明

## 💭 まだ言語化されていない感覚
- #004 説明（体験・感情・習慣への影響。チェックボックスなし）

## ✅ 十分に整理されている観点
- #005 説明（チェックボックスなし）
```

### 承認操作ルール

| Obsidian での操作 | 記法 | メインセッションの挙動 |
|---|---|---|
| この懸念を反映する | `- [x] #001` | idea.md の該当セクションを更新 |
| 意識的に却下する | `- [x] #002 ❌ 理由：〇〇` | idea.md の「意識的に却下した観点」に記録 |
| 保留 | `- [ ] #003` | 次回 REVIEW でも再掲 |
| 反映済み | `- [x] #001 ✅ 反映済み` | メインセッションが自動更新 |

> **コード版との違い**: ❌ は「スキップ（無視）」ではなく「**意識的に考慮した上で却下**」を意味する。
> 却下理由が idea.md に記録されることで、「考えた証拠」が残る。

---

## 5. 通知 JSON フォーマット

### think_review_*.json

```json
{
  "type": "think_review_request",
  "idea_slug": "副業戦略2026",
  "idea_name": "副業戦略2026",
  "idea_dir": "/home/user/claude/claudeflow-think/ideas/...",
  "idea_file": ".../idea.md",
  "review_file": ".../REVIEW.md",
  "vault_review_dir": ".../vault/reviews/think/...",
  "context": "（.claudeflow-think.yaml の context）",
  "review_prompt": "（査読観点）",
  "timestamp": "2026-06-23 12:00"
}
```

### think_refine_*.json

```json
{
  "type": "think_refine_request",
  "idea_slug": "副業戦略2026",
  "idea_name": "副業戦略2026",
  "idea_dir": "...",
  "idea_file": ".../idea.md",
  "review_file": ".../REVIEW.md",
  "vault_review_path": ".../vault/reviews/think/.../REVIEW.md",
  "refine_prompt": "（精錬指示）",
  "approved_ids": "#001 #002",
  "timestamp": "2026-06-23 12:00"
}
```

---

## 6. スクリプト仕様

### 6-1. idea_watcher_cron.sh（メイン監視スクリプト）

**役割**: 2つの変化を検知して notifications/ に JSON を書き込む。`claude -p` は一切呼ばない。

**① vault ポーリング（REVIEW.md [x] 変更検知）**:
1. `cd VAULT_DIR && git fetch + pull --rebase`
2. `reviews/think/*/REVIEW.md` の内容ハッシュを前回と比較
3. 変化あり + `[x]` 行あり → idea repo の REVIEW.md に同期 → `think_refine_*.json` を書き込み

**② idea リポジトリポーリング（idea.md 変更検知）**:
1. 各 `ideas/*/.claudeflow-think.yaml` を走査
2. `idea.md` の最終コミット SHA を前回と比較
3. 変化あり + refine/apply コミットでない → `git pull` → `think_review_*.json` を書き込み

### 6-2. review.sh（手動トリガー）

`think_review_*.json` を書き込むだけ。
`claude -p` は呼ばない。メインセッションが処理する。

### 6-3. refine.sh（手動トリガー）

`think_refine_*.json` を書き込むだけ。
`claude -p` は呼ばない。メインセッションが処理する。

---

## 7. メインセッションでの処理内容（claude-discord への追加実装が必要）

メインセッションは `notifications/think_*.json` を検出したとき、以下を実行する。

### think_review_request の処理

```
1. idea_file を読み込む
2. context + review_prompt に基づき REVIEW.md を生成
3. idea repo: git add REVIEW.md && git commit -m "review: {timestamp}" && git push
4. vault: vault_review_dir に REVIEW.md + idea.md をコピー → git push
5. Discord DM: 「💡 {idea_name} の査読が完了しました」
6. 通知ファイルを削除
```

### think_refine_request の処理

```
1. REVIEW.md を読み込み、approved_ids の項目を確認
2. idea_file のアーカイブを archive/ に保存
3. [x] のみ → idea.md の適切なセクションを更新
4. [x] ❌ → idea.md の「意識的に却下した観点」に記録
5. REVIEW.md の該当行を「- [x] #XXX ✅ 反映済み」に更新
6. idea repo: git add -A && git commit -m "refine: {approved_ids}" && git push
7. vault: REVIEW.md を archive/ に退避 + idea.md を最新化 → git push
8. Discord DM: 「✨ {idea_name} が更新されました ({approved_ids})」
9. 通知ファイルを削除
```

---

## 8. launchd 設定

`~/Library/LaunchAgents/com.claudeflow-think.watcher.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claudeflow-think.watcher</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/shogo/claude/claudeflow-think/scripts/idea_watcher_cron.sh</string>
  </array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key>
  <string>/Users/shogo/claude/claudeflow-think/logs/watcher.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/shogo/claude/claudeflow-think/logs/watcher.error.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key><string>/Users/shogo</string>
  </dict>
</dict>
</plist>
```

---

## 9. セットアップ手順

```bash
# Step 1: フレームワーク clone
git clone https://github.com/simadach/claudeflow-think.git \
  ~/claude/claudeflow-think

# Step 2: ディレクトリ作成
mkdir -p ~/claude/claudeflow-think/{ideas,logs,state}

# Step 3: スクリプト権限設定
chmod +x ~/claude/claudeflow-think/scripts/*.sh

# Step 4: vault に think/ ディレクトリを作成
mkdir -p ~/claude/claudeflow/vault/reviews/think
cd ~/claude/claudeflow/vault
git add reviews/think/
git commit -m "feat: add think/ directory for claudeflow-think"
git push

# Step 5: launchd 登録（§8 の plist を配置）
launchctl load ~/Library/LaunchAgents/com.claudeflow-think.watcher.plist

# Step 6: メインセッションに think_* 通知処理を追加
# → claude-discord の CLAUDE.md / 通知処理ロジックに追記（§7 参照）

# Step 7: 初アイデア作成
bash ~/claude/claudeflow-think/scripts/new-idea.sh
```

---

## 10. 運用チェックリスト

```
新規アイデア作成時:
  □ new-idea.sh で作成
  □ GitHub でリポジトリ作成 → git remote add → git push
  □ idea.md に核心・背景・現在の考えを記述して push
  □ 10分以内に idea_watcher_cron.sh が検知 → メインセッションが査読

日常ループ:
  □ idea.md を更新して push
  □ iPhone Obsidian で vault/reviews/think/{slug}/REVIEW.md を確認
  □ [x] = 反映する、[x] ❌ 理由：〇〇 = 意識的却下、[ ] = 保留
  □ 保存 → Obsidian Git が push → 10分以内にメインセッションが精錬

指針:
  □ 「全部 [x]」にしなくてよい。保留は次回も残る
  □ ❌ を積極的に使う（考えた証拠が残る）
  □ idea.md のステータスを「探索中」→「深化中」→「決定済み」と進める

トラブル時:
  □ logs/watcher.log を確認
  □ bash review.sh {IDEA_DIR} で手動トリガー（JSON を書き込む）
  □ メインセッション側の通知処理ログを確認
```
