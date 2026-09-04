---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

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

```bash
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_PATH="$WORKSPACE_ROOT"
# Capture now, while still inside the workspace — Step 5 changes directory
# before cleanup (Step 6) needs this value
#
# Isolation: skill-managed workspaces live under .worktrees/ or worktrees/,
# or have a jj workspace name other than "default".
ISOLATED=false
if echo "$WORKSPACE_PATH" | grep -qE '/\.worktrees/|/worktrees/'; then
  ISOLATED=true
fi
WS_NAME=$(jj workspace list 2>/dev/null | awk -v root="$WORKSPACE_PATH" '$0 ~ root { print $1; exit }')
if [ -n "$WS_NAME" ] && [ "$WS_NAME" != "default" ]; then
  ISOLATED=true
fi
# Anonymous working-copy change (no bookmark on @) ≈ detached HEAD
HAS_BOOKMARK=$(jj log -r '@' -T 'local_bookmarks ++ "\n"' --no-graph 2>/dev/null | tr -d '[:space:]')
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Not isolated (`ISOLATED=false`, default workspace) | Standard 3 options | No workspace to clean up |
| Isolated, named bookmark on `@` | Standard 3 options | Provenance-based (see Step 6) |
| Isolated, no bookmark on `@` (anonymous working-copy) | Reduced 2 options (no merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the bookmark's upstream tracking. If it is not already
known, ask: "This bookmark split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Normal repo and named-bookmark workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**Anonymous working-copy (no bookmark) — present exactly these 2 options:**

```
Implementation complete. You're on an anonymous working-copy change (externally managed workspace).

1. Push as new bookmark and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Merge Locally

```bash
# Get primary workspace root for CWD safety (default workspace)
MAIN_ROOT=$(jj workspace list | awk '$1 == "default" { print $2; exit }')
# Fallback if list format differs: walk up from current root to the repo that owns default
if [ -z "$MAIN_ROOT" ]; then
  MAIN_ROOT=$(jj workspace root)
fi
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
jj git fetch
jj new <base-bookmark> <feature-bookmark>   # merge change with both parents
jj bookmark set <base-bookmark> -r @

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the workspace and bookmark in
place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the merged result is green: clean up the workspace (Step 6), then
delete the feature bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
jj git push --bookmark <feature-bookmark>
# From an anonymous working-copy, create a bookmark then push:
# jj bookmark create <new-bookmark> -r @
# jj git push --bookmark <new-bookmark>
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — `gh` if available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping bookmark <name>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Bookmark <name>
- All changes: <change-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
MAIN_ROOT=$(jj workspace list | awk '$1 == "default" { print $2; exit }')
if [ -z "$MAIN_ROOT" ]; then
  MAIN_ROOT=$(jj workspace root)
fi
cd "$MAIN_ROOT"
```

Then clean up the workspace (Step 6) and delete the bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed directory to the
main repo root — workspace removal must run from outside the workspace —
and use the `WORKSPACE_PATH` / isolation values captured in
Step 2, from before that directory change.

**If not isolated (`ISOLATED=false`):** Normal default workspace, nothing extra to clean up. Done.

**If `WORKSPACE_PATH` is under `.worktrees/` or `worktrees/`:** This skill
created this workspace — we own cleanup:

```bash
# Forget the jj workspace registration (NAME from jj workspace list)
jj workspace forget <workspace-name>
rm -rf "$WORKSPACE_PATH"
```

**If removal is refused** (workspace holds modified or untracked files, or
forget/rm would lose unique content): the workspace holds files that exist
nowhere else — undescribed plans, notes, or scratch work. Never force-delete
on your own initiative. Show your human partner what is at stake and ask:

```bash
jj -R "$WORKSPACE_PATH" status
# or from inside that workspace:
# jj status
```

```
Workspace removal refused — these files were never committed:

<file list>

1. Commit them to <bookmark> before cleanup
2. Move them into <main repo root>
3. Delete them (unrecoverable)

Which?
```

If they choose commit: describe the working-copy change before cleanup.
Based on https://go.dev/wiki/CommitMessage and on past commit messages that
you can see in `git log`, compose commit messages adherent to the present
standards. Repository-local syntax from that history wins over any fixed
template. Then:

```bash
jj describe -m "<composed message>"
# or jj commit -m "<composed message>" if snapshotting a new change is appropriate
```

Carry out the choice, then remove the workspace (`jj workspace forget` +
`rm -rf` as above).

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/` or `worktrees/` that this skill created. Everything else belongs to the host. |
| "Removal refused — force-delete is just finishing the cleanup" | The refusal means files exist only in that workspace. Force-delete destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
