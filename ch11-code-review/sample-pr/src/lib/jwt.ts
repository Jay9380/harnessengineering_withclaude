import jwt from "jsonwebtoken";

const SECRET = process.env.JWT_SECRET!;

export function verifyRefresh(token: string): { sub: string } {
  return jwt.verify(token, SECRET) as { sub: string };
}

export function signAccess(userId: string): string {
  return jwt.sign({ sub: userId }, SECRET, { expiresIn: "15m" });
}
