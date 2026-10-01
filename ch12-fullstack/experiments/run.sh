#!/bin/bash
# 12장: 경계면 버그 6종을 (0) tsc --strict, (A) 한쪽씩 보는 리뷰어 2명, (B) 양쪽을 함께 읽는 boundary-verifier로.
# 사용: ./run.sh [반복수=2]     (tsc는 npm으로 임시 설치, claude는 haiku 약 $0.3)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
FX=$HERE/../login-feature
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false   # 계정 커넥터 배제 (3장 참고)
CL=(claude -p --output-format json --setting-sources project --strict-mcp-config --model haiku --allowedTools Read Grep Glob --max-turns 10)
REPS=${1:-2}
OUT='발견을 JSON 배열 하나로만 출력하라(앞뒤 설명 금지): [{"file":"…","claim":"한 문장"}]'

echo "== (0) tsc --strict"
T=$(mktemp -d); (cd "$T" && npm i -s typescript@5 >/dev/null 2>&1 && cp -R "$FX" lf && cd lf && ../node_modules/.bin/tsc -p . && echo "  오류 0 (exit 0)")

score() { python3 - "$@" <<'PY'
import json,re,sys
items=[]
for f in sys.argv[1:]:
    t=json.load(open(f)).get('result','')
    m=re.findall(r'\[\s*\{.*\}\s*\]', t, re.S)
    if m:
        try: items+=json.loads(m[-1])
        except Exception: pass
txt=' '.join((i.get('file','')+' '+i.get('claim','')) for i in items).lower()
B={'경로 /api/login↔/api/auth/login': bool(re.search(r'/api/login\b|route|경로|endpoint path|path mismatch',txt)),
   '케이스 access_token↔accessToken': 'access_token' in txt or ('accesstoken' in txt and ('case' in txt or '케이스' in txt or 'snake' in txt or 'camel' in txt)),
   '필드명 avatar_url↔avatarUrl':     'avatar_url' in txt,
   '옵셔널 null(avatar) 크래시':      bool(re.search(r'null',txt)) and 'avatar' in txt,
   '에러 401 미처리(400만 처리)':      '401' in txt,
   '202 비동기↔result.status':        bool(re.search(r'202|jobid|job id|result\.status',txt))}
print(f"  {sum(B.values())}/6  (항목 {len(items)}개) " + ' '.join(('O' if v else 'x')+k.split(' ')[0] for k,v in B.items()))
PY
}

for r in $(seq 1 "$REPS"); do
  # (A) 한쪽씩: 백엔드 리뷰어는 server/만, 프런트 리뷰어는 web/만 있는 폴더에서
  a=$(mktemp -d); cp -R "$FX/server" "$a/"; (cd "$a" && git init -q && "${CL[@]}" "server/ 의 로그인 API 코드를 리뷰해 버그와 위험을 찾아라. $OUT" < /dev/null > "$RUNS/A-back-$r.json" 2>/dev/null || true)
  b=$(mktemp -d); cp -R "$FX/web" "$b/";    (cd "$b" && git init -q && "${CL[@]}" "web/ 의 로그인 훅 코드를 리뷰해 버그와 위험을 찾아라. 서버는 POST /api/auth/login 과 POST /api/auth/audit 를 제공한다. $OUT" < /dev/null > "$RUNS/A-front-$r.json" 2>/dev/null || true)
  echo "== (A) 한쪽씩 2명 합산 rep$r"; score "$RUNS/A-back-$r.json" "$RUNS/A-front-$r.json"
  # (B) boundary-verifier: 두 파일을 함께
  c=$(mktemp -d); cp -R "$FX/." "$c/"; (cd "$c" && git init -q && "${CL[@]}" "boundary-verifier로서 server/auth.ts(생산자)와 web/useLogin.ts(소비자)를 동시에 열어 경계면을 대조하라. 7패턴: 응답 래핑, 케이스 변환, 경로↔링크, 상태 전이, API↔훅 매핑, 즉시 응답↔비동기 결과, 옵셔널 필드. $OUT" < /dev/null > "$RUNS/B-$r.json" 2>/dev/null || true)
  echo "== (B) boundary-verifier rep$r"; score "$RUNS/B-$r.json"
done
