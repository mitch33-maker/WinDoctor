type ApiSuccess<T> = { ok: true; data: T };
type ApiFailure = { ok: false; error?: { code?: string; message?: string } };

export function unwrapApi<T>(payload: T | ApiSuccess<T> | ApiFailure): T {
  if (payload && typeof payload === "object" && "ok" in payload) {
    if ((payload as ApiFailure).ok === false) {
      const failure = payload as ApiFailure;
      throw new Error(failure.error?.message || failure.error?.code || "API request failed");
    }
    if ("data" in payload) return (payload as ApiSuccess<T>).data;
  }
  return payload as T;
}

export async function readApiResponse<T>(res: Response, path: string): Promise<T> {
  const payload = await res.json().catch(() => null);
  if (!res.ok) {
    if (payload) return unwrapApi<T>(payload);
    throw new Error(`${res.status} ${path}`);
  }
  return unwrapApi<T>(payload);
}
