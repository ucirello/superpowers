## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish bookmarks should detect their
environment with read-only `jj` commands before proceeding:

```bash
WORKSPACE_ROOT=$(jj workspace root 2>/dev/null)
WORKSPACES=$(jj workspace list)
CURRENT_CHANGE=$(jj log -r @ --no-graph -T 'change_id.short()')
BOOKMARKS=$(jj bookmark list -r @)
```

- `WORKSPACE_ROOT` set → inside a Jujutsu repository; compare `WORKSPACES`, the current root, and the task's intended isolation before deciding whether workspace creation can be skipped
- `BOOKMARKS` empty → no bookmark points to the current change; create one before `jj git push` and `gh pr create`

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark movement or `jj git push` in an
externally managed workspace, the agent describes the current change and informs
the user to use the App's native controls:

- **"Hand off to local"** — transfers the change to the user's local workspace

The agent can still run tests, inspect the current change, and suggest bookmark
names and GitHub PR descriptions. For change descriptions, repository-local
instructions and the message syntax and history visible in `git log` always win;
apply only compatible Go quality guidance. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
