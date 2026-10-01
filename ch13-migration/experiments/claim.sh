#!/bin/bash
# 원자적 claim: mkdir는 원자적이므로 잠금으로 쓴다. 다음 pending 배치 id를 출력하고 in-progress로 바꾼다.
# 사용: ./claim.sh <worker>   → 배치 id 또는 NONE
# 완료: ./claim.sh --done <batch>
set -euo pipefail
cd "$(dirname "$0")"
until mkdir .lock 2>/dev/null; do sleep 0.1; done
trap 'rmdir .lock' EXIT
if [ "${1:-}" = --done ]; then
  python3 - "$2" <<'PY'
import json,sys
b=json.load(open('batches.json'))
for x in b['batches']:
    if x['id']==sys.argv[1]: x['status']='done'
json.dump(b,open('batches.json','w'),indent=1)
PY
  exit 0
fi
python3 - "$1" <<'PY'
import json,sys
b=json.load(open('batches.json'))
done={x['id'] for x in b['batches'] if x['status']=='done'}
for x in b['batches']:
    if x['status']=='pending' and all(d in done for d in x['depends_on']):
        x['status']='in-progress'; x['owner']=sys.argv[1]
        json.dump(b,open('batches.json','w'),indent=1); print(x['id']); break
else: print('NONE')
PY
