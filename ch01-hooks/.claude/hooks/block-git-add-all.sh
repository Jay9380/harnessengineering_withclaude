#!/bin/bash
# [1장] PreToolUse 훅 — "git add -A 금지"라는 문장 규칙을 기계적 강제로 옮긴 예.
#
# 프롬프트(CLAUDE.md·메모리)에 "git add -A 하지 마"라고 쓰는 것은 '설득'이다. 50번은 지켜져도 51번째는 모른다.
# 훅은 '강제'다. 클로드 코드는 Bash 도구를 실행하기 직전에 이 스크립트를 부르고,
# 이 스크립트가 exit 2로 끝나면 명령은 실행되지 않으며 stderr 내용이 차단 이유로 Claude에게 전달된다.
#
# 입력(stdin): {"tool_name":"Bash","tool_input":{"command":"..."}, ...}
# 출력: 차단이면 exit 2 + stderr, 통과면 exit 0
set -u
cmd=$(jq -r '.tool_input.command // ""')

# 명령을 하위 명령 단위로 쪼개 각각 검사한다.
#   "git status && git add -A" 처럼 이어 붙여서 빠져나가는 것을 막기 위해서다.
while IFS= read -r part; do
  # 1) 앞뒤 공백 제거
  # 2) git -C <dir> / git -c key=value 같은 '전역 옵션'을 지운다.
  #    공식 문서가 권한 규칙 우회 예로 든 형태(git -C . push …)를 같은 방식으로 정규화한다.
  norm=$(echo "$part" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
        | sed -E 's/^git( +-C +[^ ]+| +-c +[^ ]+)+ /git /')
  # git add 뒤 어딘가에 -A, --all, . 이 '독립된 인자'로 있으면 차단
  if echo "$norm" | grep -Eq '^git +add( +[^ ]+)* +(-A|--all|\.)( |$)'; then
    echo "차단: '$norm' — 경로를 명시해 git add <파일>로 올릴 것" >&2
    exit 2
  fi
done < <(echo "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
exit 0
