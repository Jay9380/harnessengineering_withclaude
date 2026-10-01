#!/bin/bash
# 13장: 워커 3명이 같은 batches.json에서 동시에 작업을 가져간다.
#  (A) 워커가 batches.json을 직접 읽고 고쳐서 선점   (B) 원자적 claim.sh로 선점
# 각 배치의 '변환'은 ./work.sh(1~3초 후 work.log에 "<배치> <워커>" 한 줄) — 중복·누락을 세기 위함.
# (echo >> 리다이렉트는 작업 폴더 쓰기라 승인이 필요해 거부된다 — 첫 실행에서 확인)
# 사용: ./run.sh A|B|all     (haiku 워커 3개 × 조건, 약 $0.5)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format json --setting-sources project --strict-mcp-config --model haiku --max-turns 40)

setup() {  # 배치 8개, b-005는 b-001에, b-008은 b-005에 의존
  python3 - <<'PY'
import json
bs=[{"id":f"b-{i:03d}","depends_on":[],"status":"pending"} for i in range(1,9)]
bs[4]["depends_on"]=["b-001"]; bs[7]["depends_on"]=["b-005"]
json.dump({"batches":bs},open("batches.json","w"),indent=1)
PY
  : > work.log
}

report() { python3 - "$1" <<'PY'
import json,collections,sys
log=[l.split() for l in open('work.log') if l.strip()]
c=collections.Counter(b for b,_ in log)
b=json.load(open('batches.json'))['batches']
ids=[x['id'] for x in b]
dup=[k for k,v in c.items() if v>1]; miss=[i for i in ids if i not in c]
order=[x for x,_ in log]
dep_viol=[d for d,p in (('b-005','b-001'),('b-008','b-005')) if d in order and (p not in order or order.index(p)>order.index(d))]
st=collections.Counter(x['status'] for x in b)
print(f"  {sys.argv[1]}: 처리 {len(log)}줄 / 중복 배치 {dup or '없음'} / 누락 {miss or '없음'} / 의존 순서 위반 {dep_viol or '없음'} / 최종 상태 {dict(st)}")
PY
}

expA() {
  local d; d=$(mktemp -d); cd "$d"; git init -q; setup; cp "$HERE/work.sh" .
  for w in w1 w2 w3; do
    "${CL[@]}" "너는 마이그레이션 워커 $w 다. batches.json에서 status가 pending이고 depends_on이 모두 done인 배치를 하나 골라 status를 in-progress, owner를 $w 로 바꿔 저장해 선점하라. 그다음 Bash로 ./work.sh <배치id> $w 를 실행하고, status를 done으로 바꿔 저장하라. 가져갈 배치가 없을 때까지 반복하라. 다른 워커도 동시에 같은 파일을 쓴다." \
      --allowedTools Read Edit Write "Bash(./work.sh *)" < /dev/null > "$RUNS/A-${REP:-1}-$w.json" 2>/dev/null &
  done; wait; report "(A) 직접 편집"; cp batches.json "$RUNS/A-${REP:-1}-batches.json"; cp work.log "$RUNS/A-${REP:-1}-work.log"
}

expB() {
  local d; d=$(mktemp -d); cd "$d"; git init -q; setup; cp "$HERE/claim.sh" "$HERE/work.sh" .
  for w in w1 w2 w3; do
    "${CL[@]}" "너는 마이그레이션 워커 $w 다. 반복하라: Bash로 ./claim.sh $w 를 실행해 배치 id를 받는다(NONE이면 끝). ./work.sh <배치id> $w 를 실행한다. ./claim.sh --done <배치id> 를 실행한다. batches.json은 직접 고치지 마라." \
      --allowedTools "Bash(./claim.sh *)" "Bash(./work.sh *)" < /dev/null > "$RUNS/B-${REP:-1}-$w.json" 2>/dev/null &
  done; wait; report "(B) 원자적 claim"; cp batches.json "$RUNS/B-${REP:-1}-batches.json"
}

case "${1:-}" in
  A|B) "exp$1" ;;
  all) (expA); (expB) ;;
  *) echo "사용: $0 A|B|all"; exit 1 ;;
esac
