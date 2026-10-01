// 백엔드 — 로그인 API (Express 스타일)
type Req = { body: any; params: any };
type Res = { status(n: number): Res; json(b: unknown): void };

type UserRow = { id: string; email: string; avatar_url: string | null; logged_in_at: string | null };
declare const db: { findUserByEmail(e: string): Promise<UserRow | null>; touchLogin(id: string): Promise<void> };
declare function checkPassword(u: UserRow, pw: string): Promise<boolean>;
declare function signAccess(id: string): string;
declare function enqueueAuditLog(id: string): Promise<string>; // 비동기 작업 id 반환

// POST /api/auth/login
export async function login(req: Req, res: Res) {
  const user = await db.findUserByEmail(req.body.email);
  if (!user || !(await checkPassword(user, req.body.password))) {
    return res.status(401).json({ error: { code: "INVALID_CREDENTIALS" } });
  }
  await db.touchLogin(user.id);
  return res.status(200).json({
    user: { id: user.id, email: user.email, avatar_url: user.avatar_url },
    access_token: signAccess(user.id),
  });
}

// POST /api/auth/audit — 감사 로그 기록 요청. 작업은 비동기로 처리되고 job id만 즉시 돌려준다.
export async function audit(req: Req, res: Res) {
  const jobId = await enqueueAuditLog(req.body.userId);
  return res.status(202).json({ jobId });
}

export const routes = {
  "POST /api/auth/login": login,
  "POST /api/auth/audit": audit,
};
