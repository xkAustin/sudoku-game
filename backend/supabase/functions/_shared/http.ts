export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-version",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

export function error(code: string, message: string, status = 400): Response {
  return json({ success: false, error: { code, message } }, status);
}

export class RequestBodyTooLargeError extends Error {}
export class InvalidRequestBodyError extends Error {}

const SERVICE_REQUEST_TIMEOUT_MS = 8_000;

export async function readJsonBody(request: Request, maxBytes: number): Promise<unknown> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (!/^[0-9]+$/.test(contentLength)) throw new InvalidRequestBodyError("Invalid Content-Length");
    const declaredLength = Number(contentLength);
    if (!Number.isSafeInteger(declaredLength)) throw new InvalidRequestBodyError("Invalid Content-Length");
    if (declaredLength > maxBytes) throw new RequestBodyTooLargeError("Request body is too large");
  }
  if (request.body === null) throw new InvalidRequestBodyError("Request body is missing");

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      totalBytes += chunk.value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel("Request body is too large");
        throw new RequestBodyTooLargeError("Request body is too large");
      }
      chunks.push(chunk.value);
    }
  } finally {
    reader.releaseLock();
  }

  const bodyBytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bodyBytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const bodyText = new TextDecoder("utf-8", { fatal: true }).decode(bodyBytes);
    return JSON.parse(bodyText);
  } catch {
    throw new InvalidRequestBodyError("Request body is not valid JSON");
  }
}

export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server environment: ${name}`);
  return value;
}

export function serviceRequest(path: string, init: RequestInit = {}): Promise<Response> {
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${serviceKey}`);
  headers.set("apikey", serviceKey);
  headers.set("Content-Type", "application/json");
  const signal = init.signal ?? AbortSignal.timeout(SERVICE_REQUEST_TIMEOUT_MS);
  return fetch(`${env("SUPABASE_URL")}/rest/v1/${path}`, { ...init, headers, signal });
}

export async function hmacHex(message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(env("CHALLENGE_SIGNING_SECRET")),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return bytesToHex(new Uint8Array(signature));
}

export async function sha256Hex(message: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(message));
  return bytesToHex(new Uint8Array(digest));
}

export function safeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}
