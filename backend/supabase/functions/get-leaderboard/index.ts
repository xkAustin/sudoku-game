import { corsHeaders, error, json, serviceRequest } from "../_shared/http.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (request.method !== "GET") return error("METHOD_NOT_ALLOWED", "Only GET is supported.", 405);
  try {
    const url = new URL(request.url);
    const difficulty = Number(url.searchParams.get("difficulty") ?? "1");
    const limit = Math.min(100, Math.max(1, Number(url.searchParams.get("limit") ?? "100")));
    const installationId = url.searchParams.get("installation_id")?.trim() ?? "";
    if (!Number.isInteger(difficulty) || difficulty < 1 || difficulty > 6) return error("INVALID_DIFFICULTY", "Difficulty must be between 1 and 6.");
    if (installationId && !UUID.test(installationId)) return error("INVALID_INSTALLATION", "The installation identifier is invalid.", 400);
    const challengeResponse = await serviceRequest(`ranked_challenges?select=id&difficulty=eq.${difficulty}&active=eq.true&available_from=lte.${encodeURIComponent(new Date().toISOString())}&order=available_from.desc&limit=1`);
    const challenges = challengeResponse.ok ? await challengeResponse.json() : [];
    if (!Array.isArray(challenges) || challenges.length === 0) return json({ success: true, entries: [] });
    const challengeId = challenges[0].id;
    const response = await serviceRequest(`challenge_leaderboard?select=rank,display_name,duration_ms,mistakes,move_count,submitted_at&challenge_id=eq.${challengeId}&order=rank.asc&limit=${limit}`);
    if (!response.ok) return error("SERVICE_UNAVAILABLE", "The leaderboard is temporarily unavailable.", 503);
    const entries = await response.json();
    let selfEntry = null;
    if (installationId) {
      const ownResponse = await serviceRequest(`challenge_leaderboard?select=rank,display_name,duration_ms,mistakes,move_count,submitted_at&challenge_id=eq.${challengeId}&installation_id=eq.${installationId}&limit=1`);
      const ownRows = ownResponse.ok ? await ownResponse.json() : [];
      selfEntry = Array.isArray(ownRows) ? ownRows[0] ?? null : null;
    }
    return json({ success: true, challenge_id: challengeId, entries, self_entry: selfEntry });
  } catch {
    return error("INTERNAL_ERROR", "The leaderboard could not be loaded.", 500);
  }
});
