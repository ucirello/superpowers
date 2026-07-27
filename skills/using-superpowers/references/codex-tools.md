## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your harness cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish changes should inspect the jj environment before proceeding:

```bash
jj workspace root
jj workspace list
jj status
jj bookmark list -r @
```

- `jj workspace root` succeeds → already in a jj workspace; use `$(jj workspace root)/.tmp` for temporary storage
- `jj workspace root` fails → use the local `.tmp` directory for temporary storage and treat an existing harness checkout as externally managed; do not create another workspace automatically
- `jj workspace list` shows the workspaces backed by the repository; do not add another for the same task
- No bookmark at `@` is normal in jj; create or move a bookmark only when sharing the change

See `using-jj-workspaces` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark or push operations in an externally managed workspace, finish the working-copy change and direct the user to the native **Create branch** or **Hand off to local** control, as appropriate.

Before updating or recommending a change description, inspect the repository's existing message style. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository conventions take precedence; do not impose a fixed message syntax. Use `jj describe` to set the description, `jj bookmark create` or `jj bookmark move` when a named bookmark is needed, `jj git push --bookmark <bookmark-name> --remote <remote-name>` to publish it, and `gh` for the pull request when available.

The agent can still run tests, inspect `jj diff`, and output suggested bookmark names and pull-request descriptions.
