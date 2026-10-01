#!/bin/bash
# 11장: 같은 PR을 1인 리뷰어 vs 3인 팀(정적·설계·보안)으로. 모델은 모두 haiku(구조만 비교).
# 사용: ./run.sh [반복수=2]     (약 $1)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)
REPS=${1:-2}
# 저장된 로그만 다시 채점: ./run.sh rescore
OUT='발견을 JSON 배열 하나로만 출력하라(앞뒤 설명 금지): [{"file":"…","line":N,"category":"sql-injection|n+1|contract-mismatch|missing-tests|other","claim":"한 문장"}]'

agent() {  # agent <name> <description> <본문>
  printf -- '---\nname: %s\ndescription: "%s"\nmodel: haiku\ntools: Read, Grep, Glob\n---\n%s\n결과는 발견 목록(파일:줄, 무엇이 문제인지)을 텍스트로 반환한다. 코드는 고치지 않는다.\n' "$1" "$2" "$3" > ".claude/agents/$1.md"
}

score() { python3 - "$1" <<'PY'
import json,re,sys
txt=''.join(json.loads(l).get('result','') for l in open(sys.argv[1]) if l.startswith('{') and '"type":"result"' in l)
cost=max([json.loads(l).get('total_cost_usd',0) for l in open(sys.argv[1]) if l.startswith('{') and '"type":"result"' in l] or [0])
m=re.findall(r'\[\s*\{.*\}\s*\]', txt, re.S); items=[]
if m:
    try: items=json.loads(m[-1])
    except Exception: pass
def hit(pred): return any(pred(i) for i in items)
low=lambda i: (i.get('category','')+' '+i.get('claim','')).lower()
bugs={
 'SQL 인젝션(users.ts getUserByEmail)': hit(lambda i:'users.ts' in i.get('file','') and ('inject' in low(i) or '인젝션' in low(i))),
 'N+1(inviteMembers 루프)':            hit(lambda i:'users.ts' in i.get('file','') and ('n+1' in low(i) or '루프' in low(i) or 'loop' in low(i))),
 '경계면 불일치(useUser가 배열 기대)':   hit(lambda i:('contract' in low(i) or '배열' in low(i) or 'array' in low(i) or 'shape' in low(i)) and ('useUser' in i.get('file','') or 'refresh' in i.get('file',''))),
 '테스트 누락(refresh/inviteMembers)':  hit(lambda i:'missing-tests' in low(i) or '테스트' in low(i) or re.search(r'\b(no|missing|lack\w*|without)\b.{0,40}\btests?\b', low(i)) is not None),
}
print(f"  발견 {sum(bugs.values())}/4  (항목 {len(items)}개, 비용 ${cost:.3f})  " + ' '.join(('O' if v else 'x')+k.split('(')[0] for k,v in bugs.items()))
PY
}

if [ "${1:-}" = rescore ]; then for f in "$RUNS"/*.jsonl; do echo "$(basename "$f")"; score "$f"; done; exit 0; fi
for r in $(seq 1 "$REPS"); do
  # --- 1인 리뷰어 ---
  d=$(mktemp -d); cp -R "$HERE/../sample-pr/." "$d/"; cd "$d"; git init -q
  t0=$(date +%s)
  "${CL[@]}" "PR.md와 변경 파일을 리뷰해. 코딩 컨벤션·설계·성능·보안·테스트를 모두 본다. $OUT" \
    --max-turns 15 --allowedTools Read Grep Glob < /dev/null > "$RUNS/solo-$r.jsonl" 2>&1 || true
  echo "solo  rep$r  $(( $(date +%s)-t0 ))초"; score "$RUNS/solo-$r.jsonl"

  # --- 3인 팀 (서브에이전트 병렬 + 메인이 통합) ---
  d=$(mktemp -d); cp -R "$HERE/../sample-pr/." "$d/"; cd "$d"; git init -q; mkdir -p .claude/agents
  agent static-analyzer "PR 정적 분석: 반복 패턴·복잡도·루프 안 호출(N+1)·순환 의존." "변경 파일에서 규칙으로 잡을 수 있는 문제를 찾는다: 루프 안의 DB 호출(N+1), 중복, 복잡도, 타입 오류."
  agent design-reviewer "PR 설계 검토: 경계면 불일치(응답 래핑↔소비 쪽 기대 형태), 책임 분리." "API가 반환하는 모양과 그것을 쓰는 쪽(프런트 훅 등)이 기대하는 모양을 두 파일을 동시에 열어 대조한다. 변경된 기능에 테스트가 있는지도 본다."
  agent security-auditor "PR 보안 감사: OWASP Top 10, SQL 인젝션, 시크릿, 인증." "SQL 문자열 결합, 인증·토큰 처리, 시크릿 노출을 찾는다. CWE 번호를 붙인다."
  t0=$(date +%s)
  "${CL[@]}" "PR.md의 PR을 static-analyzer, design-reviewer, security-auditor 세 에이전트에게 한 번의 응답에서 동시에(run_in_background) 맡겨. 셋이 끝나면 결과를 합쳐 중복을 제거하라. $OUT" \
    --max-turns 15 --allowedTools Agent Read Grep Glob < /dev/null > "$RUNS/team-$r.jsonl" 2>&1 || true
  echo "team  rep$r  $(( $(date +%s)-t0 ))초"; score "$RUNS/team-$r.jsonl"
done
