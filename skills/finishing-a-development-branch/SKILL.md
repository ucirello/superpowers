---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Change descriptions

Before any `jj describe` or `jj commit` that needs a message: Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Also check `jj log` for local history. Repository-local syntax from project instructions and `git log` ALWAYS wins when it differs from the Go guidance. Apply compatible Go guidance to message quality, clarity, and structure without replacing repository-local syntax. Determine the message at runtime — do not use fixed Conventional Commit templates. Prefer:

```bash
jj describe -m "<message composed from the standards above>"
# or, when finishing the working-copy change and starting a new one:
jj commit -m "<message composed from the standards above>"
```

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
WORKSPACE_PATH="$WORKSPACE_ROOT"
# List workspaces (name + path). The workspace named "default" is the primary checkout.
jj workspace list
# Feature bookmark on the working-copy change (empty if none)
FEATURE_BOOKMARK=$(jj log -r @ -T 'local_bookmarks.map(|b| b.name()).join("\n")' --no-graph 2>/dev/null | head -n1)
# Fallback: bookmark pointing at @- when @ is an empty working-copy change
if [ -z "$FEATURE_BOOKMARK" ]; then
  FEATURE_BOOKMARK=$(jj log -r @- -T 'local_bookmarks.map(|b| b.name()).join("\n")' --no-graph 2>/dev/null | head -n1)
fi
```

Determine whether this is the default workspace or a secondary one:

| Signal | Meaning |
|--------|---------|
| Only one workspace in `jj workspace list`, and path is the repo's primary checkout | Default workspace (normal repo) |
| Multiple workspaces; current root differs from the default workspace path | Secondary workspace |
| Path is under `.worktrees/` or `worktrees/` | Skill-managed workspace (we own cleanup) |
| Working copy has no local bookmark at `@` or `@-` | Unnamed working copy (externally managed or not yet bookmarked) |

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Default workspace | Standard 3 options | No secondary workspace to clean up |
| Secondary workspace, named bookmark | Standard 3 options | Provenance-based (see Step 6) |
| Secondary workspace, no bookmark on working copy | Reduced 2 options (no local integrate) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or a tracked upstream bookmark (for example
`main` or `main@origin`). If it is not already known, ask: "This work
split from <your best guess> - is that correct?" Confirm before
integrating: integrating onto the wrong base is expensive to undo.

```bash
# Inspect recent history and bookmarks if you need a guess
jj log -r 'bookmarks() | @' --limit 30
jj bookmark list
```

## Step 4: Present Options

**Default workspace and named-bookmark secondary workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Integrate onto <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**Unnamed working copy (no local bookmark) — present exactly these 2 options:**

```
Implementation complete. You're on a working copy without a bookmark (externally managed workspace).

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

### Option 1: Integrate Locally

```bash
# Get default workspace root for CWD safety (secondary workspaces must
# integrate from outside themselves when cleanup follows).
# `jj workspace list` prints lines like: default: /path/to/repo
DEFAULT_ROOT=$(jj --no-pager workspace list 2>/dev/null | awk -F': ' '$1=="default"{print $2; exit}')
if [ -z "$DEFAULT_ROOT" ] || [ ! -d "$DEFAULT_ROOT" ]; then
  # Fallback: path not under .worktrees/ or worktrees/, else stay put
  DEFAULT_ROOT="$WORKSPACE_ROOT"
fi
cd "$DEFAULT_ROOT"

# Ensure base is up to date, then integrate the feature bookmark
jj git fetch
jj new <base-bookmark>
# Rebase the feature stack onto latest base when it has diverged
jj rebase -b <feature-bookmark> -o <base-bookmark>
# Create a merge-style working copy with both parents, then move the base
# bookmark forward (or squash the feature range into base if the repo
# prefers a linear history — follow local convention from jj log)
jj new <base-bookmark> <feature-bookmark>
# After verifying the integrated tree (tests below), advance base:
jj bookmark move <base-bookmark> --to @
# Or for linear history instead of a merge change:
# jj bookmark move <base-bookmark> --to <feature-bookmark>

# Verify tests on integrated result
<test command>
```

If tests fail on the integrated result: stop, leave the workspace and
bookmark in place, and investigate — nothing has been pushed, so the
integration is local and recoverable. You can `jj undo` the recent
operations if needed.

Once the integrated result is green: clean up the secondary workspace
(Step 6), then delete the feature bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

### Option 2: Push and Create PR

Ensure the working-copy changes have descriptions before push (see
**Change descriptions** above). Then:

```bash
# Named bookmark already on the stack:
jj git push --bookmark <feature-bookmark>

# From an unnamed working copy, create a bookmark then push:
# jj bookmark create <new-bookmark> -r @-   # or -r @ if @ holds the work
# jj git push --bookmark <new-bookmark>

# Or let jj generate a bookmark from a change:
# jj git push --change @-   # or -c @-
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — `gh` if available, or the creation URL most forges print when you
push — following the repo's PR template and conventions if present, and
report the URL to your human partner.

```bash
# GitHub example (gh OK; set GIT_DIR when the repo is not colocated):
# GIT_DIR=$(jj git root) gh pr create --base <base-bookmark> --head <feature-bookmark>
```

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping bookmark <name>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Bookmark <name>
- All changes: <change-id list from jj log>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
# Move to default workspace before tearing down a secondary one
cd "$DEFAULT_ROOT"
```

Then clean up the secondary workspace (Step 6). Abandon the feature
changes if they should not remain reachable, then delete the bookmark:

```bash
# Optional: abandon the feature range relative to base (destructive)
# jj abandon '<base-bookmark>..<feature-bookmark>'
jj bookmark delete <feature-bookmark>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed directory to the
default workspace root when a secondary workspace is involved — workspace
removal must run from outside that workspace — and use the
`WORKSPACE_ROOT` / `WORKSPACE_PATH` values captured in Step 2, from before
that directory change.

**If this is the default workspace only:** No secondary workspace to clean
up. Done.

**If `WORKSPACE_PATH` is under `.worktrees/` or `worktrees/`:** This skill
created this workspace — we own cleanup:

```bash
# Forget the jj workspace registration, then remove the directory
jj workspace forget <workspace-name>
rm -rf "$WORKSPACE_PATH"
```

Discover `<workspace-name>` from `jj workspace list` (first column) for the
path matching `$WORKSPACE_PATH`.

**If removal is refused** or the directory still has files that exist
nowhere else — undescribed plans, notes, or scratch work. Never delete
those on your own initiative. Show your human partner what is at stake and
ask:

```bash
jj -R "$WORKSPACE_PATH" status
# Also surface untracked files under the workspace path:
ls -la "$WORKSPACE_PATH"
# Scratch or notes may live under the workspace-local temp dir:
ls -la "$WORKSPACE_PATH/.tmp" 2>/dev/null || true
```

```
Workspace cleanup blocked — these files may be lost:

<file list>

1. Describe/commit them onto <bookmark> before cleanup
   (jj describe / jj commit with a message composed from the standards above)
2. Move them into <default workspace root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice, then forget the workspace and remove the directory.

For option 1 (describe before cleanup):

```bash
cd "$WORKSPACE_PATH"
# Based on https://go.dev/wiki/CommitMessage and past messages in `jj log`
jj describe -m "<message composed from the standards above>"
# or: jj commit -m "<message composed from the standards above>"
```

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Cleanup Bookmark |
|--------|-----------|------|----------------|------------------|
| 1. Integrate locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (delete) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "Cleanup blocked — force-delete is just finishing" | Blocked cleanup means files may exist only in that workspace. Force-deleting destroys them permanently. Show your human partner and ask. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Integrating onto the wrong base is expensive to undo. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
