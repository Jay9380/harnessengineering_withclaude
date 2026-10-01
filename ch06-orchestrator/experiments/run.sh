#!/bin/bash
# 6장 실험. 사용: ./run.sh 1|2|3|4|all   (haiku, 전체 약 $0.8). 로그는 ch06-orchestrator/runs/
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
SUMM="python3 $HERE/../../tools/summarize_stream.py"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)

exp1() {  # 책의 TeamCreate / TeamDelete는 지금 도구 목록에 있는가 (실험 플래그 켜고 끄고)
  local flag d
  for flag in off on; do
    d=$(mktemp -d); cd "$d"; git init -q
    if [ $flag = on ]; then export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; else unset CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS; fi
    "${CL[@]}" hi < /dev/null 2>/dev/null | head -1 | python3 -c "
import sys,json; t=json.loads(sys.stdin.readline())['tools']
print('AGENT_TEAMS=$flag', len(t), '개 중 팀 관련:', sorted(x for x in t if any(k in x for k in ('Team','Task','Send','Agent','List'))))"
  done
}

exp2() {  # TaskCreate로 의존성 있는 작업 3개 — 실제로 어떤 필드로 표현되나
  local d; d=$(mktemp -d); cd "$d"; git init -q
  "${CL[@]}" "작업 목록 도구로 작업 3개를 만들어: '보안 리뷰', '성능 리뷰', '테스트 리뷰'. 테스트 리뷰는 앞 두 작업이 끝나야 시작할 수 있게 의존성을 걸어. 그다음 작업 목록을 조회해서 그대로 보여 줘. 작업 자체는 수행하지 마." \
    --max-turns 8 --allowedTools TaskCreate TaskUpdate TaskList TaskGet < /dev/null > "$RUNS/exp2.jsonl" 2>&1 || true
  $SUMM "$RUNS/exp2.jsonl" | grep -v INIT | cut -c1-260
}

exp3() {  # 리더를 거치지 않는 직접 메시지 — 비밀값은 finder만 읽을 수 있다
  local d; d=$(mktemp -d); cd "$d"; git init -q; mkdir -p .claude/agents
  local SECRET="K-$RANDOM-$RANDOM"; echo "$SECRET" > secret.txt
  cat > .claude/agents/finder.md <<'MD'
---
name: finder
description: "secret.txt를 읽어 checker에게 직접 전달하는 실험 에이전트."
model: haiku
tools: Read, SendMessage
---
secret.txt를 Read로 읽고, 그 값을 SendMessage로 checker에게 보낸다(to: "checker"). 메인에게는 "전달함"이라고만 답하고 값은 말하지 않는다.
MD
  cat > .claude/agents/checker.md <<'MD'
---
name: checker
description: "finder가 보낸 메시지를 받아 그 값을 보고하는 실험 에이전트."
model: haiku
tools: SendMessage
---
finder에게서 메시지가 올 때까지 기다렸다가, 받은 값을 그대로 최종 답으로 보고한다. 파일은 읽지 않는다(Read 도구가 없다).
MD
  "${CL[@]}" "checker 에이전트와 finder 에이전트를 이 순서로 각각 이름을 붙여(name: checker, name: finder) 백그라운드로 띄워. 너는 secret.txt를 읽지 말고 값을 중계하지도 마. 둘이 끝나면 checker가 보고한 값을 그대로 전해 줘." \
    --max-turns 12 --allowedTools Agent SendMessage < /dev/null > "$RUNS/exp3.jsonl" 2>&1 || true
  $SUMM "$RUNS/exp3.jsonl" | grep -v INIT | cut -c1-240
  echo "--- 비밀값: $SECRET"
  python3 - "$RUNS/exp3.jsonl" "$SECRET" <<'PY'
import json,sys
f,sec=sys.argv[1],sys.argv[2]
main_prompts=[];main_read=False;sub_send=[];final=''
for l in open(f):
    try: d=json.loads(l)
    except: continue
    if d.get('type')=='assistant':
        for c in d['message']['content']:
            if c.get('type')!='tool_use': continue
            if not d.get('parent_tool_use_id'):
                if c['name'] in ('Agent','Task'): main_prompts.append(c['input'].get('prompt',''))
                if c['name']=='Read': main_read=True
            elif c['name']=='SendMessage': sub_send.append(c['input'].get('to'))
    if d.get('type')=='result': final+=d.get('result','')
print('메인이 secret.txt를 읽음:', main_read)
print('메인의 위임 프롬프트에 비밀값 포함:', any(sec in p for p in main_prompts))
print('서브에이전트의 SendMessage 수신자:', sub_send)
print('최종 답에 비밀값 포함:', sec in final)
PY
}

exp4() {  # 실험 3의 정석판 — 메인은 '내용'이 아니라 '주소(agentId)'만 넘긴다
  local d; d=$(mktemp -d); cd "$d"; git init -q; mkdir -p .claude/agents
  local SECRET="K-$RANDOM-$RANDOM"; echo "$SECRET" > secret.txt
  cat > .claude/agents/finder.md <<'MD'
---
name: finder
description: "secret.txt를 읽어 지정된 agentId로 직접 보내는 실험 에이전트."
model: haiku
tools: Read, SendMessage
---
secret.txt를 Read로 읽고, 프롬프트로 받은 checker의 agentId를 SendMessage의 to에 넣어 그 값을 보낸다.
SendMessage 결과가 success:false면 그 오류를 그대로 메인에게 보고한다. 성공하면 "전달함"이라고만 답하고 값은 말하지 않는다.
MD
  cat > .claude/agents/checker.md <<'MD'
---
name: checker
description: "다른 에이전트가 보낸 메시지를 받아 그 값을 보고하는 실험 에이전트."
model: haiku
tools: SendMessage
---
메시지가 도착할 때까지 기다렸다가(메시지는 자동으로 전달된다), 받은 값을 그대로 최종 답으로 보고한다. 파일은 읽지 않는다.
MD
  "${CL[@]}" "1) checker 에이전트를 백그라운드로 띄워. 2) 그 spawn 결과에 나온 agentId를 확인해. 3) finder 에이전트를 띄우면서 프롬프트에 'checker의 agentId는 <그 값>'이라고 알려 줘. 너는 secret.txt를 읽지 말고, 어떤 값도 직접 보내거나 중계하지 마. 4) checker가 끝나면 checker가 보고한 값을 그대로 전해 줘." \
    --max-turns 12 --allowedTools Agent < /dev/null > "$RUNS/exp4.jsonl" 2>&1 || true
  $SUMM "$RUNS/exp4.jsonl" | grep -v INIT | cut -c1-240
  echo "--- 비밀값: $SECRET  /  최종 답에 포함: $(grep -q "$SECRET" <(python3 -c "
import json,sys
for l in open('$RUNS/exp4.jsonl'):
    try: d=json.loads(l)
    except: continue
    if d.get('type')=='result': print(d.get('result',''))") && echo 예 || echo 아니오)"
}

case "${1:-}" in
  1|2|3|4) "exp$1" ;;
  all) for i in 1 2 3 4; do echo "######## 실험 $i"; (exp$i); done ;;
  *) echo "사용: $0 1|2|3|4|all"; exit 1 ;;
esac
