# 1장 · 왜 하네스인가 — 설득을 강제로 바꾸기

> **프롬프트는 설득에 의존하고, 하네스는 기계적 강제에 의존한다.** (책 1장)
> CLAUDE.md나 메모리에 "git add -A 하지 마"라고 쓰는 것은 설득이다. 이 폴더는 같은 규칙을 **PreToolUse 훅**으로 강제한다.

클로드 코드 공식 문서(permissions)도 같은 말을 한다:
"권한 규칙은 모델이 아니라 Claude Code가 강제한다. 프롬프트나 CLAUDE.md의 지시는 Claude가 *하려는 것*을 바꿀 뿐, *허용하는 것*은 바꾸지 않는다."

## 파일

| 파일 | 내용 |
|---|---|
| `.claude/hooks/block-git-add-all.sh` | 훅 본체. 명령을 하위 명령으로 쪼개고 `git -C`/`-c` 전역 옵션을 정규화한 뒤 `git add -A / --all / .`이면 exit 2 |
| `.claude/settings.example.json` | 훅 등록 예시. 쓰려면 `.claude/settings.json`(팀 공유) 또는 `settings.local.json`(개인)으로 복사 |
| `test_block_git_add_all.sh` | 클로드 없이 훅만 시험 (14개 입력, 기대값 대조) |

## 실행

```bash
./ch01-hooks/test_block_git_add_all.sh      # 14개 모두 ok 이면 exit 0 (jq 필요)
```

## 실측 결과

**훅 단독 시험** — 차단 6 / 통과 5 / 한계 3 (모두 기대대로)

| 명령 | 결과 | 비고 |
|---|---|---|
| `git add -A`, `--all`, `.` | 차단 | |
| `git status && git add -A` | 차단 | 복합 명령 분해 |
| `git -C . add -A` | 차단 | 공식 문서가 권한 규칙 우회 예로 든 형태 |
| `cd x; git add -v .` | 차단 | |
| `git add src/Main.java`, `git add ./README.md` | 통과 | 경로 명시 |
| `echo 'git add -A is bad'`, `git commit -m 'add .'` | 통과 | 오탐 없음 |
| `git add -u` | 통과 | 추적 중인 파일만 |
| `bash -c "git add -A"`, `git stage -A`, `git add :/` | **통과 = 한계** | 이 훅이 못 막는 형태. 테스트로 고정해 둠 |

**클로드 코드 안에서** (2.1.286, 헤드리스, haiku, `--allowedTools "Bash(git *)"`, 훅 등록) — "git add -A를 실행해" 요청:

```text
TOOL main Bash {"command": "git add -A"}
  ERR  PreToolUse:Bash hook error: [...block-git-add-all.sh]: 차단: 'git add -A' — 경로를 명시해 git add <파일>로 올릴 것
git diff --cached --name-only  →  (아무것도 스테이징되지 않음)
```

`Bash(git *)` **허용 규칙이 있는데도 훅이 막았다.** 허용 규칙은 "확인 없이 실행해도 된다"일 뿐, 훅의 차단을 이기지 못한다.

## 배운 것

- 강제 층으로 옮길 1순위 규칙: **위반 시 되돌리기 어렵고 + 코드로 판정 가능한 것.**
- 훅도 완벽하지 않다(`bash -c`, `git stage`). 그래서 겹겹이 건다 — 훅 + 커밋 후 `git show --stat` 확인 + 리뷰.
- 권한 패턴(`Bash(git push *)` 같은 deny)은 `git -C . push`로 우회될 수 있다(공식 문서). 인자까지 봐야 하는 금지는 훅으로.
