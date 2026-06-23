# claudeflow-think

アイデアの精錬・意思決定のための ClaudeFlow 派生ワークフロー。

コードレビューではなく、**まだ言語化されていない懸念・盲点・前提**を Claude と一緒に掘り起こし、
Obsidian で「対応する / 意識的に却下する / 保留」を判断していく。

## コンセプト

```
idea.md を書いて GitHub push
  → 10分以内に Claude が盲点・懸念・前提を洗い出す → vault に REVIEW.md 配信
  → iPhone Obsidian で確認
    [x]          → idea.md に反映（深化）
    [x] ❌ 理由  → 意識的に却下（却下理由を idea.md に記録）
    [ ]          → 保留（次回 REVIEW でも再掲）
  → idea.md が自動更新 → ループ
```

## ClaudeFlow との違い

| | claudeflow | claudeflow-think |
|---|---|---|
| 入力 | spec.md（仕様書） | idea.md（アイデア・意思決定） |
| Claude の役割 | バグ・実装ミスを探す | 盲点・前提・感情的影響を探す |
| 反映対象 | コードファイル | idea.md 自体 |
| ❌ の意味 | スキップ（無視） | **意識的却下**（理由が idea.md に記録される） |

## アーキテクチャ（v2.0）

- **サブプロセス廃止**: `claude -p` を直接呼ばず `notifications/think_*.json` を書き込む  
- **iCloud 廃止**: `~/claude/claudeflow-think/` に配置（bird デーモンによる git デッドロック回避）
- **fswatch 廃止**: `idea_watcher_cron.sh` が 10 分ごとにポーリング
- **vault 同期**: `simadach/claudeflow` vault の `reviews/think/` 経由で iPhone に配信

## ドキュメント

- [SPEC.md](./SPEC.md) — システム仕様・セットアップ手順

## 依存関係

- [claudeflow](https://github.com/simadach/claudeflow) の `notifications/` と `vault/` を共有
- メインセッション（claude-discord）が `think_review_request` / `think_refine_request` を処理
