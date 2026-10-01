import { getUserById } from "../src/api/users";

test("getUserById returns null for unknown id", async () => {
  expect(await getUserById("nope")).toBeNull();
});
