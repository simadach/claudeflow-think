# Gemini Home Voice

**作成日**: 2026-06-29
**最終更新**: 2026-06-29
**ステータス**: 探索中

---

## 核心

Google Nest Mini を音声I/Oとして使い、Gemini を「家の頭脳」、Home Assistant を「家の神経」として繋ぐことで、命令実行型スマートスピーカーではなく **住宅を理解して自然に会話する対話型ホームAI** を実現する。

---

## 背景・動機

現在のスマートホーム（Home Assistant）は高度な自動化が実現できているが、操作インターフェースがダッシュボード・音声命令（定型）に限られている。
「暑い」「なんで電気代高い？」のような自然な問いかけに対して、住宅全体の状態を踏まえた文脈的な応答を返せるシステムが欲しい。
また、AIから積極的に話しかけてくる（「今発電量が多いのでこのタイミングで洗濯機を」）という ProActive な提案を受けたい。

---

## 現在の考え

### システム構成（案）

ユーザー音声 → Google Nest Mini → Gemini（会話・理解・提案） → Home Assistant（状態取得・制御）
Home Assistant から Gemini へ状態フィードバック → Gemini から Nest Mini へ応答

### Gemini と HA の連携方法（未確定）

- Gemini の Function Calling / Tool Use で HA REST API を直接叩く
- または HA 側に Gemini 統合（google_generative_ai_conversation）を使う
- Google Home との連携経由で Nest Mini を Gemini の入出力にする

### 実現したい体験（優先順）

1. **状況理解応答**：「暑い」→ 室温取得 → 「31℃です。エアコンをつけますか？」
2. **電力分析**：「なんで電気代高い？」→ HA データ → Gemini 解析 → 説明
3. **プロアクティブ提案**：発電量増加 → Gemini 判断 → Nest Mini から話しかける
4. **EV連携**：「充電どう？」→ Tesla 状態 + 電力状況 → 最適提案

---

## 期待する結果・価値

- 定型命令でなく自然言語で家を操作・理解できる
- AI が住宅エネルギーの文脈を持った提案をしてくれる
- 家族それぞれに合わせた会話（将来）
- Home Assistant の複雑さを隠しつつ能力を最大活用

---

## 既知の懸念・トレードオフ

- Google Nest Mini と Gemini の統合方法が不明瞭（API 経由か、Google Home アプリか）
- HA の google_generative_ai_conversation 統合の制限・できることの範囲
- プロアクティブ通知のタイミング制御（頻繁すぎると鬱陶しい）
- Gemini API コスト（会話のたびにトークン消費）
- ローカル処理 vs クラウド依存のトレードオフ
- 家族（子供含む）が使える UI の簡素さ vs 機能の豊富さ

---

## 前提条件

- Home Assistant が稼働中で REST API / WebSocket が利用可能（確認済み）
- Google Nest Mini が既存環境にある（確認要）
- Gemini API キーが取得できる
- Google Home と Gemini の連携が技術的に可能（未調査）

---

## 意識的に考慮したが却下した観点

（まだなし）

---

## 次のアクション

- [ ] Google Home + Gemini の連携方法を調査
- [ ] HA の google_generative_ai_conversation 統合の現状・できること確認
- [ ] Nest Mini をカスタム音声エンドポイントとして使う方法の調査
- [ ] プロトタイプ：HA webhook → Gemini → HA 制御 の最小フロー
