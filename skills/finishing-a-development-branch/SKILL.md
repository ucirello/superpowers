---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing Development Work

## Overview

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop — the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

Capture the current workspace and change before any history edits:

```bash
WORKSPACE_PATH=$(jj workspace root)
WORKSPACE_NAME=$(jj workspace list -T 'if(target.current_working_copy(), name ++ "\n", "")')

FEATURE_REVISION=@
if [ -z "$(jj diff -r @ --summary)" ] && \
   [ -z "$(jj log -r @ --no-graph -T 'description')" ]; then
  FEATURE_REVISION=@-
fi
FEATURE_CHANGE_ID=$(jj log -r "$FEATURE_REVISION" --no-graph -T 'change_id ++ "\n"')
FEATURE_BOOKMARK=$(jj log -r "$FEATURE_REVISION & bookmarks()" --no-graph -T 'bookmarks.map(|b| b.name()).join("\n") ++ "\n"')
```

When `@` is a fresh undescribed empty change, `FEATURE_REVISION` selects `@-`,
the completed tip. `FEATURE_CHANGE_ID` is the durable identity of the work even
if integration rewrites its commit ID. A bookmark is optional in Jujutsu and
does not mean a change is checked out. If multiple bookmarks point to the
selected revision, ask which one names this work before an operation needs a
feature bookmark.

Recover the cleanup owner and source workspace root recorded when this
workspace was created. A native harness owns cleanup for its workspace. A
manual workspace is owned by this workflow. If no ownership record exists,
classify the workspace as externally managed; `.tmp/` placement alone is not
proof of ownership. Record the source root as `ORDINARY_WORKSPACE_PATH` for a
manually owned workspace.

The workspace path determines cleanup ownership:

| State | Menu | Cleanup |
|-------|------|---------|
| Ordinary workspace | Standard 3 options | No workspace to remove |
| Explicitly recorded manual workspace | Standard 3 options | Owned workspace; see Step 6 |
| Native or unknown ownership | Standard 3 options | Owner-managed; leave in place |

## Step 3: Determine Base Bookmark

The base bookmark identifies the line of development from which this work
forked. It is usually named in the plan or conversation; otherwise use the
repository's configured `trunk()` as evidence. If the base is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before integrating: choosing the wrong base is expensive to undo.

Record the confirmed name as `BASE_BOOKMARK`. Verify it resolves to exactly
one revision, that `BASE_BOOKMARK..FEATURE_CHANGE_ID` contains only the changes
being finished, and that `BASE_BOOKMARK..@` adds at most the selected feature
stack's fresh empty successor.

## Step 4: Present Options

**Present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the changes as-is (I'll handle them later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

Before Options 1 or 2, inspect all revisions in
`BASE_BOOKMARK..FEATURE_CHANGE_ID`. Every non-empty change must have a
meaningful description before it is integrated or pushed. When composing or
revising a change description:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local syntax from project instructions and history wins when it
differs from Go guidance; apply only compatible Go guidance to quality,
clarity, and structure.

Use `jj describe -r <revision>` for each description that needs work. Do not
apply one fixed description to multiple changes.

### Option 1: Integrate Locally

Fetch first, then rebase the work onto the current base and advance the base
bookmark to the rebased feature tip:

```bash
jj git fetch
jj rebase -r "$BASE_BOOKMARK..@" -o "$BASE_BOOKMARK"
```

Inspect the rebased revisions for conflicts. Advance the base bookmark only
after the selected revisions are conflict-free:

```bash
jj bookmark set "$BASE_BOOKMARK" -r "$FEATURE_CHANGE_ID"

# Verify tests on the integrated result
<test command>
```

If fetch leaves the base bookmark conflicted, or rebase produces content
conflicts, stop and resolve that state before advancing the base bookmark.

If tests fail on the integrated result: stop, leave the workspace and
bookmarks in place, and investigate. Nothing has been pushed, and Jujutsu's
operation log preserves the local recovery path.

Once the integrated result is green, if a feature bookmark exists and differs
from the base bookmark, forget it locally without scheduling remote deletion.
Then clean up the workspace (Step 6):

```bash
if [ -n "$FEATURE_BOOKMARK" ] && [ "$FEATURE_BOOKMARK" != "$BASE_BOOKMARK" ]; then
  jj bookmark forget "$FEATURE_BOOKMARK"
fi
```

### Option 2: Push and Create PR

If the work has no feature bookmark, ask for a name and record it as
`FEATURE_BOOKMARK`. Set that bookmark on the completed feature tip, then push it
explicitly:

```bash
jj bookmark set "$FEATURE_BOOKMARK" -r "$FEATURE_CHANGE_ID"
jj git push --remote origin --bookmark "$FEATURE_BOOKMARK"
```

Do not use `--allow-empty-description`, `--allow-conflicts`, or bypass a push
safety check. A rejected push means the remote moved or the bookmark state
needs attention; fetch and investigate rather than forcing it.

Create the pull request against the confirmed base bookmark with `gh`, follow
the repository's PR template and conventions, and report the URL:

```bash
GIT_DIR="$(jj git root)" gh pr create --base "$BASE_BOOKMARK" --head "$FEATURE_BOOKMARK"
```

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report the feature change ID, any feature bookmark, and the preserved workspace
path.

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Show the exact revisions selected by `BASE_BOOKMARK..@`, including
any fresh empty successor, then confirm first:

```
This will permanently abandon:
- Changes: <change-list>
- Bookmark: <name, if any>
- Workspace at <path, if owned>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, forget any feature bookmark
without scheduling remote deletion, abandon exactly the reviewed revisions,
then clean up the workspace (Step 6):

```bash
if [ -n "$FEATURE_BOOKMARK" ] && [ "$FEATURE_BOOKMARK" != "$BASE_BOOKMARK" ]; then
  jj bookmark forget "$FEATURE_BOOKMARK"
fi
jj abandon "$BASE_BOOKMARK..@"
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Use the `WORKSPACE_PATH` and `WORKSPACE_NAME` values captured in
Step 2.

**If `WORKSPACE_PATH` is the repository's ordinary working directory:** There
is no additional workspace to clean up. Done.

**If this workspace's recorded cleanup owner is manual:** This workflow owns
cleanup. Before removing anything, verify that `WORKSPACE_PATH` and
`WORKSPACE_NAME` match the recorded values, then inspect `jj status` and the
workspace directory for ignored files. Jujutsu snapshots non-ignored
working-copy files, but ignored files are not stored as changes and may exist
nowhere else.

If ignored files would be lost, show your human partner what is at stake and
ask:

```
Workspace removal would delete ignored files that are not stored in Jujutsu:

<file list>

1. Move them into the repository's ordinary workspace
2. Move them into $(jj workspace root)/.tmp as a fallback
3. Delete them (unrecoverable)

Which?
```

Carry out the choice. Change to another registered workspace, forget the owned
workspace while it still exists, and then remove only that workspace directory.
If files must be moved temporarily and no destination was supplied,
create `$(jj workspace root)/.tmp` and use it instead of a global temporary
directory. Never use a force-removal shortcut.

```bash
cd "$ORDINARY_WORKSPACE_PATH"
jj workspace forget "$WORKSPACE_NAME"
rm -r "$WORKSPACE_PATH"
```

**Otherwise:** The host environment owns this workspace — leave it in place.
If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Cleanup Feature Bookmark |
|--------|-----------|------|----------------|--------------------------|
| 1. Integrate locally | yes | - | ordinary only | forget locally |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | ordinary only | forget locally |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only the current workspace when its recorded owner is this manual workflow. Everything else belongs to the host. |
| "Ignored files are probably disposable" | Ignored files are not stored in Jujutsu changes. Show your human partner and ask before deleting them. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Changes and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Integrating into the wrong base is expensive to undo. |
| "The push was rejected — bypassing the safety check will fix it" | A rejected push means the remote moved or bookmark state changed. Fetch and investigate. |
