# PR #142 — JWT 리프레시 토큰 엔드포인트 추가

- `POST /api/auth/refresh` 추가: 리프레시 토큰을 검증하고 새 액세스 토큰과 사용자 정보를 돌려준다.
- 팀 초대 시 이메일 목록으로 사용자를 찾는 `inviteMembers` 추가.
- 프런트 `useUser` 훅이 새 응답을 쓰도록 변경.

변경 파일: src/api/refresh.ts, src/api/users.ts, src/lib/jwt.ts, src/hooks/useUser.ts
