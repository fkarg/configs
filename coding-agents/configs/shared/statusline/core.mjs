export function visibleWidth(value) {
  return stripAnsi(String(value ?? "")).length
}

export function stripAnsi(value) {
  return String(value ?? "").replace(/\x1b\[[0-9;]*m/g, "")
}

export function formatCount(value) {
  const n = Number(value || 0)
  if (!Number.isFinite(n)) return "0"
  const abs = Math.abs(n)
  if (abs >= 1000000) return `${(n / 1000000).toFixed(1)}M`
  if (abs >= 1000) return `${(n / 1000).toFixed(1)}k`
  return `${Math.round(n)}`
}

export function formatDuration(seconds) {
  const s = Math.max(0, Math.floor(Number(seconds || 0)))
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  if (h > 0) return `${h}h${String(m).padStart(2, "0")}m`
  if (m > 0) return `${m}m`
  return `${s}s`
}

export function abbreviatePath(cwd, home = "") {
  const path = String(cwd || "")
  if (!path) return "?"
  if (home && path === home) return "~"
  if (home && path.startsWith(`${home}/`)) return `~${path.slice(home.length)}`
  return path
}

export function shortenPath(path, width) {
  const raw = String(path || "?")
  const max = Math.max(1, Number(width || 1))
  if (visibleWidth(raw) <= max) return raw
  const parts = raw.split("/")
  if (parts.length <= 1) return truncate(raw, max)
  const last = parts.at(-1) || raw
  const first = raw.startsWith("~") ? "~" : parts[0]
  const compact = `${first}/.../${last}`
  return visibleWidth(compact) <= max ? compact : truncate(last, max)
}

export function truncate(value, width, suffix = "...") {
  const raw = stripAnsi(value)
  const max = Math.max(0, Number(width || 0))
  if (raw.length <= max) return String(value ?? "")
  if (max <= suffix.length) return suffix.slice(0, max)
  return `${raw.slice(0, max - suffix.length)}${suffix}`
}

export function lineDelta(add = 0, del = 0) {
  return `+${Number(add || 0)}/-${Number(del || 0)}`
}

export function usageSegment(label, usedPercent, resetEpochSeconds, nowEpochSeconds = Date.now() / 1000) {
  if (usedPercent === undefined || usedPercent === null || usedPercent === "") return ""
  const used = Number(usedPercent)
  if (!Number.isFinite(used)) return ""
  const left = Math.max(0, Math.round(100 - used))
  const reset = Number(resetEpochSeconds)
  const resetText = Number.isFinite(reset) && reset > nowEpochSeconds ? ` ${formatDuration(reset - nowEpochSeconds)}` : ""
  return `${label} ${left}%${resetText}`
}

export function paceGlyph(usedPercent, resetEpochSeconds, windowSeconds, nowEpochSeconds = Date.now() / 1000) {
  const used = Number(usedPercent)
  const reset = Number(resetEpochSeconds)
  if (!Number.isFinite(used) || !Number.isFinite(reset)) return ""
  const remaining = Math.max(0, reset - nowEpochSeconds)
  const elapsed = Math.min(1, Math.max(0, (windowSeconds - remaining) / windowSeconds))
  const deviation = used - elapsed * 100
  if (deviation <= -2) return "^"
  if (deviation < 2) return "="
  return "v"
}

export function buildStatusParts(input) {
  const cwd = shortenPath(abbreviatePath(input.cwd, input.home), input.pathWidth ?? 42)
  const parts = [
    cwd,
    input.branch,
    input.model,
    input.tokens ? `${formatCount(input.tokens.input)}^/${formatCount(input.tokens.output)}v` : "",
    input.lines ? lineDelta(input.lines.add, input.lines.del) : "",
    input.fiveHour ? `${usageSegment("5h", input.fiveHour.used, input.fiveHour.reset, input.now)}${paceGlyph(input.fiveHour.used, input.fiveHour.reset, 18000, input.now)}` : "",
    input.weekly ? `${usageSegment("7d", input.weekly.used, input.weekly.reset, input.now)}${paceGlyph(input.weekly.used, input.weekly.reset, 604800, input.now)}` : "",
    input.context,
    input.state,
  ]
  return parts.filter((part) => part !== undefined && part !== null && String(part).length > 0).map(String)
}

export function fitStatusLine(parts, width, separator = " | ") {
  const max = Math.max(1, Number(width || 1))
  const list = parts.filter(Boolean).map(String)
  const anchored = new Set([0, Math.min(2, list.length - 1)])
  while (list.length > 1 && visibleWidth(list.join(separator)) > max) {
    let drop = -1
    for (let i = list.length - 2; i >= 1; i--) {
      if (!anchored.has(i)) {
        drop = i
        break
      }
    }
    if (drop === -1) drop = list.length - 1
    list.splice(drop, 1)
  }
  if (visibleWidth(list.join(separator)) <= max) return list.join(separator)
  return truncate(list.join(separator), max)
}
