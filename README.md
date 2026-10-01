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

진행에 따라 장이 추가된다.

## 출처와 라이선스

일부 파일은 책의 공식 예제 저장소 [revfactory/harness-engineering-with-cc](https://github.com/revfactory/harness-engineering-with-cc)
(Apache License 2.0)에서 가져와 수정했다. 가져온 파일과 수정 내용은 각 장 README의 **출처** 표에 적었고,
라이선스 전문은 [`tools/BOOK-EXAMPLES-LICENSE`](tools/BOOK-EXAMPLES-LICENSE), 고지는 [`NOTICE`](NOTICE)에 있다.
책 본문은 포함하지 않는다.
