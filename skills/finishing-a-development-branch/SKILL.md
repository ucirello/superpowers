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
# Capture now, while still inside the workspace — Step 5 may change directory
# before cleanup (Step 6) needs these values
WORKSPACE_ROOT=$(jj workspace root)
CURRENT_WORKSPACE=$(jj workspace list | awk -v root="$WORKSPACE_ROOT" -F': ' '$2 == root { print $1; exit }')
BOOKMARKS_ON_AT=$(jj log -r @ -T 'bookmarks' --no-graph)
# Default workspace is typically named "default"
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Current workspace is `default` (or only workspace) | Standard 3 options | No linked workspace to clean up |
| Non-default workspace, bookmark(s) on `@` | Standard 3 options | Provenance-based (see Step 6) |
| Non-default workspace, no bookmark on `@` | Reduced 2 options (no local merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the feature bookmark's upstream tracking. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Default workspace and named-bookmark linked workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**No bookmark on `@` (externally managed workspace) — present exactly these 2 options:**

```
Implementation complete. You're in an externally managed workspace with no bookmark on @.

1. Create bookmark, push, and open a Pull Request
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
# Get default workspace root for CWD safety
DEFAULT_ROOT=$(jj workspace list | awk -F': ' '$1 == "default" { print $2; exit }')
cd "$DEFAULT_ROOT"

# Merge first — verify success before removing anything
# Create a merge change with both base and feature as parents, then move base bookmark
jj new <base-bookmark> <feature-bookmark>
# Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `jj log`, compose commit messages adherent to the present standards.
jj describe -m "<composed message>"
jj bookmark set <base-bookmark> -r @
jj new  # leave @ on a new empty change after the merge

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
# From a workspace with no bookmark on @, create one first:
# jj bookmark set <new-bookmark> -r @
# jj git push --bookmark <new-bookmark>
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available (e.g. `gh`), or the creation URL most forges
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
DEFAULT_ROOT=$(jj workspace list | awk -F': ' '$1 == "default" { print $2; exit }')
cd "$DEFAULT_ROOT"
```

Then clean up the workspace (Step 6) and delete the bookmark:

```bash
jj bookmark delete <feature-bookmark>
# If the bookmark must be abandoned even with divergent history, confirm with
# your human partner first — never abandon destructive history on your own initiative.
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed directory to the
default workspace root — workspace forget must run from outside the linked
workspace — and use the `WORKSPACE_ROOT`/`CURRENT_WORKSPACE` values captured in
Step 2, from before that directory change.

**If current workspace was `default`:** Default workspace, no linked workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `.worktrees/`, `workspaces/`, or `worktrees/`:** RocketClaw
created this workspace — we own cleanup:

```bash
jj workspace forget "$CURRENT_WORKSPACE"
# Remove the working-copy directory if it still exists on disk after forget
rm -rf "$WORKSPACE_ROOT"
```

**If forget/removal is refused** or the workspace directory holds files that
were never recorded in jj (untracked plans, notes, or scratch work): Never
force-delete on your own initiative. Show your human partner what is at stake
and ask:

```bash
jj -R "$WORKSPACE_ROOT" status
# Also surface untracked files the VCS does not manage:
(cd "$WORKSPACE_ROOT" && find . -type f | head -n 100)
```

```
Workspace cleanup blocked — these files may not be recorded in jj:

<file list>

1. Record them on <bookmark> before cleanup (jj describe / jj commit)
2. Move them into <default workspace root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice, then forget the workspace.

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
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/`, `workspaces/`, or `worktrees/`. Everything else belongs to the host. |
| "Cleanup blocked — force-delete is just finishing" | The block means files may exist only in that workspace. Force-delete destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
