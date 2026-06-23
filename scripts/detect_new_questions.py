#!/usr/bin/env python3
"""
REVIEW.md の「## ❓ 追加の疑問」セクションから未処理の質問を抽出する。
- 「- 」で始まる行を質問として抽出
- 空行・コメント・処理済み（<!-- processed -->）はスキップ
- 質問がなければ None を返す
"""
import re, json, sys

def detect_new_questions(review_path):
    try:
        content = open(review_path).read()
    except Exception:
        return None

    match = re.search(r'## ❓ 追加の疑問\s*\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if not match:
        return None

    # processed マークがあるセクションはスキップ
    section = match.group(1)
    if '<!-- processed -->' in section:
        return None

    questions = []
    for line in section.split('\n'):
        line = line.strip()
        if line.startswith('- ') and len(line) > 2:
            q = line[2:].strip()
            if q:
                questions.append(q)

    return questions if questions else None


if __name__ == '__main__':
    path = sys.argv[1]
    result = detect_new_questions(path)
    if result:
        print(json.dumps(result, ensure_ascii=False))
