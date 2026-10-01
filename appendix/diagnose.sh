#!/bin/bash
# 부록 B.3 / C.7 — 자기 프로젝트에 돌려 보는 5분 진단 (과금 없음, 읽기만 함)
# 사용: ./diagnose.sh <프로젝트 경로>
set -uo pipefail
P=${1:-.}; cd "$P" || exit 1
ok(){ printf '  [%s] %s\n' "$1" "$2"; }
echo "== 문서 계층"
n=$( (wc -l < CLAUDE.md 2>/dev/null || echo 0) | tr -d " "); [ "$n" -le 150 ] && ok OK "CLAUDE.md ${n}줄 (≤150)" || ok NO "CLAUDE.md ${n}줄 (>150)"
c=$(grep -c '<!--' CLAUDE.md 2>/dev/null || true); [ "${c:-0}" -eq 0 ] && ok OK "CLAUDE.md HTML 주석 0" || ok CHECK "CLAUDE.md HTML 주석 ${c}개 — 규칙이 주석 안에 있지 않은지 확인 (표식이면 무해)"
echo "  하위 CLAUDE.md: $(find . -maxdepth 3 -name CLAUDE.md -not -path '*/node_modules/*' | wc -l | tr -d ' ')개"
echo "== 도구 구성"
sum(){ awk '{s+=$1} END{print s+0}'; }
m=$( { [ -f .mcp.json ] && jq '.mcpServers|keys|length' .mcp.json; [ -f .claude/settings.json ] && jq '(.mcpServers//{})|keys|length' .claude/settings.json; } 2>/dev/null | sum)
[ "${m:-0}" -le 3 ] && ok OK "프로젝트 MCP 서버 ${m:-0}개 (≤3)" || ok NO "프로젝트 MCP 서버 ${m}개 (>3)"
for f in .claude/agents/*.md; do [ -f "$f" ] || continue; head -1 "$f" | grep -q '^---' || continue
  t=$(grep -c '^tools:' "$f"); mo=$(grep -c '^model:' "$f")
  [ "$t" -gt 0 ] && [ "$mo" -gt 0 ] && ok OK "$(basename "$f") tools·model 명시" || ok NO "$(basename "$f") tools:${t} model:${mo} — 생략 시 전체 도구·부모 모델 상속"
done
echo "== 스킬"
s=$(find .claude/skills -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' '); echo "  SKILL.md ${s}개"
bad=$(find .claude/skills -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '); [ "$bad" -eq 0 ] && ok OK "단일 .md 스킬 없음" || ok NO "디렉터리 없이 놓인 스킬 .md ${bad}개 (로드되지 않음)"
echo "== 강제 장치"
h=$(for f in .claude/settings.json .claude/settings.local.json; do [ -f "$f" ] && jq '(.hooks//{})|keys|length' "$f"; done 2>/dev/null | sum)
[ "${h:-0}" -gt 0 ] && ok OK "훅 이벤트 ${h}개 등록" || ok NO "훅 없음 — 금지 규칙이 전부 설득(문장)에 의존"
echo "== 팀 중복 작업 (최근 7일, 같은 파일 30분 내 다른 커밋)"
git log --since="7 days ago" --name-only --pretty=format:"@%ct" 2>/dev/null | awk '/^@/{ts=substr($0,2);next} NF{print ts, $0}' | sort -k2,2 -k1,1n | awk '{if($2==p && $1-pt<1800) n++; p=$2; pt=$1} END{print "  "n+0"건"}'
