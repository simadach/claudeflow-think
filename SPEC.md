# claudeflow-think 仕様書

**バージョン**: 2.2.0
**作成日**: 2026-06-23
**更新日**: 2026-06-26
**対象環境**: Mac mini M4 / macOS / Apple Silicon

> **思想原則**: 本仕様書は [claudeflow PHILOSOPHY.md](https://github.com/simadach/claudeflow/blob/main/PHILOSOPHY.md) の実現手段である。
> 「仕様通りに動くこと」と「人間にとって心地よい思考の場であること」は別問題であり、
> 関与するすべての AI エージェントは PHILOSOPHY.md を最上位の判断基準とすること。

---

## 1. 概要

アイデア・意思決定を `idea.md` に書くと、Claude がまだ言語化されていない懸念・盲点・前提を
`REVIEW.md` として生成する。iPhone Obsidian で各項目を判断し、メインセッションが `idea.md` を更新する（深化ループ）。

> ⚠️ **Web UI でファイルを編集する場合は `simadach/claudeflow-think` リポジトリの `ideas/{slug}/idea.md` を編集すること。**
> アイデアは独立リポジトリではなく claudeflow-think のモノレポに含まれる。

```
idea.md 記述 → simadach/claudeflow-think へ push（ideas/{slug}/idea.md）
  → idea_watcher_cron.sh が変更検知（10分ごと）
  → notifications/think_review_*.json 書き込み
  → メインセッション（claude-discord）が次ターンで査読実行
  → REVIEW.md 生成 → idea repo git push
  → vault reviews/claudeflow-think/{slug}/ に push
  → iPhone Obsidian Git が自動 pull
  → [x] / [x] ❌ 理由：〇〇 を付けて保存 → Obsidian Git が自動 push
  → idea_watcher_cron.sh が vault REVIEW.md 変化を検知
  → notifications/think_refine_*.json 書き込み
  → メインセッションが次ターンで idea.md を更新
  → idea repo git push → vault 更新
  → ループ（idea が深まるほど REVIEW も深まる）
```

### v2.1.0 変更点（rereview / newquestion フロー追加・重複通知防止）

| 項目 | v2.0（旧） | v2.1（現行） |
|------|-----------|------------|
| 返答への対応 | なし | `> 返答:` を書いて push → `think_rereview_request` → 指摘を更新 |
| 追加質問の経路 | なし | `## ❓ 追加の疑問` に書いて push → `think_newquestion_request` → 新項目追加 |
| vault REVIEW.md 変化検知 | [x] + 全体ハッシュ | [x]・返答・疑問を独立ハッシュで個別追跡 |
| rereview 重複防止 | なし | `detect_replies.py` が `（返答確認済み）` 付き行をスキップ |
| idea.md 検知スキップ条件 | `apply:` / `refine:` コミット | + `rereview:` コミットも追加 |

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
│       └── claudeflow-think/    ← ★ think は claudeflow-think（/think/ ではない）
│           └── {idea-slug}/
│               ├── idea.md      ← メインセッションがコピー
│               └── REVIEW.md    ← メインセッションがコピー → iPhone に配信
└── logs/

~/claude/claudeflow-think/       ← 本フレームワーク（simadach/claudeflow-think リポジトリ）
├── SPEC.md
├── README.md
├── scripts/
│   ├── idea_watcher_cron.sh     # idea.md 変更 / vault REVIEW.md 変化を検知 → JSON 書き込み
│   ├── detect_replies.py        # REVIEW.md から未処理の > 返答: を抽出
│   ├── detect_new_questions.py  # REVIEW.md の ❓ 追加の疑問セクションを抽出
│   ├── review.sh                # 手動トリガー用（→ JSON 書き込み）
│   ├── refine.sh                # 手動トリガー用（→ JSON 書き込み）
│   └── new-idea.sh              # 新規アイデア作成
├── templates/
│   ├── idea_template.md
│   ├── REVIEW_TEMPLATE.md
│   └── project_template.yaml
├── ideas/                       ← ★ アイデアは claudeflow-think のモノレポに含まれる
│   └── {idea-slug}/             ← 各アイデア（独立リポジトリではない）
│       ├── .claudeflow-think.yaml
│       ├── idea.md              ← 人間が記述するアイデア・意思決定ドキュメント
│       ├── REVIEW.md            ← メインセッションが生成
│       └── archive/             ← idea.md の過去スナップショット（.gitignore 対象）
├── state/                       ← SHA・ハッシュ管理（.gitignore 対象）
└── logs/                        ← ログ（.gitignore 対象）
```

> ⚠️ **push 先は `simadach/claudeflow-think` のみ。**  
> アイデアごとに別リポジトリを作ると watcher が検知できない。  
> `new-idea.sh` を使えば自動的にモノレポの一部として作成される。

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
| **返答を書く** | `> 返答: ○○の理由で問題なし` | `think_rereview_request` → 指摘を再査読・更新 |
| **疑問を追加** | `## ❓ 追加の疑問` に `- 質問` を書く | `think_newquestion_request` → 新項目として追加 |

> **コード版との違い**: ❌ は「スキップ（無視）」ではなく「**意識的に考慮した上で却下**」を意味する。
> 却下理由が idea.md に記録されることで、「考えた証拠」が残る。

### REVIEW.md への返答（think_rereview）

```markdown
- [ ] #005 **予算の判断軸が定まっていないかもしれません**
  ...
  > 返答: GPU は妥協しない方針で決定。残りは RAM・SSD の削減で対応する
```

- 空の `> 返答:` はスキップ（プレースホルダーとして残せる）
- 処理後、Claude が `（返答確認済み）` を `> 返答:` 行末に追記 → 重複 rereview を防止
- `[x]` チェックと独立（refine と rereview は同時に処理できる）

### REVIEW.md への疑問追加（think_newquestion）

```markdown
## ❓ 追加の疑問

- 9800X3D と 7800X3D の価格差は今どのくらい？
```

- 追加後、セクションは `<!-- processed -->` になり再処理されない
- `> 返答:` とは独立して動作（同時に書いても両方処理される）

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
  "vault_review_dir": ".../vault/reviews/claudeflow-think/...",
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
  "think_root": ".../claudeflow-think",
  "vault_review_path": ".../vault/reviews/claudeflow-think/.../REVIEW.md",
  "refine_prompt": "（精錬指示）",
  "approved_ids": "#001 #002",
  "timestamp": "2026-06-23 12:00"
}
```

### think_rereview_*.json

```json
{
  "type": "think_rereview_request",
  "idea_slug": "副業戦略2026",
  "idea_name": "副業戦略2026",
  "idea_dir": "...",
  "idea_file": ".../idea.md",
  "review_file": ".../REVIEW.md",
  "think_root": ".../claudeflow-think",
  "vault_review_path": ".../vault/reviews/claudeflow-think/.../REVIEW.md",
  "vault_review_dir": ".../vault/reviews/claudeflow-think/副業戦略2026",
  "responded_ids": "#003 #005",
  "responses": {"#003": "返答テキスト", "#005": "返答テキスト"},
  "timestamp": "2026-06-23 12:00"
}
```

### think_newquestion_*.json

```json
{
  "type": "think_newquestion_request",
  "idea_slug": "副業戦略2026",
  "idea_name": "副業戦略2026",
  "idea_dir": "...",
  "idea_file": ".../idea.md",
  "review_file": ".../REVIEW.md",
  "think_root": ".../claudeflow-think",
  "vault_review_path": ".../vault/reviews/claudeflow-think/.../REVIEW.md",
  "vault_review_dir": ".../vault/reviews/claudeflow-think/副業戦略2026",
  "questions": ["質問1", "質問2"],
  "timestamp": "2026-06-23 12:00"
}
```

---

## 6. スクリプト仕様

### 6-1. idea_watcher_cron.sh（メイン監視スクリプト）

**役割**: 2つの変化を検知して notifications/ に JSON を書き込む。`claude -p` は一切呼ばない。

**① vault ポーリング（REVIEW.md 変更検知）**:
1. `cd VAULT_DIR && git fetch + pull --rebase`
2. `reviews/claudeflow-think/*/REVIEW.md` の内容ハッシュを前回と比較
3. ハッシュ変化あり → 以下の3種類を独立して検知（同一ファイルでも複数通知可）

   **①-a 追加の疑問（`## ❓`）検知**:
   - `question_hash_{slug}` が変化 + `detect_new_questions.py` で質問が 1 件以上
   - `notifications/think_newquestion_{timestamp}.json` を書き込み

   **①-b 返答（`> 返答:`）検知**:
   - `reply_hash_{slug}` が変化 + `detect_replies.py` で未処理返答が 1 件以上
   - 未処理 = `（返答確認済み）`・`✅ 対象外`・`✅ 反映済み` を含まない返答行
   - `notifications/think_rereview_{timestamp}.json` を書き込み

   **①-c [x] 承認検知**:
   - `refine_hash_{slug}`（`[x]` 行のみのハッシュ）が変化 + `反映済み`・`対象外` 除外の承認 ID がある
   - idea repo の REVIEW.md に同期 → `notifications/think_refine_{timestamp}.json` を書き込み

**② モノレポポーリング（idea.md 変更検知）**:
1. 各 `ideas/*/.claudeflow-think.yaml` を走査
2. `idea.md` の最終コミット SHA（`git log origin/main -1`）を前回と比較
3. 変化あり + `refine:` / `rereview:` / `apply:` コミットでない → `git pull` → `think_review_*.json` を書き込み

### 6-2. review.sh（手動トリガー）

`think_review_*.json` を書き込むだけ。
`claude -p` は呼ばない。メインセッションが処理する。

### 6-3. refine.sh（手動トリガー）

`think_refine_*.json` を書き込むだけ。
`claude -p` は呼ばない。メインセッションが処理する。

---

## 7. メインセッションでの処理内容

メインセッションは `notifications/think_*.json` を検出したとき、以下を実行する。
**詳細手順は CLAUDE.md の「ClaudeFlow 通知キュー」セクションが正文**。ここは構造の概要のみ示す。

### think_review_request の処理

```
1. DM に「💡 {idea_name} の査読を開始しました」を送信
2. idea_file + context を読み、review_prompt の観点で REVIEW.md を生成
3. think_root の git に commit + push（msg: review: {idea_name} {timestamp}）
4. vault: vault_review_dir に REVIEW.md + idea.md をコピー → 同期検証 → git push
5. DM に「💡 {idea_name} の査読が完了しました」を送信
6. 通知ファイルを削除
```

### think_refine_request の処理

```
1. DM に「✨ {idea_name} の精錬を開始しました」を送信
2. REVIEW.md を読み、approved_ids の [x] 行（反映済み・対象外 除く）を確認
3. idea_file を archive/idea_{date}.md にスナップショット保存
4. [x]（❌ なし） → idea.md の該当セクションを更新
   [x] ❌ → idea.md に「意識的に却下した観点」として記録
5. REVIEW.md の反映行を「- [x] #XXX ✅ 反映済み」に更新、STATUS を更新
6. think_root の git に commit + push（msg: refine: {approved_ids} {timestamp}）
7. vault: STATUS に応じて REVIEW.md をアーカイブまたはトップレベルに保持 + idea.md 同期 → git push
8. DM に「✨ {idea_name} に {approved_ids} を反映しました」を送信
9. 通知ファイルを削除
```

### think_rereview_request の処理

```
1. DM に「🔄 {idea_name} の再査読を開始しました」を送信
2. REVIEW.md と responses を照合し、返答の種類を判断:
   - 「対象外・前提違い」→ 指摘を「✅ 対象外（返答: ○○）」に変更
   - 「補足・背景説明」 → 指摘本文を精緻化。> 返答: 行末に（返答確認済み）を追記
   - 「確認・同意」    → 指摘末尾に（返答確認済み）を追記
3. すべての処理済み > 返答: 行に（返答確認済み）を必ず付与（重複検知防止）
4. think_root の git に commit + push（msg: rereview: {responded_ids} {timestamp}）
5. vault: REVIEW.md を更新版で上書き → 同期検証 → git push
6. DM に「🔄 {idea_name} の再査読が完了しました」を送信
7. 通知ファイルを削除
```

### think_newquestion_request の処理

```
1. DM に「❓ {idea_name} の追加の疑問を処理しています」を送信
2. REVIEW.md の既存最大 ID を確認（次 ID を決める）
3. 各質問を idea.md の内容と照合し、新しい REVIEW.md 項目を生成（🔴/🟡/❓/💭 分類）
4. REVIEW.md に追記し、「## ❓ 追加の疑問」セクションを「<!-- processed -->」に変更
5. think_root の git に commit + push（msg: review(newq): {idea_name} {timestamp}）
6. vault: REVIEW.md を更新版で上書き → 同期検証 → git push
7. DM に「❓ {idea_name} の追加の疑問を REVIEW.md に追加しました」を送信
8. 通知ファイルを削除
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

# Step 4: vault に claudeflow-think/ ディレクトリを作成
mkdir -p ~/claude/claudeflow/vault/reviews/claudeflow-think
cd ~/claude/claudeflow/vault
git add reviews/claudeflow-think/
git commit -m "feat: add claudeflow-think/ directory for vault"
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
  □ new-idea.sh で作成（モノレポに自動統合）
  □ ⚠️ 別リポジトリを作らない。アイデアは simadach/claudeflow-think の ideas/ に置く
  □ idea.md に核心・背景・現在の考えを記述して push
  □ 10分以内に idea_watcher_cron.sh が検知 → メインセッションが査読

日常ループ:
  □ idea.md を更新して simadach/claudeflow-think へ push
  □ ⚠️ Web UI 編集時は「simadach/claudeflow-think」を選ぶこと（別リポジトリにしない）
  □ iPhone Obsidian で vault/reviews/claudeflow-think/{slug}/REVIEW.md を確認
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
