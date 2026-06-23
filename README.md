# claudeflow-think

アイデアの精錬・意思決定のための ClaudeFlow 派生ワークフロー。

コードレビューではなく、**まだ言語化されていない懸念・盲点・前提**を Claude と一緒に掘り起こし、
Obsidian で「対応する / 意識的に却下する / 保留」を判断していく。

## コンセプト

```
あなたがアイデアや意思決定を idea.md に書く
  → Claude が盲点・懸念・前提を洗い出す → REVIEW.md 生成
  → iPhone Obsidian で確認
    [x]        → idea.md に反映（深化）
    [x] ❌     → 意識的に却下（却下理由を idea.md に記録）
    [ ]        → 保留（次回も残る）
  → refine.sh が idea.md を更新 → git push
  → ループ
```

## ClaudeFlow との違い

| | claudeflow | claudeflow-think |
|---|---|---|
| 入力 | spec.md（仕様書） | idea.md（アイデア・決断） |
| 査読観点 | バグ・実装ミス | 盲点・前提・感情・リスク |
| 反映対象 | コードファイル | idea.md 自体 |
| ❌ の意味 | スキップ | 意識的に却下（理由を記録） |

## ドキュメント

- [SPEC.md](./SPEC.md) — システム仕様

## 依存関係

[claudeflow](https://github.com/simadach/claudeflow) の
`notify.sh` を共通利用するため、先にセットアップすること。
