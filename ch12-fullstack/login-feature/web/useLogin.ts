// 프런트 — 로그인 훅
export type User = { id: string; email: string; avatarUrl: string };

export async function useLogin(email: string, password: string): Promise<{ user: User; token: string }> {
  const r = await fetch("/api/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (r.status === 400) throw new Error("bad request");
  const data = await r.json();
  return { user: data.user, token: data.accessToken };
}

export function avatarInitial(user: User): string {
  return user.avatarUrl.split("/").pop()!.charAt(0).toUpperCase();
}

export async function recordAudit(userId: string): Promise<string> {
  const r = await fetch("/api/auth/audit", { method: "POST", body: JSON.stringify({ userId }) });
  const data = await r.json();
  return data.result.status; // 기록 결과 상태
}
