# Sandbox local-network policy

## Goal

Keep the Codex and Claude Code safeguards enabled while avoiding false blocks for deliberate local development and cross-model peer review.

## Codex

The tracked shared Codex configuration will retain its current public-domain proxy allowlist and enable `features.network_proxy.allow_local_binding = true`.

This permits local destinations dynamically, including loopback, private-network, link-local, and `/etc/hosts`-resolved names. SSH is explicitly out of scope: this setting governs Codex’s network proxy and must not be represented as an SSH policy.

The change will add a merge-config test that asserts the generated proxy policy includes the local-binding setting. Applying the `coding_agents` Ansible role will then validate a local target succeeds and a non-allowlisted public target remains denied.

## Claude Code

The generated Claude settings will add the narrowest supported Auto Mode permission for the intentional `gh issue view … | peer-review …` data flow. Default Auto Mode classifier protections remain unchanged.

The implementation will verify that the permission matches the compound pipeline. If the permission grammar cannot safely match it, the implementation will use a fixed-purpose local wrapper with an exact permission instead of a general shell exemption.

## Non-goals

- Permitting arbitrary public egress.
- Modifying SSH sandbox behavior.
- Disabling Auto Mode or removing its exfiltration protections.
