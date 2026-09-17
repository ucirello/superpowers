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
# Capture now, while still inside the workspace — Step 5 changes directory
# before cleanup (Step 6) needs these values
WORKSPACE_ROOT=$(jj workspace root)
DEFAULT_ROOT=$(jj workspace root --name default 2>/dev/null || true)
# name<TAB>root for every workspace — match WORKSPACE_ROOT to find the current name
jj workspace list -T 'name ++ "\t" ++ if(root, root, "(none)") ++ "\n"'
# Named bookmark(s) on the working-copy commit — empty means anonymous @
FEATURE_BOOKMARKS=$(jj log -r @ -T 'local_bookmarks.map(|b| b.name()).join("\n")' --no-graph 2>/dev/null)
# Or: jj bookmark list -r '@'
```

If templates are unavailable, fall back to:

```bash
jj workspace list
jj log -r @ --no-graph
jj bookmark list
```

Compare `WORKSPACE_ROOT` to `DEFAULT_ROOT` (or match roots from `jj workspace list`): a secondary workspace is any working copy whose root is not the default workspace root.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `WORKSPACE_ROOT == DEFAULT_ROOT` (or only one workspace) | Standard 3 options | No extra workspace to clean up |
| Secondary workspace, named bookmark on `@` | Standard 3 options | Provenance-based (see Step 6) |
| Secondary workspace, anonymous `@` (no local bookmark) | Reduced 2 options (no merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the feature bookmark's tracked upstream. If it is
not already known, ask: "This work split from <your best guess> - is that
correct?" Confirm before merging: merging into the wrong base is expensive to
undo.

## Step 4: Present Options

**Default workspace and named-bookmark secondary workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**Anonymous working copy (no local bookmark on `@`) — present exactly these 2 options:**

```
Implementation complete. You're on an anonymous working copy (externally managed workspace).

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
# Get default workspace root for CWD safety
MAIN_ROOT=$(jj workspace root --name default)
cd "$MAIN_ROOT"

# Fetch latest base, then merge — verify success before removing anything
jj git fetch
# Create a merge commit with both parents (or: rebase feature onto base, then advance base)
jj new <base-bookmark> <feature-bookmark>
# Advance the base bookmark onto the merge result
jj bookmark move <base-bookmark> --to @

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the workspace and bookmark in
place, and investigate — nothing has been pushed, so the merge is local
and recoverable. You can `jj undo` the local merge operations if needed.

Once the merged result is green: clean up the workspace (Step 6), then
delete the feature bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
# Named feature bookmark:
jj git push --bookmark <feature-bookmark>

# From an anonymous working copy, create a bookmark on @ first, then push:
# jj bookmark create <new-bookmark> -r @
# jj git push --bookmark <new-bookmark>
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — `gh` or another forge CLI if one is available, or the creation URL
most forges print when you push — following the repo's PR template and
conventions if present, and report the URL to your human partner.

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
MAIN_ROOT=$(jj workspace root --name default)
cd "$MAIN_ROOT"
```

Then clean up the workspace (Step 6) and delete the feature bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed directory to the
default workspace root — workspace removal must run from outside the
secondary workspace — and use the `WORKSPACE_ROOT` / `DEFAULT_ROOT` /
`WORKSPACE_NAME` / `FEATURE_BOOKMARKS` values captured in Step 2, from
before that directory change.

**If `WORKSPACE_ROOT == DEFAULT_ROOT` (or only one workspace):** Default
workspace only, no extra workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `.worktrees/` or `worktrees/`:** this skill
(or its pair) created this workspace — we own cleanup:

```bash
jj workspace forget "$WORKSPACE_NAME"
rm -rf "$WORKSPACE_ROOT"
```

**Before `rm -rf`:** inspect for files that exist only in that workspace —
ignored scratch, notes, or other content never snapshotted into `@`. Never
delete the directory on your own initiative when unique files are at stake.
Show your human partner what is at stake and ask:

```bash
# From outside the workspace, or with -R pointing at it:
jj -R "$WORKSPACE_ROOT" st
# Also surface ignored/untracked material the snapshot does not own, e.g.:
(cd "$WORKSPACE_ROOT" && find . -type f \( -name '*.md' -o -name '.env*' -o -name '*.local' \) 2>/dev/null | head -50)
```

```
Workspace cleanup would destroy files that may exist only here:

<file list>

1. Keep them on a bookmark before cleanup
2. Move them into <default workspace root>
3. Delete them (unrecoverable)

Which?
```

If they choose to keep work on a bookmark first: Based on
https://go.dev/wiki/CommitMessage and on past commit messages that you can
see in `git log`, compose commit messages adherent to the present standards.
Repository-local commit-message syntax as established by project
instructions and `git log` ALWAYS wins when it differs from the Go guidance.
Then apply the description with a placeholder message (no fixed template):

```bash
jj describe -r @ -m "<message composed from the standards above>"
# Ensure a bookmark points at the work if one does not already:
# jj bookmark create <feature-bookmark> -r @
```

Carry out the choice, then forget the workspace and remove the directory.

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
| "Cleanup found unique files — `rm -rf` is just finishing the cleanup" | Unique files in that workspace are destroyed permanently by `rm -rf`. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — forcing the remote bookmark will fix it" | A rejected push means the remote moved. Investigate; force overwrite only on your human partner's explicit request. |
