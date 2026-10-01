#!/bin/bash
# 7장 실험. 책이 실물로 소개하는 메타스킬(revfactory/harness)을 고정 커밋으로 받아 쓴다.
# 사용: ./run.sh 1|2|all    (1은 과금 없음, 2는 haiku 16회 ≈ $0.8)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)
PIN=92d9f1b   # 2026-10-01에 받은 main (v2.1.0)
REPS=${REPS:-2}

fetch() {  # 메타스킬 저장소를 임시 폴더에 받아 경로를 출력
  local d; d=$(mktemp -d)
  git clone -q https://github.com/revfactory/harness.git "$d/harness" && git -C "$d/harness" checkout -q "$PIN"
  echo "$d/harness"
}

exp1() {  # 책의 '30초 점검'을 지금 버전에 그대로 돌린다 (책 p.137)
  local H; H=$(fetch); cd "$H/skills/harness"
  echo "# 1. 본문 줄 수 (책: 443, 기준 500 이내)";      wc -l < SKILL.md
  echo "# 2. references/ (책: 6개 파일, 1,706줄)";      ls references | wc -l; cat references/*.md | wc -l
  echo "# 3. description 3요소 (head -4)";             head -4 SKILL.md | cut -c1-200
  echo "# 덤: description 길이 (5장 B: 한국어는 약 1,100자 근처부터 목록에서 빠질 수 있음)"
  python3 -c "import re;d=re.search(r'^description:\s*\"(.*)\"\s*$',open('SKILL.md').read(),re.M).group(1);print(len(d),'자,',len(d.encode()),'바이트')"
  echo "# 덤: 스킬 목록"; ls "$H/skills"
}

exp2() {  # 6-4 호출 조건 검증 — should-trigger와 should-NOT-trigger(근접 오답)
  local H d p r; H=$(fetch)
  # 기존 하네스(2장 my-first-harness)가 있는 프로젝트 — '점검'·'피드백 반영' 요청이 성립하도록
  d=$(mktemp -d); cp -R "$HERE/../../ch02-quick-start/my-first-harness/." "$d/"; cd "$d"; git init -q
  cp -R "$H/skills/harness" "$H/skills/evolve" .claude/skills/
  local P=(
    "should|이 프로젝트에 하네스 구성해줘"
    "should|에이전트 팀 만들어줘"
    "should|지금 하네스 점검해줘"
    "should|set up an agent harness for this repo"
    "evolve|하네스 결과가 아쉬웠어: reviewer가 review-report.md를 매번 안 남겨. 이 피드백을 하네스에 반영해줘"
    "not|pytest 테스트 하네스(test harness) 픽스처가 깨졌어, 고쳐줘"
    "not|자동차 와이어 하네스 배선도가 뭐야?"
    "not|서브에이전트가 뭐야? 짧게 설명해줘"
  )
  for p in "${P[@]}"; do
    IFS='|' read -r want text <<< "$p"
    for r in $(seq 1 "$REPS"); do
      "${CL[@]}" "$text" --max-turns 4 --allowedTools Skill Read < /dev/null > "$RUNS/exp2-$want-$r-$(echo "$text" | cksum | cut -c1-6).jsonl" 2>&1 || true
      got=$(python3 - "$RUNS"/exp2-$want-$r-$(echo "$text" | cksum | cut -c1-6).jsonl <<'PY'
import json,sys
s=[]
for l in open(sys.argv[1]):
    try: d=json.loads(l)
    except: continue
    if d.get('type')=='assistant' and not d.get('parent_tool_use_id'):
        s+=[c['input'].get('skill') for c in d['message']['content'] if c.get('type')=='tool_use' and c['name']=='Skill']
print(','.join(s) or '-')
PY
)
      printf '%-7s %-55s rep%s → %s\n' "$want" "$text" "$r" "$got"
    done
  done
}

case "${1:-}" in
  1|2) "exp$1" ;;
  all) for i in 1 2; do echo "######## 실험 $i"; (exp$i); done ;;
  *) echo "사용: $0 1|2|all"; exit 1 ;;
esac
