export const API_URL = import.meta.env.VITE_API_URL || "http://localhost:4000";

export async function apiGet(path) {
  const r = await fetch(API_URL + path);
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

export async function apiPost(path, body) {
  const r = await fetch(API_URL + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {})
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}
