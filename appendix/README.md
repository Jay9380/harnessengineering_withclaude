# 부록 A~D — 설치 · 안티패턴 · 트러블슈팅 · 토큰 경제

부록은 본문을 실행 가능한 점검표로 압축한다. 여기서는 두 가지를 직접 돌린다.

| 파일 | 부록 | 하는 일 | 비용 |
|---|---|---|---|
| `cache_probe.sh` | D 원리 2 "KV 캐시는 10배 레버" | CLAUDE.md 첫 줄의 타임스탬프 하나가 캐시 적중률을 얼마나 깨는지 잰다 | haiku 6회, 약 $0.05 |
| `diagnose.sh` | B.3 10항목 / C.7 셀프 진단 | 프로젝트 하나에 5분 진단을 돌린다(읽기만 함) | 없음 |

## D — 타임스탬프 한 줄이 캐시를 깨는가

같은 폴더에서 `claude -p "hi"`를 3번. (A) CLAUDE.md 고정, (B) 실행할 때마다 CLAUDE.md 첫 줄에 현재 시각.

```text
== static                                                         == timestamp
run1  total=25940  cache_read=13796  creation=12134  hit=53%      run1  total=25960  cache_read=13796  creation=12154  hit=53%
run2  total=25940  cache_read=25930  creation=    0  hit=100%     run2  total=25960  cache_read=17808  creation= 8142  hit=69%
run3  total=25940  cache_read=25930  creation=    0  hit=100%     run3  total=25960  cache_read=17808  creation= 8142  hit=69%
```

- 고정이면 두 번째부터 **100% 캐시 적중**. 타임스탬프가 있으면 **69%에서 멈춘다** — 바뀐 바이트(CLAUDE.md 첫 줄) 앞까지만 재사용되고, 그 뒤 8,142토큰은 매번 다시 쓴다(cache_creation).
- 처음 13,796토큰은 두 조건 모두 첫 실행부터 적중했다 — CLAUDE.md보다 **앞**에 있는 부분(도구 정의 등)이다. 책의 "접두사(prefix) 기반"이 그대로 보인다.
- 단가로 환산하면(캐시 읽기 = 기본 입력의 0.1배, 이 환경의 1시간 캐시 쓰기 = 2배 — Anthropic 가격표 기준) 두 번째 실행의 입력 비용은
  고정 ≈ 25,930×0.1 = 2,593 단위, 타임스탬프 ≈ 17,808×0.1 + 8,142×2 = 18,065 단위 — **약 7배**. 바이트 하나의 값이다.
- 책의 처방 그대로: 가변 값(타임스탬프·세션 ID)은 접두사 뒤쪽으로, CLAUDE.md 편집은 드물게.

## B.3 — 5분 진단

```bash
./diagnose.sh <프로젝트 경로>
```

점검: CLAUDE.md 길이(≤150)·HTML 주석, 하위 CLAUDE.md, 프로젝트 MCP 서버 수(≤3), 에이전트마다 `tools`·`model` 명시, 스킬 레이아웃(디렉터리+SKILL.md), 훅 등록 여부, 최근 7일 같은 파일 30분 내 다중 커밋.

2장 예제(`ch02-quick-start/my-first-harness`)에 돌린 결과:

```text
[OK] CLAUDE.md 8줄 (≤150)              [OK] commit-msg-author.md tools·model 명시
[OK] CLAUDE.md HTML 주석 0              [OK] commit-msg-reviewer.md tools·model 명시
[OK] 프로젝트 MCP 서버 0개 (≤3)          [OK] 단일 .md 스킬 없음 (SKILL.md 1개)
[NO] 훅 없음 — 금지 규칙이 전부 설득(문장)에 의존
팀 중복 작업 15건
```

진단의 한계도 같이 적어 둔다.
- **'팀 중복 작업' 15건은 거짓 양성이다.** 예제 폴더는 이 실습 저장소 안에 있어서 git log가 저장소 전체를 본다 — 한 사람이 README를 30분 안에 여러 번 고친 것이 세어졌다. 이 지표는 여러 에이전트가 worktree로 일하는 팀 모드에서만 뜻이 있다.
- **`tools`가 있어도 `tools: '*'`이면 사실상 전부다.** 이 스크립트는 필드의 존재만 본다. 4장에서 본 것처럼 무엇이 들어 있는지(특히 Bash)를 사람이 봐야 한다.
- 진단은 출발점이다 — 부록 B의 말대로 "다섯 항목 중 셋 이상 실패하면 튜닝 대상".
