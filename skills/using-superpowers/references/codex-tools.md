## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. When using subagent-driven-development, close reviewer subagents when their review returns. Keep each implementer subagent open until its task's review passes — the fix loop resumes the implementer — then close it. If your runtime cannot send another message to a spawned agent, dispatch each fix round as a fresh implementer carrying the brief, the report file, and the findings.

## Environment Detection

Skills that create workspaces or finish bookmarks should inspect their
environment with read-only JJ commands before proceeding:

```bash
jj --ignore-working-copy root
jj --ignore-working-copy workspace list
jj --ignore-working-copy status
```

- Explicit instructions or a verified isolated workspace path/name identify task isolation → reuse it instead of creating another workspace
- No suitable bookmark points to the working-copy commit → create one before publishing or opening a PR

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks bookmark or publish operations in an externally
managed workspace, the agent records all work in JJ and informs the user
to finish from their local checkout:

- Create a bookmark for the working-copy commit
- Publish it with `jj git push`, then open the PR with GitHub or `gh`

The agent can still run tests and suggest bookmark names, JJ descriptions,
and PR descriptions. When composing a JJ description, repository-local
instructions and the syntax established by the existing log take precedence;
do not impose a fixed syntax. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Derive neutral wording from the actual
change rather than prescribing a fixed prefix, type, scope, or example.
