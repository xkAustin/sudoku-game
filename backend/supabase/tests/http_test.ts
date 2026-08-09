import {
  InvalidRequestBodyError,
  readJsonBody,
  RequestBodyTooLargeError,
} from "../functions/_shared/http.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, received ${actual}`);
  }
}

async function assertRejectsWith(
  action: () => Promise<unknown>,
  expectedError: new (...args: never[]) => Error,
): Promise<void> {
  try {
    await action();
  } catch (caught) {
    if (caught instanceof expectedError) return;
    throw caught;
  }
  throw new Error(`Expected ${expectedError.name}`);
}

function requestWithChunks(
  chunks: string[],
  headers: HeadersInit = {},
): Request {
  const encoder = new TextEncoder();
  let index = 0;
  const body = new ReadableStream<Uint8Array>({
    pull(controller) {
      if (index >= chunks.length) {
        controller.close();
        return;
      }
      controller.enqueue(encoder.encode(chunks[index]));
      index += 1;
    },
  });
  return new Request("https://example.test/submit", {
    method: "POST",
    headers,
    body,
  });
}

Deno.test("reads valid lengthless JSON within the byte limit", async () => {
  const parsed = await readJsonBody(
    requestWithChunks(['{"ok":', "true}"]),
    16_384,
  ) as Record<string, unknown>;
  assertEquals(parsed.ok, true);
});

Deno.test("rejects a lengthless body after streamed bytes exceed the limit", async () => {
  await assertRejectsWith(
    () =>
      readJsonBody(
        requestWithChunks(['{"value":"', "x".repeat(16_384), '"}']),
        16_384,
      ),
    RequestBodyTooLargeError,
  );
});

Deno.test("does not trust a smaller declared Content-Length", async () => {
  await assertRejectsWith(
    () =>
      readJsonBody(
        requestWithChunks(["x".repeat(17)], { "content-length": "2" }),
        16,
      ),
    RequestBodyTooLargeError,
  );
});

Deno.test("rejects an invalid Content-Length", async () => {
  await assertRejectsWith(
    () =>
      readJsonBody(
        requestWithChunks(["{}"], { "content-length": "not-a-number" }),
        16_384,
      ),
    InvalidRequestBodyError,
  );
});
