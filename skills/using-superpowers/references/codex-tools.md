## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Jujutsu Environment Detection

Skills that create workspaces or finish changes should inspect their environment with non-mutating Jujutsu commands before proceeding:

```bash
JJ_ROOT=$(jj --ignore-working-copy workspace root 2>/dev/null)
JJ_WORKSPACES=$(jj --ignore-working-copy workspace list 2>/dev/null)
JJ_STATUS=$(jj --ignore-working-copy status 2>/dev/null)
JJ_BOOKMARKS=$(jj --ignore-working-copy bookmark list -r @ 2>/dev/null)
```

- `JJ_ROOT` set means the current directory is a Jujutsu workspace.
- `JJ_WORKSPACES` lists every working copy attached to the repository; reuse the current managed workspace only after confirming it belongs to this task or session, otherwise follow the ownership check in the workspace skill.
- `JJ_STATUS` shows the current working-copy change without snapshotting it.
- `JJ_BOOKMARKS` lists bookmarks pointing to the working-copy change. Jujutsu has no active or current bookmark, so an empty result is valid and does not prevent creating changes.
- Use `$JJ_ROOT/.tmp`, with a local `.tmp` fallback only when no Jujutsu workspace is available.
- Each workspace has its own working-copy change. Jujutsu records working-copy files automatically, and bookmarks provide names for changes that need to be pushed or used for a PR.

See `using-git-worktrees` Step 0 and `finishing-a-development-branch` Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark or push operations in an externally managed workspace, set the working-copy change description with `jj describe`, then inform the user how to use the App's native controls:

- **"Create bookmark"** — names the change, then push and open the PR via App UI
- **"Hand off to local"** — transfers work to the user's local workspace

When operations are permitted, create a bookmark with `jj bookmark create` or deliberately move it to the intended revision with `jj bookmark move`, verify its target with `jj bookmark list`, push it with `jj git push --bookmark`, and use `gh` for the PR.

Before composing, editing, validating, or recommending a change description or PR description, inspect repository-local instructions from `$(jj workspace root)` and history with `jj log -r ::`. Apply only Go commit-message guidance that is compatible with those present repository standards; do not impose fixed syntax, examples, or templates. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
