## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish changes should inspect their environment with read-only Jujutsu commands before proceeding:

```bash
ROOT=$(jj --ignore-working-copy workspace root)
jj --ignore-working-copy workspace list
jj --ignore-working-copy status
jj --ignore-working-copy bookmark list
```

- `ROOT` identifies the current workspace root; use `$(jj workspace root)/.tmp`, with a local `.tmp` fallback only when no Jujutsu workspace is available.
- Each workspace has its own working-copy change. Jujutsu records working-copy files automatically, and bookmarks provide names for changes that need to be pushed or used for a PR.

See `using-jj-workspaces` Step 0 and `finishing-a-development-branch` Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark or push operations in an externally managed workspace, set the working-copy change description with `jj describe`, then inform the user how to use the App's native controls:

- **"Create bookmark"** — names the change, then push and open the PR via App UI
- **"Hand off to local"** — transfers work to the user's local workspace

When operations are permitted, create or move a bookmark with `jj bookmark create` or `jj bookmark set`, push it with `jj git push --bookmark`, and use `gh` for the PR.

Before composing, editing, validating, or recommending a change description or PR description, inspect repository-local instructions from `$(jj workspace root)` and history with `jj log -r ::`. Apply only Go commit-message guidance that is compatible with those present repository standards; do not impose fixed syntax, examples, or templates. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
