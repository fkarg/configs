# Firefox browser control via MCP on NixOS

Implementation handoff, researched 2026-10-14. Scope: browser interactions in an
existing Firefox session on Wayland. This document installs nothing and chooses
no bridge transport on the user's behalf.

The useful subset of Codex Computer Use is tab discovery, page observations,
semantic actions, and screenshots. A Firefox WebExtension can supply these
without desktop capture, compositor control, XWayland, or synthetic OS input.
It will not reproduce all native browser input semantics.

## The interface observed from the agent side

In the current Codex session, the tool is `mcp__cua_repl.js`, accepting
`{ code, timeout_ms?, title? }`. It evaluates JavaScript in a persistent REPL.
The injected `cua` object provides discovery and bindings:

```ts
await cua.getState();
await cua.listBrowsers();
await cua.listTabs({ browser: browserId });
let tab = await cua.getTab(tabId, { browser: browserId });
let created = await cua.createBrowserTab(browserId, url, { visible: false });
```

Tab methods include `getAXState()`, `getScreenshot()`,
`getAXStateAndScreenshot()`, `click(elementIndex | [x, y], options?)`,
`scroll(target, direction, pages?)`, `drag(from, to)`, `setValue(index, value)`,
`selectText(index, text, options?)`, and
`performSecondaryAction(index, action)`. Browser text methods take an element
index or `null` before the text/key: `typeText(index, text)`,
`paste(index, text, options?)`, `pressKey(index, chord)`.
Navigation/lifecycle methods such as `goto`, `back`, `reload`, and `close` are
optional. DOM-only providers instead expose documented Playwright locators;
their native input wrappers throw. Provider documentation is returned on first
selection. Accessibility snapshots use transient element indices; a new
observation follows actions before the agent chooses its next target.

These are observed internal runtime interfaces, not a published compatibility
standard. A new MCP server does not need these names, a JavaScript evaluator,
or OpenAI's backend. Its tool results can carry text and images directly.
The public [OpenAI computer-use guide][openai] also supports custom UI tools.
Public [Linux app documentation][linux-app] currently excludes Computer Use,
although the runtime documentation describes Linux methods. This handoff does
not depend on enabling that backend.

## Components and the transport decision

```text
MCP client/agent
    ↕ MCP tools (stdio is sufficient locally)
local MCP server
    ↕ bridge transport: decide before implementation
Firefox extension background context
    ↕ extension messaging + scripting API
content scripts in explicitly selected tab/frame
```

Two viable bridge choices:

| Bridge | Advantage | Cost / constraint |
| --- | --- | --- |
| Extension connects to a loopback WebSocket listener in the MCP server | Fewer processes; MCP client starts server and extension reconnects | Authenticate connections, validate Origin, bind loopback only, and handle port discovery and multiple clients explicitly |
| Extension uses Firefox native messaging; native host connects to the MCP server over a user-private Unix socket | No browser-facing TCP listener; Firefox restricts native host access to the named extension | Extra adapter and packaging; Firefox launches the native host, while the MCP client launches the MCP server |

Do not directly connect MCP stdio to Firefox native messaging stdio. They have
different framing and launch ownership. [MCP stdio][mcp-transport] uses
newline-delimited JSON-RPC. [Firefox native messaging][native] uses UTF-8 JSON
with a native-endian 32-bit byte-length prefix. Firefox requires an explicit
extension ID, `nativeMessaging` permission, and a host manifest with
`allowed_extensions`. Use a long-lived `runtime.connectNative()` port for
bidirectional messages. Native-host-to-extension messages are limited to 1 MB;
screenshots normally travel in the opposite direction, but still enforce
application size bounds. Host disconnects must fail pending requests.

My assessment: both are reasonable for this scope. The real tradeoff is fewer
processes versus avoiding a local TCP authentication surface. Decide this with
the user before building; the rest of the proposed tool contract is independent
of it. Do not add both transports initially.

## Proposed minimum MCP tool surface

These are proposed names and semantics, not existing Codex tools. Prefer typed
tools over unrestricted page-JavaScript evaluation. Start with the following:

| Tool | Input | Result / behavior |
| --- | --- | --- |
| `browser_tabs` | none | Connected browser session and tab IDs, URL/title where permitted, active/discarded status |
| `browser_open` | `sessionId, url` | New tab ID; opening/activation policy must be explicit |
| `browser_navigate` | `sessionId, tabId, url` | Navigate the selected tab; invalidate previous observations |
| `browser_observe` | `sessionId, tabId, screenshot?` | DOM-derived semantic snapshot; optional MCP image |
| `browser_act` | `sessionId, tabId, observationId, action` | Execute one typed action, then return a fresh observation |

Initially allow `click`, `fill`, `select`, and `scroll` actions. Require an
element reference for semantic actions; allow viewport coordinates for a
best-effort DOM click. Add tab closure, keyboard chords, drag, uploads, or
batching only when actual workflows need them. A custom skill can teach the
agent the observe → act → inspect loop, without emulating a persistent REPL.

An illustrative call and textual result:

```json
{
  "sessionId": "firefox-connection-1",
  "tabId": 12,
  "observationId": "obs-7",
  "action": { "type": "fill", "ref": "e3", "text": "nixos" }
}
```

```text
session=firefox-connection-1 tab=12 observation=obs-8
url=https://example.org/search title=Search
viewport=1280x720 css-px scroll=0,0
e3 textbox name="Search" value="nixos"
e4 button name="Submit"
```

Use MCP `content` text blocks and image blocks (`type: "image"`, base64 `data`,
`mimeType`) rather than putting a data URL inside a textual response. Metadata
can also be returned as structured content. Mark action failures with
`isError: true` and a useful reason. [MCP tool results][mcp-tools]

## Observations and element references

Build a compact DOM-derived semantic view: visible headings/text, controls,
labels, roles, states, current non-sensitive values, and actionable references.
Explicitly call it a DOM snapshot; it is not Firefox's complete accessibility
tree. Define supported label/role extraction rather than claiming perfect
accessible-name computation. Do not dump the full HTML.

Keep references in content-script memory, scoped to a browser connection, tab,
frame, document, and observation. Never resolve an old reference by searching
for a similar label. Reject detached/replaced elements or changed documents and
ask for another observation. Navigation, extension reload, and bridge reconnect
invalidate references. A retained node is not proof the whole page is unchanged;
recheck visibility, enabled state, and relevant identity before acting.

Serialize mutations within each tab. A failed connection after dispatch can
leave execution uncertain: do not automatically replay a click or submission.
Observe the page first. Correlate bridge responses with request IDs and fail
requests when their browser session disappears; tab IDs alone are insufficient
across profiles/restarts. Start with one explicitly paired Firefox connection;
reject ambiguous additional connections rather than silently controlling one.

Use `browser.scripting.executeScript()` and/or content-script messaging.
Injection requires `scripting` plus the relevant host permission or a valid
`activeTab` grant. Frame targeting is explicit, and inaccessible frames must be
reported; Firefox can return partial results, so inspect frame-level errors.
Cross-origin frames need their own permitted injection; the top
document cannot simply traverse their DOM. Start with top-frame support if
necessary, but report omitted frames. [Script injection][scripting]

## Firefox capabilities and hard limits

- **Synthetic actions are semantic approximations.** `HTMLElement.click()` and
  dispatched input events are not trusted physical input. `dispatchEvent()`
  does not manufacture user activation. Dispatching a keyboard event is not a
  general text-entry or browser-shortcut mechanism. [Event trust][trusted]
- **Fill needs defined behavior.** Focus a supported input/textarea, use the
  native value setter where needed, and dispatch appropriate input/change
  events. Verify the resulting value and application reaction. Contenteditable
  and framework-controlled widgets need separate handling and fixture tests;
  do not promise every editor works.
- **Coordinates are DOM viewport coordinates.** Use hit testing and semantic
  actions; this does not reproduce hardware pointer events. Canvas, closed
  shadow roots, custom drag/drop, and games may remain unsupported.
- **Screenshots:** Firefox `tabs.captureTab(tabId)` targets a particular tab
  and requires `<all_urls>`. `activeTab` alone does not satisfy that API.
  Do not silently activate another tab as a screenshot fallback. Verify
  inactive/minimized/discarded tab capture on the actual Firefox build rather
  than assuming all states render identically. [Tab capture][capture]
- **Pixel mapping:** return screenshot dimensions, viewport dimensions,
  scroll offsets, and the applied crop/scale. Convert image coordinates to CSS
  viewport coordinates explicitly; browser zoom, device scale, and capture
  options make a raw 1:1 assumption unsafe.
- **Permission model:** `activeTab` follows a qualifying user gesture and is
  temporary; an MCP request does not itself grant it. Explicit site permissions
  are needed for unattended cross-site DOM access. The `tabs` permission grants
  access to sensitive tab metadata; it does not grant page injection. A broad
  capture grant still needs a narrower application-level tab/site policy.
  MV2 places host patterns in `permissions`; MV3 uses `host_permissions`.
  Check actual grants with `permissions.contains()` and handle revocation;
  declaring a host in the manifest is not a permanent authorization guarantee.
  [Permissions][permissions], [MV3 host grants][host-permissions]
- **Background lifecycle:** use Firefox-supported background scripts/event
  pages; do not copy Chrome's service-worker-only manifest. Firefox MV3 does
  not support persistent background pages; MV2 permits persistent pages.
  Choose the manifest version deliberately. Test idle connection behavior for
  the chosen transport; do not assume an open connection prevents suspension.
  Handle reconnects, rebuild volatile state, and register listeners
  appropriately for the chosen lifecycle.
  [Background manifest][background]
- **Boundaries:** Firefox browser chrome, native dialogs/file pickers, and
  restricted pages (including privileged `about:` pages, the PDF viewer, and
  protected Mozilla domains) are outside the ordinary content-script surface.
  Content scripts share the DOM but not ordinary page JavaScript scope. Report
  an unsupported target, not successful execution. Treat a screenshot capability
  separately from permission to inspect or modify a page. [Content scripts][content]

## Access boundaries

The extension operates inside the user's authenticated browser. Pair it
explicitly, authorize selected tabs/sites, and enforce authorization in the
extension as well as the bridge. Recheck the destination after navigation or
redirects. Do not expose extension message handlers to arbitrary page scripts.
Validate runtime message senders and target frames; do not relay bridge commands
through page-accessible `window.postMessage` handlers.
Keep password values out of snapshots; avoid persisting page text/screenshots
or form values in diagnostic logs. Page content is untrusted data, never
authority to execute bridge commands or expand access.

For the WebSocket option, a loopback address or Origin check alone is not
authentication. Pair using a secret; validate the actual extension Origin
rather than assuming it equals the manifest's Gecko extension ID. Test extension
CSP compatibility with the chosen WebSocket URL on the target Firefox build. For
the native-host option, use a user-private socket directory and permissions;
`allowed_extensions` authenticates the extension to Firefox's host launcher,
not arbitrary clients connecting to the MCP server's socket. Keep pairing
credentials out of this public repository.

## NixOS packaging handoff

For native messaging, package the executable and manifest together. The
manifest's `path` must point to an executable Nix-store wrapper with its runtime
dependencies, not assume Firefox inherits an interactive shell's PATH.
Linux's standard user host directory is
`~/.mozilla/native-messaging-hosts/`; do not infer it from the Firefox profile
directory or this repo's profile symlinks. [Native host manifests][manifests]

The current upstream NixOS Firefox module exposes
`programs.firefox.nativeMessagingHosts.packages`. Packages conventionally
provide `lib/mozilla/native-messaging-hosts/<host-name>.json`; inspect the target
machine's pinned nixpkgs Firefox wrapper before packaging, since the cited
upstream branch is moving. [NixOS Firefox module][nix-firefox]
The [Firefox package wrapper][nix-wrapper] shows the host manifest layout.

Illustrative wiring, with an intentionally undefined package placeholder:

```nix
programs.firefox = {
  enable = true;
  nativeMessagingHosts.packages = [ firefoxBrowserBridge ];
};
```

For a WebSocket-only bridge, native-host registration is unnecessary. Either
way, the MCP client starts the local server by an absolute executable path and
arguments; stdout is reserved for MCP, diagnostics go to stderr. Pin an MCP SDK
and use its supported protocol negotiation rather than copying framing code.

In this repo, shared Firefox module configuration belongs under
`nixos/shared/programs/`, with imports in the relevant machine configuration.
Follow [the module layout](nixos-module-layout.md). This handoff does not change
the existing package installation or introduce Home Manager.

Before relying on native-host registration, verify which Firefox wrapper the
machine actually launches (`command -v firefox`, then resolve its symlinks).
This repo lists plain `firefox` in `nixos/shared/packages/desktop-apps.nix` and
also enables `programs.firefox` in `nixos/machines/jolly.nix`. Check the resulting
configuration and desktop launcher; do not assume either entry wins or that
hosts configured for one wrapper appear in the other. Resolve any ambiguity as
part of implementation, not by changing package installation in this handoff.

For extension development, use temporary loading in `about:debugging`; it ends
at Firefox restart. Release/Beta Firefox requires Mozilla signing for durable
installation; unlisted signing supports self-distribution. Fix
`browser_specific_settings.gecko.id` and reuse that ID in the native host's
`allowed_extensions`. Developer Edition/Nightly/ESR have different unsigned
installation rules; choose the channel deliberately.
[Temporary installation][temporary], [Signing/distribution][signing]

## Small implementation sequence and acceptance checks

1. Choose one bridge transport. Connect a temporary extension and MCP server;
   return connection capabilities and tab inventory. Prove missing-browser and
   disconnect errors are understandable.
2. Implement top-frame observe/click/fill/select/scroll on a local fixture page.
   Cover a labeled form, navigation, a replaced DOM node, and a disabled control.
3. Test a real framework-controlled form and an iframe. Unsupported operations
   should fail explicitly. Verify stale references never hit a replacement.
4. Add screenshot results and test coordinate mapping under zoom/device scale,
   plus an inactive tab. Keep the human's active tab/focus unchanged where the
   chosen operation claims background operation.
5. Test a redirect to an unauthorized origin, a restricted page, reconnect with
   a pending mutation, and a second browser connection. No silent retargeting or
   mutation retries.
6. Package the server/extension for the target NixOS machine, run the same MCP
   workflow through the actual client, and verify Firefox restart behavior.

No automated tests were run for this document. These are implementation
acceptance criteria, not claims of verified Firefox behavior on these machines.

[openai]: https://developers.openai.com/api/docs/guides/tools-computer-use
[linux-app]: https://learn.chatgpt.com/docs/linux/linux-app
[native]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging
[manifests]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_manifests
[scripting]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/scripting/executeScript
[capture]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/captureTab
[permissions]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/permissions
[host-permissions]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/host_permissions
[background]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/background
[content]: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Content_scripts
[trusted]: https://developer.mozilla.org/en-US/docs/Web/API/Event/isTrusted
[temporary]: https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/
[signing]: https://extensionworkshop.com/documentation/publish/signing-and-distribution-overview/
[mcp-tools]: https://modelcontextprotocol.io/specification/2025-11-25/server/tools
[mcp-transport]: https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
[nix-firefox]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/firefox.nix
[nix-wrapper]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/browsers/firefox/wrapper.nix
