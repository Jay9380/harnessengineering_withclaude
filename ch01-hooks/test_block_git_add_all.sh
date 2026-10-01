#!/bin/bash
# [1장] 훅을 클로드 없이 시험한다. 훅은 stdin JSON만 받으므로 직접 넣어 볼 수 있다.
# 각 줄: 기대값(BLOCK|PASS) | 명령 | 설명
# "한계"로 표시한 줄은 이 훅이 못 막는다는 것을 '고정'해 두는 테스트다 — 훅도 완벽하지 않다.
cd "$(dirname "$0")"
HOOK=.claude/hooks/block-git-add-all.sh
fail=0
check() {
  local expect="$1" cmd="$2" note="$3"
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" | "$HOOK" 2>/dev/null
  local code=$?
  local got=PASS; [ $code -eq 2 ] && got=BLOCK
  local mark="ok  "; [ "$got" != "$expect" ] && mark="FAIL" && fail=1
  printf '%s %-5s %-34s %s\n' "$mark" "$got" "$cmd" "$note"
}
check BLOCK 'git add -A'                 '기본'
check BLOCK 'git add --all'              '긴 옵션'
check BLOCK 'git add .'                  '현재 디렉터리 전체'
check BLOCK 'git status && git add -A'   '복합 명령 분해'
check BLOCK 'git -C . add -A'            '전역 옵션 우회 (공식 문서의 우회 예와 같은 형태)'
check BLOCK 'cd x; git add -v .'         '옵션이 끼어도'
check PASS  'git add src/Main.java'      '경로 명시는 허용'
check PASS  'git add ./README.md'        '"./파일"은 "."이 아님'
check PASS  "echo 'git add -A is bad'"   '문자열 속 글자에 오탐하지 않음'
check PASS  "git commit -m 'add .'"      '커밋 메시지 속 "add ."'
check PASS  'git add -u'                 '추적 중인 파일만 — 새 임시 파일은 안 들어감'
check PASS  'bash -c "git add -A"'       '한계: bash -c 로 감싸면 못 막음'
check PASS  'git stage -A'               '한계: add의 별칭 stage'
check PASS  'git add :/'                 '한계: 저장소 루트 경로 표기'
exit $fail
