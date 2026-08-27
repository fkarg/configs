# Claudex Ansible Provisioning Design

## Goal

Provision `claudex` on `caeli` and `jolly` through the existing Ansible
configuration. `claudex` runs GPT-5.6 models inside the Claude Code harness,
while the ordinary `claude` and `codex` commands keep their existing models,
configuration, authentication, and behavior.

The setup also installs OpenAI's official Codex plugin for Claude Code. That
plugin remains available in ordinary Claude sessions and is independent of the
direct GPT-5.6 compatibility route used by `claudex`.

## Supported Scope

- Hosts: `caeli` (macOS) and `jolly` (NixOS).
- Provisioner: the existing `coding_agents` Ansible role on both hosts.
- Main `claudex` model: GPT-5.6 Sol.
- Tier mapping:
  - Claude Opus tier -> `gpt-5.6-sol`
  - Claude Sonnet tier -> `gpt-5.6-terra`
  - Claude Haiku tier -> `gpt-5.6-luna`
- Existing Claude Code configuration is shared with `claudex`, so installed
  agents, skills, hooks, MCP servers, permissions, instructions, and status-line
  behavior remain available.

Cloud Claude Code sessions and the Claude desktop application are out of scope.
The proxy-backed route applies only to the local `claudex` command.

## Architecture

`claudex` is a small launcher installed in `~/.local/bin`. It applies proxy and
model environment variables only to the Claude Code child process, then executes
the existing `claude` binary. It does not alter the calling shell.

The child Claude process talks to CLIProxyAPI on `127.0.0.1:8317` using the
Anthropic-compatible endpoint. CLIProxyAPI translates requests and routes the
Claude-recognized model aliases to GPT-5.6 through a per-host Codex OAuth login.
Using recognized Claude model identifiers preserves the full Claude Code harness
more reliably than launching Claude Code with an unknown `gpt-*` identifier.

CLIProxyAPI runs as a user-owned background process. The launcher starts it on
demand when necessary, using the same Ansible-managed command and configuration
on macOS and NixOS. This avoids separate launchd and systemd implementations and
keeps all host behavior inside the `coding_agents` role.

## Managed and Local State

The repository tracks:

- a non-secret CLIProxyAPI configuration template;
- the GPT-5.6 model-alias mapping;
- a POSIX-compatible `claudex` launcher;
- Ansible tasks for installing the appropriate CLIProxyAPI release for each host;
- Ansible tasks for rendering configuration and linking the launcher;
- Claude settings declaring the official OpenAI plugin marketplace and plugin;
- idempotent plugin installation tasks.

CLIProxyAPI will use one pinned upstream release on both hosts. Ansible selects
the checksum-verified `darwin_arm64` archive for `caeli` and `linux_amd64` archive
for `jolly`, extracts it beneath a versioned `~/.local/lib/cliproxyapi/`
directory, and links the executable into `~/.local/bin`. This avoids introducing
Homebrew-only service behavior or a parallel Nix package and makes the deployed
version explicit.

Each host keeps these values locally and untracked:

- CLIProxyAPI's Codex OAuth credentials;
- a generated local proxy client key;
- runtime PID and log files.

The proxy binds only to `127.0.0.1`, remote management is disabled, and its local
client key never enters repository files, Ansible output, chat, or commits.
Existing `~/.codex/auth.json` and Claude credentials are neither read nor copied.

## Installation and Authentication Flow

The `coding_agents` role will:

1. install CLIProxyAPI for the current OS and architecture;
2. create the local configuration and runtime directories;
3. generate a per-host client key only when one does not already exist;
4. render the proxy configuration without exposing the key in command output;
5. install `claudex` in `~/.local/bin`;
6. register and install the official OpenAI Codex plugin at Claude user scope;
7. leave OAuth login pending when the host has no CLIProxyAPI credential.

OAuth remains an explicit one-time interactive action on each host because it
opens a browser or device-code flow and creates secret host state. The role and
launcher will report the exact login command rather than failing obscurely.
Running the role again preserves both the generated client key and OAuth state.

## Behavior and Failure Handling

- `claude` never receives the proxy environment and continues to use Anthropic.
- `codex` continues to use its existing CLI configuration and login.
- `claudex` exits with a clear diagnostic when Claude Code, CLIProxyAPI, its
  configuration, or OAuth state is unavailable.
- If the proxy is not running, `claudex` starts it and waits briefly for its
  loopback health endpoint before launching Claude Code.
- Proxy logs remain local. The launcher and Ansible tasks must not print
  credential values.
- The launcher forwards all user arguments and Claude Code's exit status.
- The launcher does not default to `--dangerously-skip-permissions`; existing
  Claude permission behavior remains in force.
- CLIProxyAPI is a third-party compatibility layer, not an officially supported
  OpenAI or Anthropic integration. Version changes may require updating the
  pinned package, model mapping, or launcher.

## Verification

Automated coverage will pin the observable launcher contract:

- POSIX shell syntax;
- loopback-only proxy configuration;
- exact Sol/Terra/Luna alias mapping;
- child-scoped environment and argument forwarding;
- no tracked credential or fixed client key;
- idempotent Ansible tasks and supported OS/architecture selection.

Repository verification will include the existing coding-agent tests and
`scripts/ansible_smoketest.sh` where applicable. Live host verification will
check:

1. ordinary `claude` and `codex` still start normally;
2. CLIProxyAPI responds only on loopback;
3. `claudex` reaches GPT-5.6 Sol after per-host OAuth login;
4. a lightweight Claude subagent routes to the configured GPT-5.6 tier;
5. the official Codex plugin can perform a read-only review from ordinary
   Claude Code.

The implementation is complete only after the Ansible role has been applied and
the live checks have passed on both `caeli` and `jolly`, or an explicitly reported
host-access or interactive-login step remains for the user.
