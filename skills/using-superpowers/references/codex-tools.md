## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish bookmarks should detect their
environment with read-only JJ commands before proceeding:

```bash
jj --ignore-working-copy root
jj --ignore-working-copy workspace list
jj --ignore-working-copy status
jj --ignore-working-copy bookmark list
```

If `jj --ignore-working-copy root` fails, the harness has not provided a JJ
repository. Do not infer bookmark or workspace state from that failure; use the
harness's native isolation controls and local `.tmp` storage until the
repository is available through JJ.

- Runtime instructions or harness context identify the current workspace as task-isolated → skip workspace creation
- The current workspace merely appears in `jj workspace list` → this proves registration, not isolation; follow `using-git-worktrees` Step 0
- No bookmark points to `@` → create one before pushing or opening a PR

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark/export/push operations in an externally
managed workspace, the agent describes all work and informs the user to use
the App's Git-compatible native controls after `jj git export`:

- **"Create branch"** — names the exported bookmark, then push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, inspect changes, and suggest bookmark names and
PR descriptions. For every commit-message composition site, use this exact
instruction: "Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards." Repository-local instructions and the syntax and style visible in history always win. Apply Go guidance only where compatible, and never impose a fixed type, scope, prefix, subject, body, or template. Use `gh` for GitHub PR operations after the bookmark is pushed.
