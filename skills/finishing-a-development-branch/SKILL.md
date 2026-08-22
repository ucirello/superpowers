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

```bash
WORKSPACE_PATH=$(jj workspace root)
jj workspace list
jj bookmark list --all-remotes
jj log -r '@ | bookmarks()'
```

Record the current workspace name from `jj workspace list`. Record whether this
workspace was created by the isolation workflow and its path. Record `@` as the
feature revision; an existing feature bookmark is only a publication pointer
and may lag behind the working-copy change. Do not infer a current bookmark:
Jujutsu bookmarks are pointers, not checked out branches. Determine `<remote>`
from the tracked base bookmark or repository configuration rather than assuming
a fixed remote name. If cleanup will be
needed, also retain the path of another workspace from the setup or harness
context; `jj workspace list` does not print filesystem paths.

The workspace path determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Created by this workflow under `.tmp/workspaces/`, `.rocketclaw/workspaces/`, `.worktrees/`, or `worktrees/` | Standard 3 options | Provenance-based (see Step 6) |
| Any other workspace | Standard 3 options | Externally managed; leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from, usually named in the
plan, the conversation, or the remote bookmark relationship. If it is not
already known, ask: "This work split from <your best guess> - is that
correct?" Confirm before integrating: moving the wrong base bookmark is
expensive to undo.

Inspect every change in `<base-bookmark>..<feature-revision>` with `jj log`
and ensure each has a useful description before presenting the menu. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax found at runtime wins. Where compatible with those local standards, use a short, clear subject that completes "this change modifies the project to ..."; add a blank line and a body explaining what changed and why when the subject alone is insufficient, and keep ordinary body text near 72 columns. Do not impose fixed prefixes, types, scopes, or canned examples.

For any description that needs to be added or corrected, use:

```bash
jj describe -r <revision> -m "<message composed from the standards above>"
```

## Step 4: Present Options

**Present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your human
partner explicitly asking for it (see "If your human partner asks to discard the work" below).
Wait for their answer; the integration decision is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

```bash
# Update the configured remote view, rebase the feature line, then advance the base.
jj git fetch --remote <remote>
jj rebase -s 'roots(<base-bookmark>..<feature-revision>)' -o <base-bookmark>
jj status
jj bookmark move <base-bookmark> --to <feature-revision>

# Verify tests on the integrated result.
<test command>
```

If the rebase produces conflicts, stop before moving the base bookmark and
resolve them. If tests fail on the integrated result, stop, leave the
workspace and bookmarks in place, and investigate. Nothing has been pushed,
so the operation is local and recoverable with Jujutsu's operation log.

Once the integrated result is green, forget the local feature bookmark
without scheduling a remote deletion, then clean up the workspace (Step 6).
Skip this command if the work did not have a feature bookmark:

```bash
jj bookmark forget <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
# If needed, create a bookmark at the feature revision first.
jj bookmark create <feature-bookmark> -r <feature-revision>
jj git push --remote <remote> --bookmark <feature-bookmark>
```

If the feature bookmark already exists but does not point to the feature
revision, use `jj bookmark move <feature-bookmark> --to <feature-revision>`
instead of creating it. A successful first push automatically tracks the
remote bookmark.

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the workspace; your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping <bookmark-or-revision>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Local bookmark <name>, if present
- All changes: <change-list>
- Workspace at <path>, if owned by this workflow

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
jj bookmark forget <feature-bookmark>  # Skip if there is no feature bookmark.
jj abandon <change-ids-from-confirmation>
```

Resolve and show the exact change IDs from
`<base-bookmark>..<feature-revision>` before confirmation, because forgetting
the bookmark may make the bookmark name unavailable. Then clean up the
workspace (Step 6). Never use a broader revset than the confirmed list.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Use the `WORKSPACE_PATH` and workspace name captured
in Step 2.

**If this workspace was created by this workflow and `WORKSPACE_PATH` is under
`.tmp/workspaces/`, `.rocketclaw/workspaces/`, `.worktrees/`, or
`worktrees/`:** This workflow owns cleanup. First inspect the workspace from
an existing workspace that will remain:

```bash
jj -R "$WORKSPACE_PATH" status
```

Jujutsu snapshots tracked working-copy files, but ignored or explicitly
untracked files may exist only on disk. Inspect the filesystem, including
ignored files, before deletion. If anything is not represented by the
confirmed feature changes, show your human partner what is at stake and ask:

```
Workspace cleanup would remove these local-only files:

<file list>

1. Preserve them in the current change before cleanup
2. Move them into <primary workspace root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice. From the other workspace path retained during setup,
forget the workspace registration and then remove its directory from disk.
If no other workspace path is known, leave cleanup to the user rather than
guessing:

```bash
cd "$PERSISTENT_WORKSPACE_PATH"
jj workspace forget <workspace-name>
rm -rf -- "$WORKSPACE_PATH"
```

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Cleanup Bookmark |
|--------|-----------|------|----------------|------------------|
| 1. Integrate locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (abandon) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature; I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale; I'll clean it too" | Clean up only workspaces under `.tmp/workspaces/`, `.rocketclaw/workspaces/`, `.worktrees/`, or `worktrees/`. Everything else belongs to the host. |
| "The files are probably snapshotted, so deletion is safe" | Ignored or explicitly untracked files may exist only in that workspace. Inspect, show your human partner, and ask. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Moving the wrong base is expensive to undo. |
| "The push was rejected; forcing it will fix it" | A rejected push means the remote moved. Run `jj git fetch`, investigate, and resolve the bookmark state; never bypass the safety check without your human partner's explicit request. |
