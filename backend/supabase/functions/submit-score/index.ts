import { corsHeaders, env, error, hmacHex, json, safeEqual, serviceRequest, sha256Hex } from "../_shared/http.ts";
import { respectsClues, validCompletedBoard } from "../_shared/sudoku.ts";

type Submission = {
  idempotency_key: string;
  challenge_id?: string;
  challenge_token?: string;
  source?: "online" | "offline";
  difficulty?: number;
  puzzle?: string;
  installation_id: string;
  display_name: string;
  duration_ms: number;
  mistakes: number;
  hints_used: number;
  final_board: string;
  move_count: number;
  move_digest?: string;
  client_version: string;
  platform: string;
  completed_at?: string;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PLATFORMS = new Set(["android", "ios", "macos", "windows", "linux", "web", "unknown"]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (request.method !== "POST") return error("METHOD_NOT_ALLOWED", "Only POST is supported.", 405);
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > 16_384) return error("PAYLOAD_TOO_LARGE", "The request is too large.", 413);
  try {
    const body = await request.json() as Submission;
    const validation = validateShape(body);
    if (validation) return validation;

    const duplicateResponse = await serviceRequest(`score_submissions?select=id,verified&idempotency_key=eq.${body.idempotency_key}&limit=1`);
    const duplicates = duplicateResponse.ok ? await duplicateResponse.json() : [];
    if (Array.isArray(duplicates) && duplicates.length > 0) {
      return json({ success: true, duplicate: true, verified: duplicates[0].verified });
    }

    const submissionSource = body.source === "offline" ? "offline" : "online";
    const challengeLookup = submissionSource === "offline"
      ? `ranked_challenges?select=id,difficulty,puzzle,solution_hash,rules_version,expires_at,available_from,active&difficulty=eq.${body.difficulty}&active=eq.true&available_from=lte.${encodeURIComponent(new Date().toISOString())}&order=available_from.desc&limit=1`
      : `ranked_challenges?select=id,difficulty,puzzle,solution_hash,rules_version,expires_at,available_from,active&id=eq.${body.challenge_id}&limit=1`;
    const challengeResponse = await serviceRequest(challengeLookup);
    if (!challengeResponse.ok) return error("SERVICE_UNAVAILABLE", "Score validation is temporarily unavailable.", 503);
    const challenges = await challengeResponse.json();
    if (!Array.isArray(challenges) || challenges.length !== 1) return error("INVALID_CHALLENGE", "The ranked challenge is invalid.", 404);
    const challenge = challenges[0];
    const now = Date.now();
    if (!challenge.active || now < Date.parse(challenge.available_from)) {
      return error("CHALLENGE_EXPIRED", "The submission window has closed.", 410);
    }
    if (submissionSource === "offline") {
      if (!body.puzzle || !respectsClues(body.puzzle, body.final_board) || !validCompletedBoard(body.final_board)) {
        return error("INVALID_SCORE", "The offline score does not contain a valid completed puzzle.");
      }
    } else {
      const tokenParts = (body.challenge_token ?? "").split(".");
      if (tokenParts.length !== 2 || Number(tokenParts[0]) !== challenge.rules_version) return error("INVALID_TOKEN", "The challenge token is invalid.", 401);
      const expectedToken = await hmacHex(`${challenge.id}|${challenge.rules_version}|${challenge.expires_at}`);
      if (!safeEqual(tokenParts[1], expectedToken)) return error("INVALID_TOKEN", "The challenge token is invalid.", 401);
      if (now > Date.parse(challenge.expires_at) + 86_400_000) return error("CHALLENGE_EXPIRED", "The submission window has closed.", 410);
      if (!respectsClues(challenge.puzzle, body.final_board) || !validCompletedBoard(body.final_board)) {
        return error("INVALID_SCORE", "The submitted board is invalid.");
      }
      const actualHash = await sha256Hex(body.final_board + env("SOLUTION_HASH_PEPPER"));
      if (!safeEqual(actualHash, challenge.solution_hash)) return error("INVALID_SCORE", "The submitted board is incorrect.");
    }

    const recentResponse = await serviceRequest(`score_submissions?select=id&installation_id=eq.${body.installation_id}&submitted_at=gte.${encodeURIComponent(new Date(now - 60_000).toISOString())}&limit=21`);
    const recent = recentResponse.ok ? await recentResponse.json() : [];
    if (Array.isArray(recent) && recent.length >= 20) return error("RATE_LIMITED", "Too many submissions. Try again later.", 429);

    const insertResponse = await serviceRequest("score_submissions?on_conflict=idempotency_key", {
      method: "POST",
      headers: { "Prefer": "resolution=ignore-duplicates,return=representation" },
      body: JSON.stringify({
        idempotency_key: body.idempotency_key,
        challenge_id: challenge.id,
        installation_id: body.installation_id,
        display_name: normalizeName(body.display_name),
        duration_ms: body.duration_ms,
        mistakes: body.mistakes,
        hints_used: body.hints_used,
        final_board: body.final_board,
        move_count: body.move_count,
        move_digest: body.move_digest || null,
        client_version: body.client_version,
        platform: body.platform,
        completed_at: body.completed_at || null,
        source: submissionSource,
        difficulty: submissionSource === "offline" ? body.difficulty : challenge.difficulty,
        puzzle: submissionSource === "offline" ? body.puzzle : challenge.puzzle,
        verified: true,
        rejection_reason: null,
      }),
    });
    if (!insertResponse.ok) return error("SUBMISSION_FAILED", "The score could not be stored.", 503);

    const leaderboardResponse = await serviceRequest(`challenge_leaderboard?select=rank,duration_ms,mistakes,move_count&challenge_id=eq.${challenge.id}&installation_id=eq.${body.installation_id}&limit=1`);
    const rankRows = leaderboardResponse.ok ? await leaderboardResponse.json() : [];
    return json({ success: true, duplicate: false, verified: true, personal_best: Array.isArray(rankRows) ? rankRows[0] ?? null : null });
  } catch {
    return error("INVALID_REQUEST", "The request could not be processed.", 400);
  }
});

function validateShape(body: Submission): Response | null {
  if (!body || !UUID.test(body.idempotency_key) || !UUID.test(body.installation_id)) return error("INVALID_REQUEST", "Required identifiers are invalid.");
  const source = body.source === "offline" ? "offline" : "online";
  if (source === "online" && (!body.challenge_id || !UUID.test(body.challenge_id))) return error("INVALID_REQUEST", "The challenge identifier is invalid.");
  if (source === "offline") {
    if (!Number.isInteger(body.difficulty) || Number(body.difficulty) < 1 || Number(body.difficulty) > 6) return error("INVALID_DIFFICULTY", "Difficulty must be between 1 and 6.");
    if (typeof body.puzzle !== "string" || !/^(?:[0-9]{81}|[0-9A-G]{256})$/.test(body.puzzle)) return error("INVALID_PUZZLE", "The offline puzzle is invalid.");
    const clueCount = Array.from(body.puzzle).filter((value) => value !== "0").length;
    if (clueCount < 16 || clueCount >= body.puzzle.length) return error("INVALID_PUZZLE", "The offline puzzle has an invalid clue count.");
  }
  const name = normalizeName(body.display_name ?? "");
  if (name.length < 1 || Array.from(name).length > 20 || /[\u0000-\u001f\u007f]/.test(name)) return error("INVALID_NAME", "The display name is invalid.");
  if (!Number.isInteger(body.duration_ms) || body.duration_ms < 10_000 || body.duration_ms > 86_400_000) return error("INVALID_DURATION", "The completion time is invalid.");
  if (!Number.isInteger(body.mistakes) || body.mistakes < 0 || body.mistakes > 999 || body.hints_used !== 0) return error("INVALID_SCORE", "Ranked scores cannot include hints.");
  if (!Number.isInteger(body.move_count) || body.move_count < 1 || body.move_count > 10_000 || body.duration_ms < body.move_count * 40) return error("IMPLAUSIBLE_SCORE", "The score timing is not plausible.");
  if (!PLATFORMS.has(body.platform) || typeof body.client_version !== "string" || body.client_version.length > 32) return error("INVALID_CLIENT", "Client metadata is invalid.");
  if (source === "online" && (typeof body.challenge_token !== "string" || body.challenge_token.length > 256 || !/^[1-9][0-9]*\.[0-9a-f]{64}$/.test(body.challenge_token))) return error("INVALID_TOKEN", "The challenge token is invalid.");
  if (!/^(?:[1-9]{81}|[1-9A-G]{256})$/.test(body.final_board)) return error("INVALID_SCORE", "The submitted board is invalid.");
  return null;
}

function normalizeName(value: string): string {
  return value.trim().replace(/\s+/g, " ");
}
