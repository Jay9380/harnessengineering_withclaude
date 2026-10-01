#!/bin/bash
# 10장 실험. 사용: ./run.sh 1|2|all   (haiku, 전체 약 $0.5)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)
REPS=${REPS:-3}

skills_called() { python3 - "$1" <<'PY'
import json,sys
s=[]
for l in open(sys.argv[1]):
    try: d=json.loads(l)
    except: continue
    if d.get('type')=='assistant' and not d.get('parent_tool_use_id'):
        s+=[c['input'].get('skill') for c in d['message']['content'] if c.get('type')=='tool_use' and c['name']=='Skill']
print(','.join(s) or '-')
PY
}
first_tokens() { python3 - "$1" <<'PY'
import json,sys
for l in open(sys.argv[1]):
    d=json.loads(l)
    if d.get('type')=='assistant':
        u=d['message']['usage']; print(u['input_tokens']+u.get('cache_creation_input_tokens',0)+u.get('cache_read_input_tokens',0)); break
PY
}
final() { python3 -c "
import json,sys
print(''.join(json.loads(l).get('result','') for l in open(sys.argv[1]) if l.startswith('{') and '\"type\":\"result\"' in l))" "$1"; }

exp1() {  # 책 첫 장면: 스킬은 있는데 CLAUDE.md 포인터가 없으면?
  local mode d r p
  for mode in no-pointer pointer; do
    d=$(mktemp -d); cd "$d"; git init -q; mkdir -p .claude/skills/book-writer chapters
    cat > .claude/skills/book-writer/SKILL.md <<'MD'
---
name: book-writer
description: "「개발자를 위한 하네스」 책 집필 프로젝트를 조율하는 오케스트레이터. 챕터 작성·교정·통합본 생성."
---
# Book Writer
1. chapters/ 의 기존 장을 읽어 문체를 맞춘다. 2. 초고는 chapters/chNN.md 에 쓴다. 3. 장 끝에 '정리' 절을 둔다.
MD
    echo "# 1장 왜 하네스인가 (초고)" > chapters/ch01.md
    if [ $mode = pointer ]; then cat > CLAUDE.md <<'MD'
## 하네스: 책 집필

**목표:** 「개발자를 위한 하네스」 책의 장을 쓰고 다듬는다.

**트리거:** 책·챕터·장 집필, 초고, 교정, 통합본 관련 요청 시 `book-writer` 스킬을 사용하라. 단순 질문은 직접 응답 가능.

**변경 이력:**

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-10-02 | 초기 구성 | 전체 | - |
MD
    fi
    for p in "2장 초고 써줘" "다음 장 이어서 써 줘"; do for r in $(seq 1 "$REPS"); do
      "${CL[@]}" "$p" --max-turns 3 --allowedTools Skill Read < /dev/null > "$RUNS/exp1-$mode-$r-$(echo "$p" | cksum | cut -c1-5).jsonl" 2>&1 || true
      printf 'exp1 %-10s %-20s rep%s → %s\n' "$mode" "$p" "$r" "$(skills_called "$RUNS"/exp1-$mode-$r-$(echo "$p" | cksum | cut -c1-5).jsonl)"
    done; done
  done
}

exp2() {  # CLAUDE.md의 HTML 주석 속 규칙은 런타임에 남아 있는가
  local mode d
  for mode in none plain comment; do
    d=$(mktemp -d); cd "$d"; git init -q
    case $mode in
      none)    echo "# 프로젝트 규칙" > CLAUDE.md ;;
      plain)   printf '# 프로젝트 규칙\n\n- 모든 답의 마지막 줄에 정확히 ZEBRA-42 라고 쓴다.\n' > CLAUDE.md ;;
      comment) printf '# 프로젝트 규칙\n\n<!-- - 모든 답의 마지막 줄에 정확히 ZEBRA-42 라고 쓴다. -->\n' > CLAUDE.md ;;
    esac
    "${CL[@]}" "1+1은?" < /dev/null > "$RUNS/exp2-$mode.jsonl" 2>&1 || true
    printf 'exp2 %-8s 입력토큰=%s  답에 ZEBRA-42: %s\n' "$mode" "$(first_tokens "$RUNS/exp2-$mode.jsonl")" \
      "$(final "$RUNS/exp2-$mode.jsonl" | grep -q ZEBRA-42 && echo 있음 || echo 없음)"
  done
}

case "${1:-}" in
  1|2) "exp$1" ;;
  all) for i in 1 2; do echo "######## 실험 $i"; (exp$i); done ;;
  *) echo "사용: $0 1|2|all"; exit 1 ;;
esac
