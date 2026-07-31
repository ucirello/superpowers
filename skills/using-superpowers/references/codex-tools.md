## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Jujutsu Environment Detection

Skills that create workspaces or finish changes should detect their
environment with non-mutating Jujutsu commands before proceeding:

```bash
JJ_ROOT=$(jj --ignore-working-copy workspace root 2>/dev/null)
JJ_WORKSPACES=$(jj --ignore-working-copy workspace list 2>/dev/null)
JJ_BOOKMARKS=$(jj --ignore-working-copy bookmark list -r @ 2>/dev/null)
```

- `JJ_ROOT` set means the current directory is a Jujutsu workspace.
- `JJ_WORKSPACES` lists every working copy attached to the repository; reuse the current managed workspace only after confirming it belongs to this task or session, otherwise follow the ownership check in the workspace skill.
- `JJ_BOOKMARKS` lists bookmarks pointing to the working-copy change. Jujutsu has no active or current bookmark, so an empty result is valid and does not prevent creating changes.

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark or push operations in an externally managed
workspace, the agent describes the working-copy change with `jj describe` and
informs the user to use the App's native controls:

- **"Create branch"** — names the branch, then push/open the PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests and output suggested branch names, change
descriptions, and PR descriptions for the user to copy. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
