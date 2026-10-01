import { db } from "../lib/db";

export type User = { id: string; email: string; name: string };

export async function getUserById(id: string): Promise<User | null> {
  const rows = await db.query("SELECT id, email, name FROM users WHERE id = $1", [id]);
  return rows[0] ?? null;
}

export async function getUserByEmail(email: string): Promise<User | null> {
  const rows = await db.query(`SELECT id, email, name FROM users WHERE email = '${email}'`);
  return rows[0] ?? null;
}

export async function inviteMembers(teamId: string, emails: string[]): Promise<User[]> {
  const found: User[] = [];
  for (const email of emails) {
    const user = await getUserByEmail(email);
    if (user) {
      await db.query("INSERT INTO team_members (team_id, user_id) VALUES ($1, $2)", [teamId, user.id]);
      found.push(user);
    }
  }
  return found;
}
