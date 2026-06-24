#!/usr/bin/env python3
"""REVIEW.md から '> 返答:' 行を抽出して JSON 出力する"""
import re, json, sys

PROCESSED_MARKERS = ('（返答確認済み）', '✅ 対象外', '✅ 反映済み', '✅ 処理済み')

def detect_replies(review_path):
    try:
        lines = open(review_path).readlines()
    except Exception:
        return None

    responses = {}
    current_id = None
    current_item_line = ''
    replies = []

    for line in lines:
        m = re.match(r'^- \[.\] (#\d+)', line)
        if m:
            if current_id and replies:
                # 項目自体が処理済みでなければ追加
                if not any(marker in current_item_line for marker in PROCESSED_MARKERS):
                    responses[current_id] = ' '.join(replies)
            current_id = m.group(1)
            current_item_line = line
            replies = []
        elif current_id and '> 返答:' in line:
            text = re.sub(r'^\s*> 返答:\s*', '', line).strip()
            # 処理済みマーカーを含む返答はスキップ
            if text and not any(marker in text for marker in PROCESSED_MARKERS):
                replies.append(text)

    if current_id and replies:
        if not any(marker in current_item_line for marker in PROCESSED_MARKERS):
            responses[current_id] = ' '.join(replies)

    return responses if responses else None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
    result = detect_replies(sys.argv[1])
    if result:
        print(json.dumps(result, ensure_ascii=False))
