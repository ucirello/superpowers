## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish bookmarks should detect their
environment with read-only Jujutsu commands before proceeding:

```bash
ROOT=$(jj root)
WORKSPACES=$(jj workspace list)
BOOKMARKS=$(jj bookmark list -r @)
```

- Harness-native state identifies a managed workspace → already isolated (skip creation)
- The primary/default workspace appearing in `WORKSPACES` does not by itself prove isolation
- `BOOKMARKS` empty → the current change has no bookmark (create one before push/PR)

See `using-jj-workspaces` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark/push operations in an externally managed
workspace, the agent leaves the working-copy change recorded and informs
the user to use the App's native controls:

- **"Create branch"** — names the App branch, then push/open the PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, inspect `jj diff`, and output suggested bookmark
names, change descriptions, and PR descriptions. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and syntax established by `git log` always win; apply compatible Go guidance to clarity and structure without imposing fixed prefixes, types, scopes, subjects, bodies, or templates.
