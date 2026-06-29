# Gemini Home Voice

**作成日**: 2026-06-29
**最終更新**: 2026-06-29
**ステータス**: 探索中

---

## 核心

HA の `google_generative_ai_conversation` 統合（Gemini）を「家の頭脳」として使い、Home Assistant を「家の神経」として繋ぐことで、命令実行型スマートスピーカーではなく **住宅を理解して自然に会話する対話型ホームAI** を実現する。  
音声I/Oは HA Assist パイプライン（Companion アプリ・マイク）を主軸とし、Nest Mini は Cast API 経由の **出力スピーカー（TTS再生）** として活用する。

---

## 背景・動機

現在のスマートホーム（Home Assistant）は高度な自動化が実現できているが、操作インターフェースがダッシュボード・音声命令（定型）に限られている。
「暑い」「なんで電気代高い？」のような自然な問いかけに対して、住宅全体の状態を踏まえた文脈的な応答を返せるシステムが欲しい。

---

## 現在の考え

### システム構成（案）

```
ユーザー音声
  → HA Assist パイプライン（STT: Whisper または HA Companion アプリ）
  → google_generative_ai_conversation 統合（Gemini）
  → Gemini が HA の状態を取得（Function Calling / Tool Use で HA REST API）
  → Gemini が応答テキスト生成
  → HA TTS → Nest Mini（Cast API 経由で音声出力）
```

> **方針変更（#001 反映）**: Nest Mini をカスタム STT エンドポイントとして使う構成（「Nest Mini に話しかけた音声をカスタムモデルに送る」）は現時点で技術的に困難。代わりに HA 側の Assist パイプラインを入力経路として使い、Nest Mini は出力（TTS再生）専用とする。

### Gemini と HA の連携方法（採用方針）

- HA の `google_generative_ai_conversation` 統合を Assist パイプラインのエンジンとして設定
- Gemini の Function Calling / Tool Use で HA REST API を直接叩く（状態取得・デバイス制御）
- Nest Mini への応答再生は Cast API 経由（`media_player.play_media` + TTS）

### 実現したい体験（優先順）

1. **状況理解応答**：「暑い」→ 室温取得 → 「31℃です。エアコンをつけますか？」
2. **電力分析**：「なんで電気代高い？」→ HA データ → Gemini 解析 → 説明
3. **EV連携**：「充電どう？」→ Tesla 状態 + 電力状況 → 最適提案
4. **プロアクティブ提案**（後段フェーズ）：発電量増加 → Gemini 判断 → Nest Mini から話しかける

> **フェーズ分け（#002 反映）**: プロアクティブ提案（AIから先に話しかける）は後段フェーズに延期。HA 統合だけでは実現できない別設計（HA オートメーション + TTS）が必要なため、まずユーザーが話しかける方向から実装を進める。

### 代替アーキテクチャ（将来検討）

- **Gemini Live API**（#004 反映）: Gemini 2.0 以降の音声↔音声ストリーミング API。テキスト変換なしで「話す→考える→話す」がリアルタイムで実現できる。Raspberry Pi など別デバイスにマイク+スピーカーを繋ぐ構成も選択肢。現時点では HA 統合より複雑になるため将来オプション。

---

## 期待する結果・価値

- 定型命令でなく自然言語で家を操作・理解できる
- AI が住宅エネルギーの文脈を持った提案をしてくれる
- 家族それぞれに合わせた会話（将来）
- Home Assistant の複雑さを隠しつつ能力を最大活用

---

## 既知の懸念・トレードオフ

- **ローカル Assist vs Gemini クラウドのトレードオフ**（#003 反映）: HA には Assist + Whisper（STT）+ Piper（TTS）+ カスタム intent でローカル完結の音声制御が実現できる。Gemini の「自然な対話」は強力だが、クラウド依存・コスト・プライバシーのトレードオフがある。ローカルファーストで始めて会話品質が不満な部分だけ Gemini にフォールバックする設計も検討価値あり。
- プロアクティブ通知のタイミング制御（頻繁すぎると鬱陶しい）← 後段フェーズで対処
- Gemini API コスト（会話のたびにトークン消費）
- ローカル処理 vs クラウド依存のトレードオフ
- 家族（子供含む）が使える UI の簡素さ vs 機能の豊富さ

---

## 前提条件

- Home Assistant が稼働中で REST API / WebSocket が利用可能（確認済み）
- Google Nest Mini が既存環境にある（確認要）
- Gemini API キーが取得できる
- `google_generative_ai_conversation` 統合が HA にインストール可能（確認要）

---

## 意識的に考慮したが却下した観点

（まだなし）

---

## 次のアクション

- [ ] HA の `google_generative_ai_conversation` 統合のインストール・動作確認
- [ ] Assist パイプラインに Gemini を接続し、基本応答が返るか検証
- [ ] Gemini Function Calling で HA REST API を叩く最小フロー実装
- [ ] Nest Mini に TTS 音声を Cast API 経由で再生する検証
- [ ] **Google Home Automations API の調査**（#005 反映）: フル自作の前に既存 Google Home 連携でどこまで届くか調査。Matter/Thread 統合や Automations API（2025年以降拡張中）を確認する
- [ ] Gemini Live API の可能性調査（#004 反映）: 音声↔音声ストリーミングの将来オプションとして
