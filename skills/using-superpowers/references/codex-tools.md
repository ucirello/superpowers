## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables the multi-agent tools that skills like
`dispatching-parallel-agents` and `subagent-driven-development` use.
Which tools you get depends on the multi-agent version your model
preset selects (current presets run V2; older ones run V1). Trust your
actual tool list over any table — including this one — when they
disagree.

- **Spawning:** give children a clean context with
  `spawn_agent {fork_turns: "none"}`; the default `"all"` copies your
  entire transcript into the child. On Codex 0.145+, role files under
  `~/.codex/agents/` attach to isolated forks via `agent_type`.
  Full-history forks accept `model` and `reasoning_effort` overrides
  (only `agent_type` is refused there) — isolated forks are the SDD
  default for context hygiene, not because overrides require them.
- **Fix rounds:** resume the implementer with `followup_task` — it
  delivers your message, triggers a turn, and transparently reloads a
  child the harness evicted. Never dispatch a fresh implementer on the
  theory that a spawned agent cannot be messaged again; on V2 it
  always can.
- **Lifecycle:** V2 has no `close_agent`. Finished children are
  evicted automatically when slots are needed; leaving them unclosed
  costs nothing. Only V1 sessions have `close_agent` — there, close
  reviewers when their review returns, and close each implementer
  after its task's review passes.
- **Model names:** never copy a model name from a skill, table, or old
  session into `spawn_agent` without checking it against your current
  spawn allowlist — V2 accepts only V2-capable presets and hard-errors
  on the rest.

## Waiting on children

`wait_agent` is an event subscription, not a poll: a long wait wakes
the moment a child produces mailbox activity, with the same latency as
a short one. Short-timeout polling buys nothing and costs a tool call —
and a context rebill — per poll. In measured sessions, roughly
two-thirds of all wait calls were short polls that timed out.

- While you still have local work, do not wait at all. A completed
  child's final answer is pushed into your mailbox and arrives with
  your next turn.
- When you are genuinely idle with children outstanding, wait in
  bounded stretches: `wait_agent` with `timeout_ms` 300000-600000
  (5-10 minutes). After each stretch — wake or timeout — post one
  status line, run `list_agents`, and chase any child that finished
  without reporting. Never stack polls shorter than five minutes; the
  event subscription wakes a bounded stretch just as fast as a short
  one.
- Completion mail cannot wake an idle controller (it is delivered
  without triggering a turn); covering that idle window is
  `wait_agent`'s only job. A stretch that times out with no activity
  is your cue to reconcile, not to shorten the next stretch.

## Model routing on spawns

Every `spawn_agent` you issue — including when you are yourself a
spawned child running a fan-out — sets `model` AND `reasoning_effort`
explicitly, per the Model Selection rules of the skill you are
executing. Setting `model` alone is a trap: the child's effort
silently resets to that model's default, not to yours.

Ask your human partner to add a machine-level backstop to
`~/.codex/config.toml` so any spawn that slips through still routes to
a deliberate tier instead of silently inheriting the session's most
expensive model:

```toml
[agents]
default_subagent_model = "<a mid-tier model from your spawn allowlist>"
default_subagent_reasoning_effort = "medium"
```

## Environment Detection

Skills that create workspaces or finish changes should detect their
environment with read-only Jujutsu commands before proceeding:

```bash
WORKSPACE_ROOT=$(jj --ignore-working-copy workspace root 2>/dev/null)
WORKSPACES=$(jj --ignore-working-copy workspace list)
CURRENT_BOOKMARKS=$(jj --ignore-working-copy bookmark list --revision @)
```

- Temporary storage belongs under `$(jj workspace root)/.tmp/`. If
  `jj workspace root` fails, the directory is not a Jujutsu workspace; do not
  substitute another VCS's workflow commands, and use the current directory's `.tmp/`
  only as the fallback.
- `WORKSPACES` identifies all attached working copies. A current workspace does
  not prevent creating another with `jj workspace add <workspace-path>`.
- Empty `CURRENT_BOOKMARKS` is normal: Jujutsu changes do not require bookmarks.
  Create or move a bookmark only when a named reference is needed for transport.

See `using-jj-workspaces` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

Jujutsu automatically snapshots working-copy edits. Before finishing, inspect
them with `jj status` and `jj diff`, then set the current change description with
`jj describe` or finish it and start a new change with `jj commit`.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Runtime repository instructions and the repository-prescribed `git log` syntax
take precedence. Where compatible, keep the description clear and concise and
preserve useful rationale rather than merely restating the diff. Do not impose
a fixed message, prefix, type, scope, subject, body, or template. Apply this
policy whenever composing, editing, validating, or recommending a change
description.

For command-line transport, create a neutral bookmark with
`jj bookmark create <bookmark> --revision <revision>` or move an existing one
with `jj bookmark move <bookmark> --to <revision>`, push it with
`jj git push --bookmark <bookmark> --remote <remote>`, and use `gh` for the pull
request. In a non-colocated repository, invoke GitHub CLI as
`GIT_DIR=$(jj git root) gh <command>`.

When an externally managed sandbox blocks bookmark or transport operations, the
agent leaves all work snapshotted and described, then informs the user to use
the App's native controls:

- **"Create branch"** — creates the App-managed transport reference, then push
  and open the pull request via the App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, inspect snapshots, set change descriptions, and
output suggested bookmark names, change descriptions, and pull-request
descriptions.
