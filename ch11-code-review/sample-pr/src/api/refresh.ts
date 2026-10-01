import type { Request, Response } from "express";
import { verifyRefresh, signAccess } from "../lib/jwt";
import { getUserById } from "./users";

// POST /api/auth/refresh
export async function refresh(req: Request, res: Response) {
  const token = req.body?.refreshToken;
  if (!token) return res.status(400).json({ error: "refreshToken required" });

  let payload: { sub: string };
  try {
    payload = verifyRefresh(token);
  } catch {
    return res.status(401).json({ error: "invalid token" });
  }

  const user = await getUserById(payload.sub);
  if (!user) return res.status(404).json({ error: "user not found" });

  return res.json({ accessToken: signAccess(user.id), user: { id: user.id, email: user.email, name: user.name } });
}
