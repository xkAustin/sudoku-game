import { handleGetLeaderboard } from "../functions/get-leaderboard/handler.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) throw new Error(`Expected ${expected}, received ${actual}`);
}

Deno.test("loads Edge leaderboard entries and own rank concurrently", async () => {
  const originalFetch = globalThis.fetch;
  const originalUrl = Deno.env.get("SUPABASE_URL");
  const originalServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  let activeRequests = 0;
  let maximumConcurrentRequests = 0;
  let requestCount = 0;
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  globalThis.fetch = async (input: string | URL | Request) => {
    requestCount += 1;
    const url = String(input);
    if (url.includes("ranked_challenges")) {
      return Response.json([{ id: "00000000-0000-4000-8000-000000000010" }]);
    }
    activeRequests += 1;
    maximumConcurrentRequests = Math.max(maximumConcurrentRequests, activeRequests);
    await new Promise((resolve) => setTimeout(resolve, 5));
    activeRequests -= 1;
    if (url.includes("installation_id")) {
      return Response.json([{ rank: 7, display_name: "Player" }]);
    }
    return Response.json([{ rank: 1, display_name: "Leader" }]);
  };
  try {
    const response = await handleGetLeaderboard(new Request(
      "https://edge.test/get-leaderboard?difficulty=2&installation_id=00000000-0000-4000-8000-000000000001",
    ));
    const body = await response.json();
    assertEquals(response.status, 200);
    assertEquals(body.entries[0].rank, 1);
    assertEquals(body.self_entry.rank, 7);
    assertEquals(requestCount, 3);
    assertEquals(maximumConcurrentRequests, 2);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", originalUrl);
    if (originalServiceKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", originalServiceKey);
  }
});
