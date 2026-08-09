## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## JJ Environment Detection

Skills that create workspaces or finish changes should inspect their JJ
environment before proceeding:

```bash
JJ_ROOT=$(jj workspace root 2>/dev/null) || JJ_ROOT=
WORKSPACES=$(jj workspace list 2>/dev/null) || WORKSPACES=
BOOKMARKS=$(jj bookmark list -r @ 2>/dev/null) || BOOKMARKS=
```

- `JJ_ROOT` non-empty means the current directory is already in a JJ workspace; use `jj workspace list` to inspect sibling workspaces before adding one.
- `BOOKMARKS` empty means no bookmark points to `@`. This is normal in JJ; create or move a bookmark before pushing for a named GitHub branch.

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

Describe the working-copy change with `jj describe`, create or move a bookmark with
`jj bookmark create <name> -r @` or `jj bookmark set <name> -r @`, and push it with
`jj git push --bookmark <name>`. `gh pr create --head <name>` remains valid for opening a PR.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local conventions and existing history take precedence; do not impose a fixed message format or fixed text.

When the Codex App sandbox blocks bookmark or push operations in an externally managed workspace, describe the change and inform the user to use the App's native controls:

- **"Create branch"** — names the bookmark, then push/open the PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still inspect the change with `jj diff`, update its description with
`jj describe`, and suggest bookmark names and PR descriptions.
