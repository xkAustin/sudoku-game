import { corsHeaders, env, error, hmacHex, json, serviceRequest } from "../_shared/http.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (request.method !== "GET") return error("METHOD_NOT_ALLOWED", "Only GET is supported.", 405);
  try {
    const url = new URL(request.url);
    const difficulty = Number(url.searchParams.get("difficulty") ?? "1");
    if (!Number.isInteger(difficulty) || difficulty < 1 || difficulty > 6) {
      return error("INVALID_DIFFICULTY", "Difficulty must be between 1 and 6.");
    }
    const now = new Date().toISOString();
    const path = `ranked_challenges?select=id,difficulty,puzzle,puzzle_version,rules_version,available_from,expires_at&difficulty=eq.${difficulty}&active=eq.true&available_from=lte.${encodeURIComponent(now)}&expires_at=gt.${encodeURIComponent(now)}&order=available_from.desc&limit=1`;
    const response = await serviceRequest(path);
    if (!response.ok) return error("SERVICE_UNAVAILABLE", "Ranked challenges are temporarily unavailable.", 503);
    const rows = await response.json();
    if (!Array.isArray(rows) || rows.length === 0) return error("NO_CHALLENGE", "No active challenge is available.", 404);
    const challenge = rows[0];
    const tokenPayload = `${challenge.id}|${challenge.rules_version}|${challenge.expires_at}`;
    const signature = await hmacHex(tokenPayload);
    return json({
      success: true,
      challenge_id: challenge.id,
      difficulty: challenge.difficulty,
      puzzle: challenge.puzzle,
      puzzle_version: challenge.puzzle_version,
      rules_version: challenge.rules_version,
      available_from: challenge.available_from,
      expires_at: challenge.expires_at,
      challenge_token: `${challenge.rules_version}.${signature}`,
      api_version: env("API_VERSION"),
    });
  } catch {
    return error("INTERNAL_ERROR", "The challenge could not be loaded.", 500);
  }
});
