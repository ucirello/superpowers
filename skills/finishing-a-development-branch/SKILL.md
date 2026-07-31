---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Change

## Overview

**Core principle:** Verify tests → detect environment → identify revisions → present options → execute choice → clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

Jujutsu has no staging area or index. The working copy is a change (`@`), and
most `jj` commands snapshot file changes into it automatically. Bookmarks are
named pointers, not active branches; they do not automatically advance when a
new change is created.

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop — the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment and Snapshot the Work

Run:

```bash
jj status
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list
jj bookmark list --all-remotes
```

`jj status` snapshots the working copy. Record the current workspace's name by
matching `WORKSPACE_ROOT` against `jj workspace root --name <workspace-name>`
for the names from `jj workspace list`. Also record whether the workspace path
is under the repository's `.workspaces/` or `workspaces/` directory;
that provenance controls cleanup in Step 6.

Use workspace-root `.tmp/` for temporary files. If the current directory is not
inside a Jujutsu workspace, use a local `.tmp/` directory instead of an OS temp
directory.

## Step 3: Identify the Feature Revision and Base

The feature revision is the head of the completed work. It is often `@`, but is
often `@-` when `@` is the empty working-copy change created by `jj commit`.
Inspect `jj status`, `jj log -r '@ | @-'`, and `jj diff` and record the exact
revision as `<feature-rev>`. Do not publish an accidental empty working-copy
change. If the intended feature tip is ambiguous, ask before proceeding.

The base is the revision this work forked from, usually identified by the plan,
conversation, repository conventions, or a tracked remote bookmark. Confirm
the bookmark and remote when they are not already known. After fetching, use
`<base-bookmark>@<remote>` when the remote's latest base is intended; do not
assume that a same-named local bookmark is tracked or current.

Inspect all feature revisions and their descriptions:

```bash
jj log -r '<base-rev>..<feature-rev>'
```

Every non-empty revision that will be integrated or pushed must have a suitable
description. Repository-local conventions take precedence. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Use `jj describe -r <revision>` to edit a description without supplying a fixed message or template, then inspect the resulting log again.

## Step 4: Present Options

Present exactly these 3 options, substituting the confirmed bookmark and revision names:

```
Implementation complete. What would you like to do?

1. Integrate <feature-rev> into <base-bookmark> locally
2. Push <feature-bookmark> and create a pull or merge request
3. Keep the change as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming from
the list above. Discarding work happens only in response to your human partner
explicitly asking for it (see below). Wait for their answer; the integration
decision is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

Fetch from the repository's configured or confirmed remote:

```bash
jj git fetch --remote <remote>
jj log -r '<base-bookmark>@<remote> | <feature-rev>'
```

Stop if the fetch creates a bookmark conflict or changes the understood base.
Confirm the new base before integrating.

Preserve ordinary merge behavior:

- If `<base-bookmark>@<remote>` is an ancestor of `<feature-rev>`, fast-forward
  the local base bookmark with
  `jj bookmark set <base-bookmark> -r <feature-rev>`.
- Otherwise, create a merge change with
  `jj new <base-bookmark>@<remote> <feature-rev>` and resolve any conflicts.

For a newly created merge change, repository-local conventions take precedence. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Set its description with `jj describe` in the editor; do not supply a fixed message or template. Verify the description and parents with `jj show @`, then move the local base bookmark to the merge change with `jj bookmark set <base-bookmark> -r @`.

Run the full test suite on the revision now targeted by the local base
bookmark. If tests fail, stop and investigate. Leave the workspace, feature
bookmark, feature revisions, and local base bookmark in their current state;
nothing has been pushed, and `jj op log` plus `jj undo` preserve recovery
options.

Once the integrated result is green, forget the local feature bookmark without
scheduling remote deletion:

```bash
jj bookmark forget <feature-bookmark>
```

Skip this command if no local feature bookmark exists. Do not use
`jj bookmark delete` here: deletion is propagated on a later push, while local
post-integration cleanup must not delete an existing remote bookmark. Then
clean up the workspace as described in Step 6.

### Option 2: Push and Create a Request

Choose the feature bookmark from repository conventions or the human partner's
choice. Because bookmarks do not follow the working-copy change automatically,
set it explicitly to the confirmed feature revision:

```bash
jj bookmark set <feature-bookmark> -r <feature-rev>
jj git push --remote <remote> --bookmark <feature-bookmark>
```

The first push automatically starts tracking the remote bookmark. If the push
is rejected because the remote moved, fetch and resolve the bookmark state; do
not bypass JJ's safety checks or rewrite the remote on an assumption.

Then create the pull or merge request against `<base-bookmark>` with the
forge's tooling, following the repository's request template and conventions.
Report the resulting URL. Keep the workspace because review feedback is handled
there.

### Option 3: Keep As-Is

Report: "Keeping change <change-id>. Workspace preserved at <path>."

Also report any bookmark that points to the feature revision. If there is no
feature bookmark, say so; JJ changes remain addressable by change ID without
one.

### If the human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work
away. First get the exact revisions with
`jj log -r '<base-rev>..<feature-rev>'`, then confirm:

```
This will abandon:
- Change <change-id>
- All revisions: <revision-list>
- Local bookmark <feature-bookmark>, if present
- Workspace at <path>, if this workflow owns it

Type 'discard' to confirm.
```

Wait for that exact confirmation.

After exact confirmation, abandon only the displayed feature-only revisions:

```bash
jj bookmark forget <feature-bookmark>
jj abandon '<base-rev>..<feature-rev>'
```

Skip the bookmark command if no local feature bookmark exists. `jj abandon`
rebases descendants onto the abandoned revisions' parents and is recoverable
through the operation log. Never broaden the revset after confirmation. Then
clean up the workspace using Step 6.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. JJ workspace cleanup has two separate operations: forgetting
the workspace registration and deleting its files. `jj workspace forget` does
not remove files from disk.

**If this is the sole workspace, or it is not the exact workspace path beneath
the temporary parent recorded by using-git-worktrees:** Leave it in place. The
host environment owns it. If the platform provides a workspace-exit tool, use
it.

**If another registered workspace exists and `WORKSPACE_ROOT` is the exact
workspace path beneath that recorded temporary parent:** Change to the other
workspace or the temporary parent's parent directory, then run:

```bash
jj -R <other-workspace-root> workspace forget <workspace-name>
rm -rf -- "$WORKSPACE_ROOT"
```

Before deletion, re-check that `WORKSPACE_ROOT` is the exact path recorded in
Step 2, is not the current directory, is beneath the exact temporary parent
recorded by using-git-worktrees, and is not the other workspace root. Delete no
other workspace or stale registration.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Forget Feature Bookmark |
|--------|-----------|------|----------------|--------------------------|
| 1. Integrate locally | yes | - | only if host-owned | yes, locally only |
| 2. Create request | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | only if host-owned | yes, locally only |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is the human partner's decision. Present the choices and wait. |
| "They seem done with this feature, so I'll offer to discard it" | Discard happens only when the human partner asks for it explicitly. |
| "That sounds like confirmation" | Only the typed word `discard` authorizes abandonment and deletion. |
| "The request is open, so the workspace is clutter" | Review feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale" | Clean up only the confirmed current workspace under a managed workspace directory. Everything else belongs to the host. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything while you investigate. |
| "The base is obviously main" | Confirm the fork point and current remote bookmark. Integrating into the wrong base is expensive to undo. |
| "The bookmark must point at @" | JJ has no active bookmark, and `jj commit` commonly leaves an empty `@`. Identify the feature revision explicitly. |
| "The push was rejected, so I should force it" | JJ push safety checks detected changed remote state. Fetch, inspect, and resolve it. |
