import { relative } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_GLOBS = ["*.rs", "*.py", "*.ts", "*.tsx", "*.js", "*.jsx"];
const DEFAULT_PATTERN = [
  "^\\s*(pub\\s+)?(async\\s+)?fn\\s+[A-Za-z_][A-Za-z0-9_]*",
  "^\\s*(class|def)\\s+[A-Za-z_][A-Za-z0-9_]*",
  "^\\s*(export\\s+)?(async\\s+)?function\\s+[A-Za-z_$][A-Za-z0-9_$]*",
  "^\\s*export\\s+(class|interface|type|enum|const)\\s+[A-Za-z_$][A-Za-z0-9_$]*",
  "^\\s*(interface|type|enum)\\s+[A-Za-z_$][A-Za-z0-9_$]*",
].join("|");

function shellQuote(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "symbols",
    label: "Symbols",
    description: "Search code symbols using ripgrep. Use to find functions, classes, types, interfaces, and exported declarations by name or broad symbol pattern.",
    parameters: Type.Object({
      query: Type.Optional(Type.String({ description: "Optional symbol/name substring to filter matches." })),
      path: Type.Optional(Type.String({ description: "Directory or file to search. Defaults to cwd." })),
      pattern: Type.Optional(Type.String({ description: "Override rg regex. Defaults to common Rust/Python/TS/JS declarations." })),
      glob: Type.Optional(Type.Array(Type.String(), { description: "rg glob filters. Defaults to common Rust/Python/TS/JS source files." })),
      maxResults: Type.Optional(Type.Number({ description: "Maximum matching lines to return. Default 120.", default: 120 })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const max = Math.max(1, Math.min(Number(params.maxResults ?? 120), 500));
      const searchPath = params.path || ".";
      const pattern = params.pattern || DEFAULT_PATTERN;
      const globs = params.glob?.length ? params.glob : DEFAULT_GLOBS;

      const args = ["--line-number", "--column", "--no-heading", "--color", "never"];
      for (const glob of globs) args.push("-g", glob);
      args.push(pattern, searchPath);

      const result = await pi.exec("rg", args, { cwd: ctx.cwd });
      if (result.code !== 0 && !result.stdout.trim()) {
        return { content: [{ type: "text", text: result.stderr.trim() || "No symbols found." }], details: { matches: [] } };
      }

      const needle = (params.query || "").toLowerCase();
      const lines = result.stdout
        .split("\n")
        .filter(Boolean)
        .filter((line) => !needle || line.toLowerCase().includes(needle))
        .slice(0, max);

      const text = lines.length
        ? lines.join("\n")
        : `No symbols matched${needle ? ` query ${shellQuote(params.query!)}` : ""}.`;
      return { content: [{ type: "text", text }], details: { command: ["rg", ...args], cwd: ctx.cwd, count: lines.length } };
    },
  });
}
