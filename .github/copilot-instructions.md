# GitHub Copilot repository instructions

Follow the shared project context in [`AGENTS.md`](../AGENTS.md). It is the source of truth for the homelab goals, repository structure, cluster boundaries, secrets, and verification expectations.

For task-specific procedures, load the matching skill in `.claude/skills/`. These skills use the Agent Skills `SKILL.md` format: `debian-cloud-init` (provisioning Debian nodes and the jumpbox) `kubernetes-helm` (chart and profile conventions, deploying, troubleshooting), and `shell-scripts` (script structure, portability, and keeping scripts few).

Keep this file limited to Copilot-specific discovery notes. Put project-wide rules in `AGENTS.md` and detailed, occasional workflows in skills.
