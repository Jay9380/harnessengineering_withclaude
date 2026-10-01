# 2장 · 30분 Quick Start — 2인 팀(작성자·검토자)을 실제로 돌려 보기

책의 첫 하네스: `commit-message` 스킬이 **commit-msg-author**(초안) → **commit-msg-reviewer**(PASS/REDO) 순서로 두 에이전트를 부른다.
이 폴더는 그 파일을 그대로 두고, 책이 말한 동작이 **클로드 코드 2.1.286에서 정말 그런지** 5가지 실험으로 확인한다.

## 파일

| 경로 | 내용 |
|---|---|
| `my-first-harness/` | 책 예제 그대로 (CLAUDE.md, 에이전트 2개, 스킬 1개, 빈 `_workspace/`) |
| `experiments/run.sh` | 실험 1~5 재현. 임시 저장소를 만들어 그 안에서 `claude -p` 실행, 로그는 `runs/` |

```bash
cd ch02-quick-start/experiments
./run.sh 1        # 하나씩, 또는 ./run.sh all  (전체 약 $0.5, sonnet 위주)
```

공통 조건: `--setting-sources project`(개인 설정 배제), 허용 도구 `Bash(git *) Read Write Edit Skill Agent`, README.md 한 줄 추가를 스테이지한 상태.

## 출처

| 이 저장소 | 원본 (revfactory/harness-engineering-with-cc @ d81b72b) | 수정 |
|---|---|---|
| `my-first-harness/CLAUDE.md` | `ex-02-02-my-first-harness/CLAUDE.md` | 없음 |
| `my-first-harness/.claude/**` | `ex-02-02-my-first-harness/.claude/**` | 없음 (author 첫 줄 `--- `의 끝 공백도 그대로 — 실험 5 참고) |
| `my-first-harness/_workspace/` | 원본은 실행 결과 2개가 들어 있음 | 비우고 `.gitkeep`만 둠 |

## 실측 결과 (2026-10-01, 같은 스크립트로 2회 실행)

| 실험 | 확인한 것 | 1회차 | 2회차 |
|---|---|---|---|
| 1. 책 그대로 | 한 줄 요청 → 스킬 → author → reviewer | 다섯 단계 그대로, PASS, review-report.md **작성** ($0.147) | 다섯 단계 그대로, PASS, review-report.md **미작성** ($0.144) |
| 2. reviewer 파일 숨김 | 책: "워크플로가 끊긴다" | **끊기지 않음** — 메인이 직접 검토하고 "리뷰어 단계 생략"이라고 밝힘 | 같음 |
| 3. 틀린 초안 (`feat(auth): add login API…`) | reviewer가 잡는가 | REDO, 사유 정확. 파일 미작성 | 같음 |
| 4. 스킬 `allowed-tools` | 제한인가 | `Read`만 적은 스킬에서도 Bash 실행됨 → **제한 아님** | 같음 |
| 5. 프런트매터 첫 줄 | 깨지면? | `--- `(끝 공백)은 인식, `---`가 첫 줄이 아니면 **경고 없이 사라짐** | 같음 |

### 1. 검증 뒤에 산출물이 바뀐다 — 그리고 그 출처

두 번 다 사용자에게 간 메시지 끝에 `Co-Authored-By: Claude …`가 붙었다. 경로는 실행마다 달랐다.

- 1회차: author 초안에는 없었고, **reviewer가 PASS한 뒤** 메인이 덧붙였다 → 리뷰받지 않은 줄이 전달됨.
- 2회차: 메인이 author에게 위임하는 **프롬프트에 직접 넣었다** — `마지막 줄에 다음 attribution을 포함: Co-Authored-By: …`.
  메인(클로드 코드 자신)의 커밋 관례가 위임 지시문을 통해 팀 안으로 들어온 것이다.

> 에이전트 정의 파일만 보면 이 줄의 출처를 알 수 없다. **위임 프롬프트(메인이 쓴 brief)도 하네스의 일부**라서, 로그로 확인해야 한다.

### 2. 검증자가 없으면 '혼자 검토'로 강등된다

```text
TOOL main Agent  subagent_type=commit-msg-reviewer
  ERR  Agent type 'commit-msg-reviewer' not found. Available agents: …     ← 1회차
TOOL main Bash   ls .claude/agents                                         ← 2회차(호출 시도 없이 먼저 확인)
RESULT "리뷰어 단계 생략: … 위 형식 확인은 제가 직접 훑어본 결과이고, PASS/REDO 판정이나 review-report.md는 만들어지지 않았습니다."
```

멈추지 않고 대체 경로로 간다. 두 번 다 정직하게 밝혔지만, 밝힌다는 보장은 정의 어디에도 없다.

### 3. reviewer가 `review-report.md`를 쓰지 않는 이유 — 플랫폼 기본 지침과의 충돌

에이전트 정의의 입출력 프로토콜은 "출력. `_workspace/review-report.md`"이고, 2회차 실험 1에서는 메인의 위임 프롬프트도
"`_workspace/review-report.md` 에 저장하고 판정을 보고하라"였다. 그런데 reviewer의 답은:

```text
_workspace/review-report.md는 작성하지 않았습니다. 이번 실행 환경에 보고서 성격의 .md 파일을 쓰지 말고
결과를 직접 반환하라는 제약이 있어서입니다.
```

같은 실행에서 author는 `commit-draft.md`를 정상적으로 썼다. 즉 **'보고서 성격의 .md'만** 걸린다.
클로드 코드가 서브에이전트에 기본으로 주는 지침(결과는 파일이 아니라 응답으로 돌려준다)이 사용자의 에이전트 정의보다 우선한 것으로 보인다.
1회차에는 파일을 썼으니 **항상 그런 것도 아니다.**

> 실무 결론: "검증 결과를 파일로 남긴다"가 중요하다면 서브에이전트에게 맡기지 말고, **반환된 판정을 메인(또는 훅·스크립트)이 저장**하도록 설계한다.

### 4. 스킬 `allowed-tools`는 다른 도구를 막지 않는다

| 조건 | 스킬의 allowed-tools | 세션 전역 허용 | 결과 |
|---|---|---|---|
| A | `Read` | `Bash(touch*)` | **Bash 실행됨**, 파일 생성 |
| C (대조군) | `Read` | 없음 | 거부 — `touch in '…' needs approval` |
| B | `Bash(python3 *)` | 없음 | 거부 — `This command requires approval` |
| B0 | (필드 없음) | 없음 | 거부 |

A가 결론: 스킬 `allowed-tools`는 제한이 아니다(공식 문서도 '사전 승인'이라고 적는다). B와 B0이 같으므로 **헤드리스(`-p`)에서는 사전 승인 효과도 관찰되지 않았다.**
막고 싶으면 `disallowed-tools`, 권한 deny 규칙, 1장의 훅을 쓴다.

> 처음에는 `git log`로 시험했는데, 읽기 전용 명령은 원래 승인 없이 돌아서 대조군까지 통과했다 — 실험 무효. 승인이 필요한 명령으로 다시 설계했다.

### 5. 프런트매터가 깨지면 에이전트가 조용히 사라진다

```text
INIT agents: ['claude', 'clean-agent', 'Explore', 'general-purpose', 'Plan', 'spaced-agent', 'statusline-setup']
```

`file-c.md`(첫 줄 `xx`, 둘째 줄 `---`)의 `broken-agent`는 목록에 없고, 경고도 없다. 실험 2와 합치면:
**깨진 reviewer 파일 → 경고 없이 '혼자 검토'로 강등.**

## 덤으로 본 것

- `git diff --cached --quiet; echo $?` 는 `Contains simple_expansion`으로 거부됐다 — `$?` 같은 셸 확장이 있으면 `Bash(git *)` 허용과 무관하게 승인이 필요하다. 메인은 `&& … || …` 형태로 바꿔 다시 실행했다.
- author가 `mkdir -p … && printf … > 파일` 로 쓰려다 거부되자 Write 도구로 바꿨다 — 작업 폴더 안에 파일을 만드는 셸 명령은 별도 승인 대상이다.
