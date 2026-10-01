#!/bin/bash
# 9장 실험. 사용: ./run.sh 1|2|all   (haiku, 전체 약 $0.5)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
SUMM="python3 $HERE/../../tools/summarize_stream.py"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)

agents() {  # 실험용 에이전트 정의 3종
  mkdir -p .claude/agents
  cat > .claude/agents/sleeper.md <<'MD'
---
name: sleeper
description: "Bash로 sleep 15를 실행한 뒤 받은 번호를 답하는 실험 에이전트."
model: haiku
tools: Bash
---
Bash로 `sleep 15`를 정확히 한 번 실행하고, 끝나면 프롬프트로 받은 번호만 답한다.
MD
  cat > .claude/agents/producer.md <<'MD'
---
name: producer
description: "잠시 기다린 뒤 _workspace/a.txt에 값을 쓰는 실험 에이전트."
model: haiku
tools: Read, Write, Bash
---
1) Bash로 `sleep 20`을 실행한다. 2) secret.txt를 Read로 읽는다. 3) 그 값을 Write로 _workspace/a.txt에 쓴다. 끝나면 "작성함"이라고만 답한다.
MD
  cat > .claude/agents/consumer.md <<'MD'
---
name: consumer
description: "_workspace/a.txt를 읽어 그 값을 보고하는 실험 에이전트."
model: haiku
tools: Read
---
_workspace/a.txt를 Read로 읽고, 그 안의 값을 그대로 보고한다.
MD
}

timed() {  # timed <라벨> <프롬프트> <허용 도구...> — 벽시계 시간과 요약
  local tag=$1 p=$2; shift 2; local t0; t0=$(date +%s)
  "${CL[@]}" "$p" --max-turns 12 --allowedTools "$@" < /dev/null > "$RUNS/$tag.jsonl" 2>&1 || true
  echo "== $tag  벽시계 $(( $(date +%s) - t0 ))초"
  $SUMM "$RUNS/$tag.jsonl" | grep -E "^TOOL main Agent|ERR|^RESULT" | sed -E 's/"prompt": "[^"]{60}[^"]*"/"prompt": "…"/' | cut -c1-200
}

exp1() {  # 서브에이전트 = 순차? — 같은 일(각 15초)을 병렬/순차로
  local d
  d=$(mktemp -d); cd "$d"; git init -q; agents
  timed exp1-parallel "sleeper 에이전트 3개를 한 번의 응답에서 동시에 run_in_background=true로 띄워. 프롬프트는 각각 '1', '2', '3'. 셋 다 끝나면 받은 번호를 모아서 답해." Agent "Bash(sleep *)"
  d=$(mktemp -d); cd "$d"; git init -q; agents
  timed exp1-sequential "sleeper 에이전트를 하나씩 띄워. run_in_background는 쓰지 말고, 앞 에이전트가 끝난 뒤 다음을 띄워. 프롬프트는 차례로 '1', '2', '3'. 끝나면 받은 번호를 모아서 답해." Agent "Bash(sleep *)"
}

exp2() {  # 암묵적 의존성 — consumer는 producer의 출력이 필요한데, 둘을 동시에 띄우면?
  local d S
  for mode in parallel ordered; do
    d=$(mktemp -d); cd "$d"; git init -q; agents; S="V-$RANDOM-$RANDOM"; echo "$S" > secret.txt
    if [ $mode = parallel ]; then
      P="producer와 consumer 에이전트를 한 번의 응답에서 동시에 run_in_background=true로 띄워. 둘 다 끝나면 consumer가 보고한 값을 그대로 전해 줘. 너는 파일을 직접 읽지 마."
    else
      P="producer 에이전트를 먼저 띄우고 끝날 때까지 기다린 다음, consumer 에이전트를 띄워. consumer가 보고한 값을 그대로 전해 줘. 너는 파일을 직접 읽지 마."
    fi
    timed "exp2-$mode" "$P" Agent "Bash(sleep *)" Read Write
    python3 - "$RUNS/exp2-$mode.jsonl" "$S" <<'PY'
import json,sys
final=''.join(json.loads(l).get('result','') for l in open(sys.argv[1]) if l.startswith('{') and '"type":"result"' in l)
print('  비밀값', sys.argv[2], '→ 최종 답에 포함:', sys.argv[2] in final)
print('  최종 답(앞 200자):', final.replace('\n',' ')[:200])
PY
  done
}

case "${1:-}" in
  1|2) "exp$1" ;;
  all) for i in 1 2; do echo "######## 실험 $i"; (exp$i); done ;;
  *) echo "사용: $0 1|2|all"; exit 1 ;;
esac
