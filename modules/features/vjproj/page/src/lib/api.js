import { createSignal } from "solid-js"

const STORED = "vjproj.token"

const claim = () => {
  const offered = (location.hash.slice(1) || new URLSearchParams(location.search).get("token") || "").trim()
  if (!offered) return localStorage.getItem(STORED) || ""
  localStorage.setItem(STORED, offered)
  history.replaceState(null, "", location.pathname)
  return offered
}

const [token, setToken] = createSignal(claim())

export { token }

export const forget = () => {
  localStorage.removeItem(STORED)
  setToken("")
}

export const ask = async (path, options = {}) => {
  const response = await fetch(path, {
    ...options,
    cache: "no-store",
    headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
  })
  if (response.status === 401) {
    forget()
    throw new Error("401")
  }
  if (!response.ok) throw new Error(String(response.status))
  return response.json()
}

export const send = (path, body = {}) => ask(path, { method: "POST", body: JSON.stringify(body) })

export const on = (machine, path) =>
  machine ? `/at/${encodeURIComponent(machine)}${path}` : path
