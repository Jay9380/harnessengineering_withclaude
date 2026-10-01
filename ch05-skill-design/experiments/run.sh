#!/bin/bash
# 5장 실험. 사용: ./run.sh A|B|C|all   (모두 haiku. A 24회·B 4회·C 6회, 전체 약 $1)
# 결과 요약은 각 실험 끝에 표로 출력되고, 원본 로그는 ch05-skill-design/runs/ 에 남는다.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku)
REPS=${REPS:-2}

# 로그에서 메인 세션의 Skill 호출 이름과 Read한 파일 이름을 뽑는다
calls() { python3 - "$1" <<'PY'
import json,sys,os
out=[]
for l in open(sys.argv[1]):
    try: d=json.loads(l)
    except: continue
    if d.get('type')=='assistant' and not d.get('parent_tool_use_id'):
        for c in d['message']['content']:
            if c.get('type')=='tool_use':
                i=c['input']
                if c['name']=='Skill': out.append('Skill:'+i.get('skill',''))
                elif c['name']=='Read': out.append('Read:'+os.path.basename(i.get('file_path','')))
print(' '.join(out) or '-')
PY
}

skill() {  # skill <이름> <description> — 본문은 공통
  mkdir -p ".claude/skills/$1"
  cat > ".claude/skills/$1/SKILL.md" <<MD
---
name: $1
description: "$2"
---
# 릴리스 노트 작성 절차 (이 프로젝트 전용)

1. \`git log --oneline <이전태그>..HEAD\`로 범위를 정한다 — 태그 사이만 봐야 이미 나간 변경을 다시 적지 않는다.
2. 커밋을 Added / Changed / Fixed 세 묶음으로 나눈다 — 사용자는 '무엇이 새로 생겼나'를 먼저 찾기 때문이다.
3. CHANGELOG.md 맨 위에 \`## [버전] - YYYY-MM-DD\` 형식으로 넣는다 — Keep a Changelog 형식을 따라야 도구가 파싱한다.
MD
}

# ---------- A. description이 호출을 결정하는가 ----------
expA() {
  local BAD="릴리스 관련 작업."
  local PUSHY="릴리스 노트·변경 로그(CHANGELOG) 작성, 버전별 변경 요약, 배포 공지 초안 작성을 수행. 사용자가 '릴리스 노트', '체인지로그', 'changelog', 'release notes', '배포 공지', '버전 정리'를 언급하면 이 스킬을 우선 사용할 것. 단순 커밋 메시지 작성이나 README 수정에는 쓰지 않는다."
  local P=("이번 버전 릴리스 노트 써줘" "changelog 정리해 줘" "v1.3 배포 공지 초안 만들어줘" "write release notes for 1.3" "README 오타 하나 고쳐줘" "지금 변경으로 커밋 메시지 써줘")
  local kind i r d
  for kind in bad pushy; do
    d=$(mktemp -d); cd "$d"; git init -q
    for i in 1 2 3; do echo "v$i" > f.txt; git add f.txt; git -c user.name=t -c user.email=t@t commit -qm "feat: change $i"; done
    git tag v1.2; echo "# Changelog" > CHANGELOG.md; echo "# demo" > README.md
    [ $kind = bad ] && skill release-notes "$BAD" || skill release-notes "$PUSHY"
    for i in "${!P[@]}"; do for r in $(seq 1 "$REPS"); do
      "${CL[@]}" "${P[$i]}" --max-turns 3 --allowedTools Skill Read < /dev/null > "$RUNS/A-$kind-$i-$r.jsonl" 2>&1 || true
      printf 'A %-6s %-36s rep%s  %s\n' "$kind" "${P[$i]}" "$r" "$(calls "$RUNS/A-$kind-$i-$r.jsonl")"
    done; done
  done
}

# ---------- B. description 길이 상한 — 한국어와 영어는 다르게 잘린다 ----------
# 같은 문장을 n번 반복한 description으로 (1) "hi" 한 번의 입력 토큰 (2) 트리거 단어로 호출되는지 를 본다.
ko() { echo "사용자가 'ZEBRA-SYNC'를 요청하면 이 스킬을 사용. $(python3 -c "print('이 스킬은 사내 데이터 동기화 절차를 다룬다. ' * $1)")"; }
en() { echo "Use this skill when the user asks for ZEBRA-SYNC. $(python3 -c "print('This skill covers the internal data sync procedure. ' * $1)")"; }
syncskill() {  # syncskill <description> : 새 저장소를 만들고 그 안으로 이동
  local d; d=$(mktemp -d); cd "$d"; git init -q; mkdir -p .claude/skills/data-sync
  printf -- '---\nname: data-sync\ndescription: "%s"\n---\n동기화 절차: "동기화 완료"라고 답한다.\n' "$1" > .claude/skills/data-sync/SKILL.md
}
first_tokens() { python3 - "$1" <<'PY'
import json,sys
for l in open(sys.argv[1]):
    d=json.loads(l)
    if d.get('type')=='assistant':
        u=d['message']['usage']; print(u['input_tokens']+u.get('cache_creation_input_tokens',0)+u.get('cache_read_input_tokens',0)); break
PY
}
expB() {
  local lang n desc
  for lang in ko en; do for n in 0 20 40 45 70; do
    desc=$($lang $n); ( syncskill "$desc"
    "${CL[@]}" "hi" < /dev/null > "$RUNS/B-tok-$lang-$n.jsonl" 2>&1 || true
    "${CL[@]}" "ZEBRA-SYNC 해줘" --max-turns 2 --allowedTools Skill Read < /dev/null > "$RUNS/B-trig-$lang-$n.jsonl" 2>&1 || true
    printf 'B %s n=%-3s %5d자 %5dB  hi입력토큰=%s  트리거="ZEBRA-SYNC 해줘" → %s\n' "$lang" "$n" "${#desc}" \
      "$(printf %s "$desc" | wc -c)" "$(first_tokens "$RUNS/B-tok-$lang-$n.jsonl")" "$(calls "$RUNS/B-trig-$lang-$n.jsonl")" )
  done; done
  # 대조: 목록 예산을 늘리면 사라졌던 한국어 description이 돌아오는가 (원인 = 개별 상한이 아니라 전체 목록 예산)
  desc=$(ko 70); ( syncskill "$desc"
  SLASH_COMMAND_TOOL_CHAR_BUDGET=50000 "${CL[@]}" "hi" < /dev/null > "$RUNS/B-tok-ko-70-budget.jsonl" 2>&1 || true
  SLASH_COMMAND_TOOL_CHAR_BUDGET=50000 "${CL[@]}" "ZEBRA-SYNC 해줘" --max-turns 2 --allowedTools Skill Read < /dev/null > "$RUNS/B-trig-ko-70-budget.jsonl" 2>&1 || true
  printf 'B ko n=70  + SLASH_COMMAND_TOOL_CHAR_BUDGET=50000  hi입력토큰=%s  트리거 → %s\n' \
    "$(first_tokens "$RUNS/B-tok-ko-70-budget.jsonl")" "$(calls "$RUNS/B-trig-ko-70-budget.jsonl")" )
}

# ---------- C. Progressive Disclosure — 필요한 references만 여는가 ----------
expC() {
  local P=("Q4 매출 합계 쿼리 짜줘" "창고별 재고 현황 쿼리 짜줘" "users 테이블 전체를 조회하는 SELECT 한 줄 써줘")
  local i r d
  d=$(mktemp -d); cp -R "$HERE/../sql-query/." "$d/"; cd "$d"; git init -q
  for i in "${!P[@]}"; do for r in $(seq 1 "$REPS"); do
    "${CL[@]}" "${P[$i]}" --max-turns 4 --allowedTools Skill Read < /dev/null > "$RUNS/C-$i-$r.jsonl" 2>&1 || true
    printf 'C %-40s rep%s  %s\n' "${P[$i]}" "$r" "$(calls "$RUNS/C-$i-$r.jsonl")"
  done; done
}

case "${1:-}" in
  A|B|C) "exp$1" ;;
  all) for x in A B C; do (exp$x); done ;;
  *) echo "사용: $0 A|B|C|all"; exit 1 ;;
esac
