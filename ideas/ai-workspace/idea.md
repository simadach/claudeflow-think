# AI Workspace

**作成日**: 2026-06-29
**最終更新**: 2026-06-29
**ステータス**: 探索中

---

## 核心

AIとの会話が、そのままUI操作になる。
チャットで「調べて」と言うと、AIが画像・Web・動画などのカードをキャンバスに自動配置する。
チャットを返すのではなく、情報空間そのものを編集するAIネイティブなデスクトップ環境。

---

## 背景・動機

現在のAIチャットUIには根本的な限界がある。
情報は文章として返ってくるが、人間が本当に欲しいのは「情報の空間的な見通し」だ。
Tesla Model 3を調べるとき、画像・価格・レビュー・動画が横断的に見渡せると判断が速い。
しかしChatGPTもClaudeも、情報を「テキストの流れ」として返すことしかできない。

AIが文章を返すのではなく、AIが情報空間を直接編集する——という発想の転換がAI Workspaceのコアだ。

また個人的に、Home Assistant・TeslaMate・HEMS制御など多くのツールを使い分けている。
それらを一つのワークスペースで束ねられれば、日常の情報収集・意思決定・ホームオートメーションが統合できる。

---

## 現在の考え

### フェーズ1（まず動かす）
- **プラットフォーム**: Webブラウザ（React SPA）
- **AI**: Claude API（Anthropic）
- **最初に作るカード**: 画像カード・Webカード（検索結果表示）
- **ユースケース**: 「Tesla Model 3を調べて」→ 画像・Web記事が自動配置される

### アーキテクチャの基本方針
- AIとWorkspaceは責務分離する
  - AI：何をするかを判断（カードの種類・内容・配置を決定）
  - Workspace Engine：どう表示するかを担当
- AIはWorkspace APIを呼び出す形でカードを操作する
- この分離により、将来的にGemini・GPT-4o等のLLMを差し替え可能にする

### Workspace API（コア操作）
```
createCard(type, content, position)
deleteCard(id)
moveCard(id, position)
resizeCard(id, size)
replaceCard(id, newContent)
groupCards(ids)
pinCard(id)
focusCard(id)
search(query)
playMedia(id)
```

### カードロードマップ
1. Image Card（フェーズ1）
2. Web Card（フェーズ1）
3. Markdown Card
4. Video Card
5. PDF Card
6. Note Card
7. Home Assistant Card
8. Three.js Scene Card
9. Browser Card
10. Music Card

### 将来の拡張
- Home Assistant連携（スマートホーム制御カード）
- Claude Code連携（コーディング支援カード）
- Blender連携（3Dビューカード）
- 音声インターフェース（マイク→AI→カード操作）
- Vision Proのような空間UI

---

## 期待する結果・価値

**自分にとって**: 調査・設計・ホームオートメーションを一つのインターフェースで完結できる。ツールの切り替えコストがなくなる。

**他のユーザーにとって**: 「AIに話しかけたら必要な情報が整理されて見える」という体験。検索エンジンの次の世界観。

**プロダクトとして**: AIチャットとは異なる、AIネイティブなデスクトップ環境という新しいカテゴリを作る。

---

## 既知の懸念・トレードオフ

- **カードレイアウトの自由度と秩序のバランス**: AIが自動配置すると、ユーザーが求めるレイアウトと乖離する可能性がある
- **LLMのAPI費用**: 検索のたびにAPI呼び出しが発生するとコストが積み上がる
- **Web検索の実装**: ブラウザからリアルタイムWeb検索をするにはバックエンドが必要になる
- **マルチユーザー対応の複雑さ**: 個人ツールと他人向けプロダクトでは設計の複雑度が大きく異なる

---

## 前提条件

- Claude APIでWorkspace APIを呼び出す「function calling」が安定して動作する
- Webブラウザで十分なカード操作体験（ドラッグ&ドロップ等）が実現できる
- フェーズ1は自分一人のローカル環境で動けばよい（認証・スケーラビリティは後回し）

---

## 意識的に考慮したが却下した観点

（まだなし）

---

## 次のアクション

- [ ] idea.mdをClaudeFlow-Thinkに登録してREVIEW.mdを生成する
- [ ] フェーズ1のspec.mdを書く（Workspace API定義・カードスキーマ・React実装方針）
- [ ] 最小プロトタイプを動かす（画像カード1枚だけでも配置できる状態）
