## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Jujutsu Environment Detection

Skills that create workspaces or finish changes should inspect their Jujutsu
environment before proceeding:

```bash
jj workspace root
jj workspace list
jj status
```

- The current workspace already has its own working-copy change; use `jj workspace add <destination> --name <name>` only when isolation is needed.
- Jujutsu snapshots working-copy files automatically. Do not stage them or treat a detached Git HEAD as an error in a colocated repository.

Use `jj describe` to set the current change description, `jj new` to start the next change, and `jj bookmark set <name> -r @` followed by `jj git push --bookmark <name>` when publishing through Git transport. GitHub operations continue to use `gh`.

When composing a change description or commit message, repository-local instructions and the message syntax visible in `git log` always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped body explaining what changed and why when needed. Do not impose a fixed prefix, type, scope, template, or example.

## Codex App Finishing

When the sandbox blocks bookmark or push operations in an externally managed
workspace, keep all work in the current Jujutsu change, give it an accurate
description, and inform the user to use the App's native controls:

- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests and output a suggested bookmark name, change
description, and GitHub PR description for the user to use locally.
