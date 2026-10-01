#!/bin/bash
# 부록 D 원리 2: "접두사의 바이트 하나가 바뀌면 그 뒤의 캐시는 전부 무효화된다."
# 같은 폴더에서 "hi"를 3번. (A) CLAUDE.md 고정  (B) 매 실행 전 CLAUDE.md 첫 줄에 현재 시각을 씀.
# 지표: 첫 모델 호출의 cache_read / (input + cache_creation + cache_read)
# 사용: ./cache_probe.sh     (haiku 6회, 약 $0.05)
set -euo pipefail
export ENABLE_CLAUDEAI_MCP_SERVERS=false
rules() { for i in $(seq 1 120); do echo "- 규칙 $i: 커밋 제목은 type(scope): 형식, 50자 이내로 쓴다."; done; }
probe() { claude -p "hi" --output-format stream-json --verbose --setting-sources project --strict-mcp-config --model haiku < /dev/null 2>/dev/null | python3 -c "
import json,sys
for l in sys.stdin:
    d=json.loads(l)
    if d.get('type')=='assistant':
        u=d['message']['usage']; i,c,r=u['input_tokens'],u.get('cache_creation_input_tokens',0),u.get('cache_read_input_tokens',0)
        print(f'total={i+c+r:6d}  cache_read={r:6d}  cache_creation={c:6d}  hit={r/(i+c+r):.0%}'); break"; }
for mode in static timestamp; do
  d=$(mktemp -d); cd "$d"; git init -q
  echo "== $mode"
  for n in 1 2 3; do
    if [ $mode = timestamp ]; then { echo "# 오늘: $(date '+%Y-%m-%d %H:%M:%S.%N')"; rules; } > CLAUDE.md
    else { echo "# 프로젝트 규칙"; rules; } > CLAUDE.md; fi
    printf '  run%s  ' "$n"; probe
  done
done
