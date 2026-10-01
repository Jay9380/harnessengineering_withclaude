#!/bin/bash
# 2장 실험 1~5 재현. 각 실험은 임시 디렉터리에서 돌고, 로그(jsonl)는 ch02-quick-start/runs/ 에 남는다.
# 사용: ./run.sh 1|2|3|4|5|all      (실제 API 호출 = 과금. 전체 약 $0.6, sonnet 위주)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
HARNESS=$HERE/../my-first-harness
RUNS=$HERE/../runs; mkdir -p "$RUNS"
SUMM="python3 $HERE/../../tools/summarize_stream.py"
# --setting-sources project : 내 개인 설정(~/.claude)을 섞지 않는다
CL=(claude -p --output-format stream-json --verbose --setting-sources project)

# 책 예제를 복사하고, README.md 한 줄 추가를 스테이지한 깨끗한 저장소를 만든다
new_repo() {
  local d; d=$(mktemp -d)
  cp -R "$HARNESS"/. "$d"/ && rm -f "$d"/_workspace/.gitkeep
  (cd "$d" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "chore: init" \
     && echo "# my-first-harness" > README.md && git add README.md)
  echo "$d"
}

exp1() {  # 책 그대로: 자연어 한 줄로 author → reviewer 팀이 도는가
  local d; d=$(new_repo); cd "$d"
  "${CL[@]}" "지금 스테이지된 변경으로 커밋 메시지 만들어줘" --model sonnet \
    --allowedTools "Bash(git *)" Read Write Edit Skill Agent < /dev/null > "$RUNS/exp1.jsonl" 2>&1 || true
  $SUMM "$RUNS/exp1.jsonl"; echo "--- _workspace:"; ls _workspace; cat _workspace/*.md 2>/dev/null || true
}

exp2() {  # reviewer 정의 파일을 숨기면 워크플로가 '끊기는가'
  local d; d=$(new_repo); cd "$d"
  mv .claude/agents/commit-msg-reviewer.md .claude/agents/commit-msg-reviewer.md.bak
  "${CL[@]}" "지금 스테이지된 변경으로 커밋 메시지 만들어줘" --model sonnet \
    --allowedTools "Bash(git *)" Read Write Edit Skill Agent < /dev/null > "$RUNS/exp2.jsonl" 2>&1 || true
  $SUMM "$RUNS/exp2.jsonl"; echo "--- _workspace:"; ls _workspace
}

exp3() {  # diff와 맞지 않는 초안을 reviewer가 잡는가 (실패 경로)
  local d; d=$(new_repo); cd "$d"
  printf 'feat(auth): add login API and fix README typo\n\nAdd JWT login endpoint and correct a typo in README.\n' \
    > _workspace/commit-draft.md
  "${CL[@]}" "commit-msg-reviewer 에이전트로 _workspace/commit-draft.md 초안을 검토해줘" --model sonnet \
    --allowedTools "Bash(git *)" Read Write Edit Agent < /dev/null > "$RUNS/exp3.jsonl" 2>&1 || true
  $SUMM "$RUNS/exp3.jsonl"; echo "--- review-report.md:"; cat _workspace/review-report.md 2>/dev/null || echo "(파일 없음)"
}

skill() {  # skill <이름> <allowed-tools 줄 또는 빈 문자열> <실행할 명령>
  mkdir -p ".claude/skills/$1"
  { echo "---"; echo "name: $1"; echo "description: \"$1 실험. 사용자가 '$1'라고 하면 사용.\""
    [ -n "$2" ] && echo "allowed-tools: $2"
    echo "---"
    echo "cd 하지 말고 현재 작업 디렉터리에서 Bash 도구로 \`$3\` 를 실행하고 출력을 그대로 보여 준다. 거부되면 거부 메시지를 그대로 보여 준다."
  } > ".claude/skills/$1/SKILL.md"
}

exp4() {  # 스킬 allowed-tools는 '제한'인가 '사전 승인'인가
  local d; d=$(mktemp -d); cd "$d"; git init -q
  # 주의: git log 같은 읽기 전용 명령은 원래 승인 없이 돈다 → 승인이 필요한 명령(touch, python3)으로 시험
  skill probe-read "Read" "touch probe-ok.txt && ls probe-ok.txt"
  skill probe-py "Bash(python3 *)" 'python3 -c "print(6*7)"'
  skill probe-py-none "" 'python3 -c "print(6*7)"'
  run4() {  # run4 <라벨> <프롬프트> <모델> <전역 허용 도구...>
    local tag=$1 p=$2 m=$3; shift 3; rm -f probe-ok.txt
    "${CL[@]}" "$p" --model "$m" --allowedTools "$@" < /dev/null > "$RUNS/exp4-$tag.jsonl" 2>&1 || true
    echo "== $tag"; $SUMM "$RUNS/exp4-$tag.jsonl" | grep -E "TOOL main Bash|ERR|RESULT" || true
    [ -e probe-ok.txt ] && echo "  probe-ok.txt 생성됨" || true
  }
  run4 A  probe-read    haiku  Skill Read "Bash(touch*)" "Bash(ls*)"  # 스킬=Read만, 전역=touch 허용
  run4 C  probe-read    haiku  Skill Read                             # 대조군: 전역 허용 없음
  run4 B  probe-py      sonnet Skill Read                             # 스킬=Bash(python3 *), 전역 허용 없음
  run4 B0 probe-py-none sonnet Skill Read                             # 필드 없음, 전역 허용 없음
}

exp5() {  # 프런트매터 첫 줄이 조금 틀리면 에이전트가 인식되는가
  local d; d=$(mktemp -d); cd "$d"; git init -q; mkdir -p .claude/agents
  printf -- '--- \nname: spaced-agent\ndescription: "trailing space test"\n--- \n\nbody\n' > .claude/agents/file-a.md
  printf -- '---\nname: clean-agent\ndescription: "clean test"\n---\n\nbody\n' > .claude/agents/file-b.md
  printf -- 'xx\n---\nname: broken-agent\ndescription: "not first line"\n---\nbody\n' > .claude/agents/file-c.md
  "${CL[@]}" "hi" --model haiku < /dev/null > "$RUNS/exp5.jsonl" 2>/dev/null || true
  $SUMM "$RUNS/exp5.jsonl" | grep "INIT agents"   # broken-agent 가 목록에 없으면 재현
}

case "${1:-}" in
  1|2|3|4|5) "exp$1" ;;
  all) for i in 1 2 3 4 5; do echo "######## 실험 $i"; (exp$i); done ;;
  *) echo "사용: $0 1|2|3|4|5|all"; exit 1 ;;
esac
