## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Workspace Detection

Skills that create workspaces or finish changes should inspect the Jujutsu
workspace before proceeding:

```bash
ROOT=$(jj workspace root 2>/dev/null)
jj workspace list
jj status
```

- A successful `jj workspace root` means the current directory is already in a
  workspace; do not create another unless isolation is required.
- Use `jj workspace add <destination> -r <revision>` for an isolated working
  copy. Jujutsu snapshots working-copy changes automatically, so there is no
  staging step.
- Use `jj bookmark create <name> -r @` when a named remote publication target
  is needed. Use `jj git push --bookmark <name>` and `gh` for GitHub operations.

See `using-git-worktrees` Step 0 and `finishing-a-development-branch` Step 1 for how
each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark or push operations in an externally managed
workspace, leave the working-copy change complete and use `jj describe` to set
its description before informing the user to use the App's native controls.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Inspect repository history with `jj log` before composing the description.
Follow local syntax and history first, applying compatible Go guidance only to
quality, clarity, and structure. Do not impose a fixed subject, body, prefix,
template, capitalization scheme, or example wording.

Use the App's native controls:

- **"Create branch"** - names and publishes the Jujutsu-backed change through the App UI
- **"Hand off to local"** - transfers the change to the user's local checkout

The agent can still run tests and recommend bookmark names, change descriptions,
and pull-request descriptions.
