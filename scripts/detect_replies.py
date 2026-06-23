#!/usr/bin/env python3
"""REVIEW.md から '> 返答:' 行を抽出して JSON 出力する"""
import re, json, sys

def detect_replies(review_path):
    try:
        lines = open(review_path).readlines()
    except Exception:
        return None

    responses = {}
    current_id = None
    replies = []

    for line in lines:
        m = re.match(r'^- \[.\] (#\d+)', line)
        if m:
            if current_id and replies:
                responses[current_id] = ' '.join(replies)
            current_id = m.group(1)
            replies = []
        elif current_id and '> 返答:' in line:
            replies.append(re.sub(r'^\s*> 返答:\s*', '', line).strip())

    if current_id and replies:
        responses[current_id] = ' '.join(replies)

    return responses if responses else None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
    result = detect_replies(sys.argv[1])
    if result:
        print(json.dumps(result, ensure_ascii=False))
