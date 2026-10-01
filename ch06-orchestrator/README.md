# 6장 · 오케스트레이터 — 리더가 우체국이 되지 않으려면

책 6장은 팀 운영의 기본 도구로 `TeamCreate`·`TaskCreate`·`SendMessage`(+ `TeamDelete`)를 설명하고,
"리더를 거치지 않는 직접 메시지"가 리더 병목을 깬다고 말한다. 이 폴더는 **지금 클로드 코드(2.1.286)에 실제로 있는 도구**로 그 주장을 확인한다.

```bash
cd ch06-orchestrator/experiments
./run.sh 4      # 또는 1·2·3, all   (haiku, 전체 약 $0.5)
```

## 결과 요약

| 실험 | 확인한 것 | 결과 |
|---|---|---|
| 1 | 도구 목록 (실험 플래그 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 끄고/켜고) | 두 경우 같음: `SendMessage`, `TaskCreate/Get/List/Update/Stop`, `ListAgents`. **`TeamCreate`·`TeamDelete`는 없다** |
| 2 | 의존성 있는 작업 3개 | `TaskCreate{subject, description}` 3번 → `TaskUpdate{taskId:"3", addBlockedBy:["1","2"]}` → `#3 [pending] 테스트 리뷰 [blocked by #1, #2]`. 책의 `depends_on`·`assignee`는 실제 필드가 아니다. Task 도구는 ToolSearch로 불러와야 쓸 수 있는 지연 로딩 도구였다 |
| 3 | 이름으로 직접 메시지 (비밀값은 finder만 읽을 수 있음) | **실패.** 메인이 Agent 호출에 이름을 붙이지 않아 `"checker"`는 주소가 아니었다 → `No agent named 'checker' is reachable` ×4. 끝내 **메인이 비밀값을 직접 보냈다** — 지시("중계하지 마")를 어기고 우체국이 됨. $0.34 |
| 4 | 같은 일을 agentId로 | **성공.** 메인은 checker를 먼저 띄우고 spawn 결과의 agentId만 finder에게 넘김 → finder가 그 주소로 직접 전송 → checker가 값을 보고. 메인의 위임 프롬프트엔 값이 없음. $0.07 |

### 실험 3 — 실패가 가르쳐 준 것

```text
TOOL sub  SendMessage {"to": "checker", "message": "K-11992-31048"}
  → {"success":false,"message":"No agent named 'checker' is reachable.
     Check the spelling, or use the agent ID from a background agent's spawn result."}
...
TOOL main SendMessage {"to": "a81ec9eddd2509e84", "message": "K-11992-31048"}     ← 리더가 내용을 중계
```

- **에이전트 '종류'(subagent_type)는 주소가 아니다.** 같은 종류를 여러 번 띄울 수 있으니 당연하다. 주소는 spawn 결과의 agentId(또는 띄울 때 붙인 이름)다.
- SendMessage의 실패는 **도구 오류가 아니라 `success:false`가 담긴 정상 결과**로 돌아왔다. finder 정의에 "실패하면 그대로 보고"가 없으면 조용히 묻힐 수 있다 — 실험 4의 finder에는 그 줄을 넣었다.
- 직접 통신이 막히자 리더는 **스스로 중계자가 되는 쪽으로** 문제를 풀었다. 책의 안티패턴 ②(리더가 모든 결정을 독점)가 '선의의 문제 해결'로 생긴다는 것을 보여 준다.

### 실험 4 — 정석: 리더는 내용이 아니라 주소를 넘긴다

```text
TOOL main Agent  subagent_type=checker  run_in_background=true          → agentId a91875ce197694e37
TOOL main Agent  subagent_type=finder   prompt="checker의 agentId는 a91875ce197694e37 …"
TOOL sub  Read   secret.txt
TOOL sub  SendMessage {"to": "a91875ce197694e37", "message": "K-11800-4982"}
RESULT  "checker가 받은 메시지입니다: K-11800-4982"
```

checker는 메시지가 오기 전에 한 번 '완료' 상태가 됐는데, 도착한 메시지가 그를 다시 깨워 보고하게 했다(SendMessage 설명: 완료된 에이전트에게 보내면 그 transcript에서 재개된다).

## 책과 지금 도구의 대응

| 책 (6장) | Claude Code 2.1.286 (헤드리스에서 확인) |
|---|---|
| `TeamCreate({team_name, …})` + `AgentTool({team_name, name, …})` | 팀 생성 도구 없음. Agent(=Task) 도구로 서브에이전트를 띄우고, 주소는 agentId |
| `TaskCreate({tasks:[{title, assignee, depends_on}]})` | `TaskCreate{subject, description}` + `TaskUpdate{taskId, addBlockedBy}` |
| `SendMessage({to, summary, message})` | 같음. 단 `to`는 이름(팀원/ListAgents에 보이는 이름) 또는 agentId, `"main"`(백그라운드 서브에이전트→메인) |
| `TeamDelete()` + `shutdown_request` | 해당 도구 없음 (공식 문서: 실험적 에이전트 팀은 세션당 팀 하나가 자동 생성) |

> **저자 쪽 확인.** 책의 메타스킬 저장소 [revfactory/harness](https://github.com/revfactory/harness) CHANGELOG 2.0.0(2026-07-19):
> "v1의 전제였던 실험적 Agent Teams API가 현행 Claude Code에서 사라졌고 … `TeamCreate`/`TeamDelete`/`team_name` 전면 제거 —
> v1 오케스트레이터는 이 API를 호출하다 단일 에이전트 실행으로 조용히 퇴화하는 실질적 브로큰 상태였다."
> v2는 `Agent(name:)` + `SendMessage` + `TaskCreate/TaskUpdate`, `Workflow` 스크립트, 서브에이전트 위임의 세 실행 모드를 쓴다.

공식 문서상 '에이전트 팀(팀원끼리 직접 메시지)'은 실험 기능이고 `-p`(헤드리스)에서는 팀원이 없다. 그래서 이 폴더의 실험은 **서브에이전트 + SendMessage** 범위다. 책의 원리(리더는 주소와 구조만 주고 내용은 팀원끼리)는 이 범위에서도 그대로 확인된다.
