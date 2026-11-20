import assert from "node:assert/strict"
import test from "node:test"
import {
  abbreviatePath,
  buildStatusParts,
  fitStatusLine,
  formatCount,
  formatDuration,
  paceGlyph,
  shortenPath,
  usageSegment,
} from "./core.mjs"

test("formatCount uses compact suffixes", () => {
  assert.equal(formatCount(999), "999")
  assert.equal(formatCount(1200), "1.2k")
  assert.equal(formatCount(1250000), "1.3M")
})

test("formatDuration keeps statusline friendly units", () => {
  assert.equal(formatDuration(45), "45s")
  assert.equal(formatDuration(125), "2m")
  assert.equal(formatDuration(5000), "1h23m")
})

test("path helpers preserve home and trim toward basename", () => {
  assert.equal(abbreviatePath("/Users/felix/configs/coding-agents", "/Users/felix"), "~/configs/coding-agents")
  assert.equal(shortenPath("~/configs/coding-agents/configs/opencode/plugins", 24), "~/.../plugins")
})

test("usageSegment and paceGlyph represent remaining quota and burn direction", () => {
  const now = 1000
  assert.equal(usageSegment("5h", 25, now + 3600, now), "5h 75% 1h00m")
  assert.equal(paceGlyph(10, now + 3600, 18000, now), "^")
  assert.equal(paceGlyph(95, now + 3600, 18000, now), "v")
})

test("fitStatusLine drops lower-priority middle-right parts before truncating the anchor", () => {
  const parts = buildStatusParts({
    cwd: "/Users/felix/configs/coding-agents/configs/opencode/plugins",
    home: "/Users/felix",
    branch: "feature/statusline",
    model: "gpt-5.5 medium",
    tokens: { input: 1234, output: 567 },
    lines: { add: 12, del: 3 },
    context: "ctx 20%",
    state: "ready",
  })
  const line = fitStatusLine(parts, 55)
  assert.match(line, /plugins/)
  assert.match(line, /gpt-5\.5/)
  assert.ok(line.length <= 55)
})
