# 하네스 엔지니어링 with 클로드 코드 — 장별 실습

『하네스 엔지니어링 with 클로드 코드』를 읽으며 **각 장의 주장을 실제 Claude Code로 돌려 보고 확인한 기록**이다.
책 예제를 그대로 옮기는 것보다 "정말 그렇게 동작하는가"를 측정해 남기는 데 무게를 둔다.

## 환경

| 항목 | 값 |
|---|---|
| Claude Code | 2.1.286 (헤드리스 `claude -p --output-format stream-json`) |
| 실험 모델 | 대부분 `haiku` (비용 절감), 필요한 곳만 다른 모델 — 각 장 README에 명시 |
| 도구 | `bash`, `jq`, `python3` |

실험은 **임시 디렉터리에서** 돌린다. 각 장의 `run.sh`는 작업 폴더를 새로 만들어 그 안에서만 `claude`를 실행하고,
결과 로그는 `runs/`에 남긴다(`.gitignore` 대상). 요약은 `tools/summarize_stream.py`로 본다.

```bash
python3 tools/summarize_stream.py runs/xxx.jsonl   # INIT(에이전트·스킬) / TOOL 호출 / ERR / RESULT(비용·턴)
```

> 헤드리스 실험은 실제 API를 호출한다(과금). 각 장 README에 실측 비용을 적어 두었다.

## 장별 목차

| 장 | 폴더 | 확인하는 것 |
|---|---|---|
| 1장 왜 하네스인가 | [`ch01-hooks`](ch01-hooks) | 설득(CLAUDE.md) 대신 강제(PreToolUse 훅) — `git add -A` 차단 훅과 그 한계 |
| 2장 30분 Quick Start | [`ch02-quick-start`](ch02-quick-start) | 책의 2인 팀을 그대로 돌려 보기 — 검증자 부재 시 강등, 보고서 파일 미작성의 원인, 스킬 allowed-tools, 깨진 프런트매터 |
| 3장 책임 분리 | [`ch03-responsibility`](ch03-responsibility) | 같은 300줄을 CLAUDE.md·에이전트·스킬에 넣었을 때의 컨텍스트 비용 실측 |
| 4장 에이전트 정의 | [`ch04-agent-definition`](ch04-agent-definition) | `tools`는 강제, 본문은 설득 — "읽기 전용" 에이전트가 Bash로 파일을 고친 실측, 서브에이전트 보고서 파일 차단 |
| 5장 스킬 설계 | [`ch05-skill-design`](ch05-skill-design) | description만 바꾼 호출률, 한국어 description이 목록 예산 초과로 통째로 사라지는 경계, references 조건부 로딩 |
| 6장 오케스트레이터 | [`ch06-orchestrator`](ch06-orchestrator) | 지금 도구로 본 팀 프리미티브 — TeamCreate 부재, addBlockedBy 의존성, 이름 대신 agentId로 해야 성립하는 직접 메시지 |
| 7장 메타스킬 | [`ch07-metaskill`](ch07-metaskill) | 실물 메타스킬(revfactory/harness v2.1.0)의 30초 점검과 should/should-NOT 호출 검증 |
| 8장 아키텍처 패턴 | [`ch08-patterns`](ch08-patterns) | 생성-검증 루프에 실제 claude를 넣고 MAX_RETRIES·에스컬레이트·검증자 변조 감시 |
| 9장 실행 모드 | [`ch09-execution-modes`](ch09-execution-modes) | 서브에이전트 병렬(29초) vs 순차(68초), 동시에 띄운 의존 서브가 낡은 결과를 전하는 암묵적 의존성 |
| 10장 등록과 진화 | [`ch10-registration`](ch10-registration) | CLAUDE.md 포인터 유무에 따른 스킬 호출(4/6 vs 6/6), HTML 주석 속 규칙의 소멸 |
| 11장 코드 리뷰 팀 | [`ch11-code-review`](ch11-code-review) | 버그 4종 PR을 1인 vs 3인 팀으로 실측 — 88줄에선 7/8 동률, 팀은 3~5배 비용에 폭이 넓음 |
| 12장 풀스택 팀 | [`ch12-fullstack`](ch12-fullstack) | 경계면 버그 6종 — tsc --strict 0개, 한쪽씩 보는 리뷰어 3/6(후한 채점), 양쪽을 함께 읽는 boundary-verifier 6/6 |
| 13장 마이그레이션 팀 | [`ch13-migration`](ch13-migration) | 워커 3명이 batches.json에서 동시에 claim — 직접 편집은 5회 중 2회 '버려진 선점'으로 누락, 원자적 claim 스크립트는 2/2 완료 |
| 14장 디버깅/RCA 팀 | [`ch14-debugging`](ch14-debugging) | 재현 게이트 없이 "고쳐줘"는 9회 중 2회 거짓 완료(버그 리포트를 고치고 완료 선언까지), reproduction.sh 게이트는 9/9 |
| 부록 A~D | [`appendix`](appendix) | CLAUDE.md 타임스탬프 한 줄로 캐시 적중 100%→69%(입력 비용 약 7배), 5분 진단 스크립트 |

1~14장과 부록까지 모두 실습했다.

## 출처와 라이선스

일부 파일은 책의 공식 예제 저장소 [revfactory/harness-engineering-with-cc](https://github.com/revfactory/harness-engineering-with-cc)
(Apache License 2.0)에서 가져와 수정했다. 가져온 파일과 수정 내용은 각 장 README의 **출처** 표에 적었고,
라이선스 전문은 [`tools/BOOK-EXAMPLES-LICENSE`](tools/BOOK-EXAMPLES-LICENSE), 고지는 [`NOTICE`](NOTICE)에 있다.
책 본문은 포함하지 않는다.
