#!/bin/bash
# 3장: 같은 300줄을 CLAUDE.md / 에이전트 본문 / 스킬 본문에 넣었을 때 메인 세션의 입력 토큰이 얼마나 느는가.
# 사용: ./context_cost.sh      (haiku 7회 호출, 약 $0.1)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
# 계정에 붙은 claude.ai 커넥터(MCP)는 실행마다 'pending'/'connected'가 달라 도구 정의 분량이 흔들린다 → 끈다
export ENABLE_CLAUDEAI_MCP_SERVERS=false
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)

# 300줄짜리 '절차 지식' (내용은 반복이지만 길이는 실제 체크리스트 수준)
body() { for i in $(seq 1 "${1:-300}"); do echo "- 규칙 $i: 커밋 제목은 type(scope): 형식, 50자 이내, 명령형 현재 시제로 쓰고 본문은 72자에서 줄바꿈한다."; done; }

# 모델 호출마다 읽은 입력 토큰(input + cache_creation + cache_read)을 메인/서브로 나눠 출력
tokens() { python3 - "$1" <<'PY'
import json,sys
seen=[]; tools=None
for l in open(sys.argv[1]):
    d=json.loads(l)
    if d.get('subtype')=='init': tools=len(d['tools'])
    if d.get('type')=='assistant':
        u=d['message']['usage']; n=u['input_tokens']+u.get('cache_creation_input_tokens',0)+u.get('cache_read_input_tokens',0)
        who='sub' if d.get('parent_tool_use_id') else 'main'
        key=(who,d['message']['id'])
        if key not in [s[0] for s in seen]: seen.append((key,n))   # 한 응답이 여러 줄로 나뉘어 오므로 id로 묶음
print('tools=%s  ' % tools + '  '.join('%s:%d' % (k[0],n) for k,n in seen))
PY
}

run() {  # run <라벨> <프롬프트> [추가 인자...]
  local tag=$1 p=$2; shift 2
  "${CL[@]}" "$p" "$@" < /dev/null > "$RUNS/$tag.jsonl" 2>&1 || true
  printf '%-14s %s\n' "$tag" "$(tokens "$RUNS/$tag.jsonl")"
}

repo() { local d; d=$(mktemp -d); (cd "$d" && git init -q); echo "$d"; }
agent() { mkdir -p .claude/agents; { printf -- '---\nname: commit-rules\ndescription: "커밋 메시지 규칙을 적용하는 에이전트."\n---\n'; body "$1"; } > .claude/agents/commit-rules.md; }
skill() { mkdir -p .claude/skills/commit-rules; { printf -- '---\nname: commit-rules\ndescription: "커밋 메시지 규칙. 커밋 메시지를 쓸 때 사용."\n---\n'; body "$1"; } > .claude/skills/commit-rules/SKILL.md; }
ASK="commit-rules 의 규칙이 몇 개인지 숫자로만 답해."

cd "$(repo)" && run base "hi"
cd "$(repo)" && body 300 > CLAUDE.md && run claude-md "hi"
cd "$(repo)" && agent 1   && run agent-1line "hi"
cd "$(repo)" && agent 300 && run agent "hi" && run agent-called "commit-rules 에이전트에게 물어봐: $ASK" --allowedTools Agent
cd "$(repo)" && skill 1   && run skill-1line "hi"
cd "$(repo)" && skill 300 && run skill "hi" && run skill-called "commit-rules 스킬을 불러서 $ASK" --allowedTools Skill
