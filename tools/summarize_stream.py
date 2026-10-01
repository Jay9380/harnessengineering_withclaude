#!/usr/bin/env python3
"""claude -p --output-format stream-json --verbose 출력(jsonl)을 사람이 읽기 좋게 요약한다.

출력 예:
  TOOL main Skill {"skill": "commit-message"}      ← 메인 세션의 도구 호출
  TOOL sub  Write {"file_path": "..."}              ← 서브에이전트의 도구 호출
    ERR  No such tool available: Write ...          ← 도구 실행 오류
  RESULT success cost=0.147 turns=8                 ← 최종 결과
사용: python3 tools/summarize_stream.py run.jsonl
"""
import json
import sys


def main(path: str) -> None:
    for line in open(path, encoding="utf-8"):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = d.get("type")
        if t == "system" and d.get("subtype") == "init":
            # 세션 시작 시 클로드 코드가 인식한 에이전트·스킬 목록 (프런트매터가 깨지면 여기서 빠진다)
            print("INIT agents:", d.get("agents"))
            print("INIT skills:", [s for s in d.get("skills", [])][:20])
        elif t == "assistant":
            who = "sub " if d.get("parent_tool_use_id") else "main"
            for c in d["message"]["content"]:
                if c.get("type") == "tool_use":
                    print("TOOL", who, c["name"], json.dumps(c["input"], ensure_ascii=False)[:160])
        elif t == "user":
            content = d["message"].get("content")
            if isinstance(content, list):
                for c in content:
                    if c.get("type") == "tool_result" and c.get("is_error"):
                        print("  ERR ", str(c.get("content"))[:220])
        elif t == "result":
            print("RESULT", d.get("subtype"), "cost=%.3f" % d.get("total_cost_usd", 0), "turns=", d.get("num_turns"))
            print(d.get("result", "")[:800])


if __name__ == "__main__":
    main(sys.argv[1])
