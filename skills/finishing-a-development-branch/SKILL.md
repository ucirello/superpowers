---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Bookmark

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
WS_ROOT=$(jj workspace root 2>/dev/null) || true
# Capture now, while still inside the workspace — Step 5 changes directory
# before cleanup (Step 6) needs this value
WORKSPACE_PATH="$WS_ROOT"
jj workspace list
BOOKMARK=$(jj log -r @ -T 'self.bookmarks().map(|b| b.name()).join(" ")' --no-graph 2>/dev/null)
```

Determine isolation: if current `jj workspace root` is not the default workspace's path (or `WORKSPACE_PATH` is under `.worktrees/` / `worktrees/`), you are in a secondary workspace. Otherwise you are in the default (normal) workspace.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Default workspace only (normal repo) | Standard 3 options | No secondary workspace to clean up |
| Secondary workspace, named bookmark on `@` | Standard 3 options | Provenance-based (see Step 6) |
| Secondary workspace, no bookmark on `@` (unnamed working-copy change) | Reduced 2 options (no local merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the bookmark's upstream tracking. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Default workspace and named-bookmark secondary workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**No bookmark on `@` (unnamed working-copy change, externally managed) — present exactly these 2 options:**

```
Implementation complete. You're on a working-copy change with no bookmark (externally managed workspace).

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
# Resolve default workspace root for CWD safety
DEFAULT_ROOT=$(jj workspace root --name default 2>/dev/null) \
  || DEFAULT_ROOT=$(jj workspace list -T 'if(self.name() == "default", self.root() ++ "\n", "")' 2>/dev/null | head -1)
# Fallback: parent of .worktrees/ or worktrees/ if path heuristic applies
cd "$DEFAULT_ROOT"

# Fetch latest remote bookmarks, then advance base if needed
jj git fetch
jj rebase -d <base-bookmark>@origin -r <base-bookmark> 2>/dev/null || true
# Or: jj new <base-bookmark>@origin && jj bookmark set <base-bookmark> -r @

# Merge feature into base — create a merge change, then move the base bookmark
jj new <base-bookmark> <feature-bookmark>
# Resolve conflicts if any (edit files, then jj squash into the conflicted change as needed)

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
# From a working-copy change with no bookmark, name it first:
# jj bookmark create <new-bookmark> -r @
# jj git push --bookmark <new-bookmark>
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available (e.g. `gh pr create`), or the creation URL most forges
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
DEFAULT_ROOT=$(jj workspace root --name default 2>/dev/null) \
  || DEFAULT_ROOT=$(jj workspace list -T 'if(self.name() == "default", self.root() ++ "\n", "")' 2>/dev/null | head -1)
cd "$DEFAULT_ROOT"
```

Then clean up the workspace (Step 6) and delete the bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed directory to the
default workspace root — workspace forget must run from outside the secondary
workspace — and use the `WORKSPACE_PATH` / workspace name values captured in
Step 2, from before that directory change.

**If default workspace only:** Normal repo, no secondary workspace to clean up. Done.

**If `WORKSPACE_PATH` is under `.worktrees/` or `worktrees/`:** This session
(or RocketClaw workspace setup) created this workspace — we own cleanup:

```bash
# Forget by workspace name (often the bookmark / directory basename)
jj workspace forget <workspace-name>
# Remove destination directory from disk if it still exists
rm -rf "$WORKSPACE_PATH"
# JJ has no separate prune; list and forget any other stale named workspaces if needed
jj workspace list
```

**If the destination still has unique local files** (unsaved plans, notes,
or scratch that never became part of a change): never force-delete on your
own initiative. Show your human partner what is at stake and ask:

```bash
jj -R "$WORKSPACE_PATH" status
# Or from inside that path before leaving: jj st
ls -la "$WORKSPACE_PATH"
```

```
Workspace cleanup blocked — these paths may exist only here:

<file list>

1. Record them on <bookmark> before cleanup (jj commit / jj describe per project standards)
2. Move them into <default workspace root>
3. Delete them (unrecoverable)

Which?
```

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax from project instructions and `git log` ALWAYS wins. Use `jj commit -m "<message composed from the standards above>"` or `jj describe -m "<message composed from the standards above>"` when recording leftover files.

Carry out the choice, then forget the workspace and remove the destination directory.

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
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "Cleanup blocked — force-delete is just finishing" | Unique files may exist only in that workspace. Force-delete destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
