## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish changes should inspect their JJ
environment with read-only commands before proceeding:

```bash
jj workspace root
jj workspace list
jj log --no-graph -r @
```

- If the current workspace is already assigned to this task, do not create a
  redundant workspace. Use session context and the current workspace entry from
  `jj workspace list`; the number of attached workspaces is not an isolation
  signal.
- A current change without a suitable bookmark needs a bookmark before
  `jj git push` or opening a PR.

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark creation or `jj git push` in an externally
managed workspace, the agent finishes the JJ change and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then exports, pushes, and opens the PR
  via the App UI
- **"Hand off to local"** — transfers the change to the user's local workspace

The agent can still run tests, describe the JJ change with `jj describe`, and
suggest bookmark names and PR descriptions. For every JJ change description,
apply this instruction:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and syntax observed at runtime always win. Apply
only compatible Go guidance: use a clear, concise subject and an explanatory
body when it improves understanding. Do not impose a fixed prefix,
capitalization, tense, Conventional Commit form, subject/body/trailer syntax,
message, or example.
