import { useAuth, useHealth } from "@shop/api-client";

export const HomePage = () => {
  const health = useHealth();
  const { isAuthenticated, user } = useAuth();

  return (
    <main>
      <h1>Shop</h1>
      <p>API: {health.isLoading ? "checking…" : health.isError ? "down" : "up"}</p>
      <p>{isAuthenticated ? `Signed in as ${user?.mail ?? "…"}` : "Signed out"}</p>
    </main>
  );
};
