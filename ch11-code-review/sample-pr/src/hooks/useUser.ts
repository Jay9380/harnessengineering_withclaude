import { useEffect, useState } from "react";

type User = { id: string; email: string; name: string };

export function useUser(refreshToken: string) {
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    fetch("/api/auth/refresh", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken }),
    })
      .then((r) => r.json())
      .then((data: User[]) => setUser(data[0] ?? null));
  }, [refreshToken]);

  return user;
}
