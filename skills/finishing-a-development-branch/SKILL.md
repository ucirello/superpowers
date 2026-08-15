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
jj status
# Capture these while still inside the workspace. Later steps may operate
# from another workspace, but cleanup still needs these values.
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_NAME=$(jj workspace list --no-pager -T 'if(target.current_working_copy(), name ++ "\n")')
FEATURE_REVISION=$(jj log -r @- --no-graph -T 'commit_id ++ "\n"')
jj workspace list
jj bookmark list --revision "$FEATURE_REVISION"
```

Use `jj workspace list` to determine whether this repository has another
workspace from which integration and cleanup can safely run. Use
`jj bookmark list --revision "$FEATURE_REVISION"` to identify a feature
bookmark pointing to the completed revision. After `jj commit`, the finalized
content is at `@-`; `@` is the new empty working-copy revision. Jujutsu has no
active bookmark or detached HEAD. A bookmark gives the completed revision a
stable local name, but its captured commit ID is sufficient for local
integration.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Only one workspace | Standard 3 options | No secondary workspace to clean up |
| Multiple workspaces, owned path | Standard 3 options | Provenance-based (see Step 6) |
| Multiple workspaces, host-owned path | Standard 3 options | Leave in place |

## Step 3: Determine Base Bookmark and Remotes

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the feature bookmark's tracked remote. If it is
not already known, ask: "This work split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

Determine and confirm the remote that supplies the base bookmark and the
remote that should receive a push. They may differ. Infer them from tracked
bookmarks, repository configuration, the plan, or the conversation; ask if
either is ambiguous. Record them as `<base-remote>` and `<push-remote>` rather
than assuming a remote name.

## Step 4: Present Options

**Bookmarked work — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**Unbookmarked revision — present exactly these 3 options:**

```
Implementation complete. This revision has no feature bookmark.

1. Merge back to <base-bookmark> locally
2. Push under a new bookmark and create a Pull Request
3. Keep as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Merge Locally

Select another workspace from `jj workspace list` as the integration
workspace. If there is no other workspace, use the current workspace and do
not clean it up in Step 6. Then fetch and inspect the base bookmark before
integrating:

```bash
cd "<integration-workspace-root>"
jj git fetch --remote <base-remote>
jj status
jj log -r '<base-bookmark>|<base-bookmark>@<base-remote>|<feature-revision>'
```

Stop and resolve any conflicted bookmark or unexpected remote movement. If
the base bookmark is an ancestor of the feature revision, this is a
fast-forward integration: advance the base bookmark directly to the captured
feature revision. Do not try to edit a revision that is checked out in the
feature workspace from a second workspace.

```bash
jj bookmark set <base-bookmark> -r <feature-revision>
```

If the base and feature revisions have diverged, create a merge change with
both as parents, then advance the base bookmark to that merge change:

```bash
jj new <base-bookmark> <feature-revision>
jj describe
jj bookmark set <base-bookmark> -r @
```

At the `jj describe` composition site, inspect the repository's existing
change descriptions with `jj log` and infer its current conventions. Follow
the local style when it is clear; otherwise apply the Go guidance to the
specific merge's purpose and details. Do not impose a fixed prefix, type,
scope, capitalization, or subject syntax. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Then verify the integrated result in the workspace that holds it: use the
feature workspace for a fast-forward, or the integration workspace for a
merge change.

```bash
<test command>
```

If tests fail on the merged result: stop, leave the workspace and bookmarks
in place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the merged result is green: clean up the feature workspace (Step 6),
then, if one exists, forget the local feature bookmark without scheduling a
remote deletion. An unbookmarked revision integrates directly by its captured
commit ID and needs no bookmark:

```bash
jj bookmark forget <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
jj git push --remote <push-remote> --bookmark <feature-bookmark>
# For an unbookmarked revision, or when choosing a new bookmark for the PR:
jj git push --remote <push-remote> --named <new-bookmark>=<feature-revision>
```

A bookmark is required for push/PR behavior. The PR flow may use an existing
feature bookmark or choose a new bookmark name.

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

For bookmarked work, report: "Keeping bookmark <name>. Workspace preserved at <path>."
For unbookmarked work, report: "Keeping revision <feature-revision>. Workspace preserved at <path>."
A bookmark is required only if your human partner wants the kept revision to
have a stable local name.

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Bookmark <name>, if any
- All revisions: <revision-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. Before changing anything, record the exact
revision IDs in `<base-bookmark>..<feature-revision>`. When confirmation
arrives, forget the feature bookmark without scheduling a remote deletion:

```bash
cd "<integration-workspace-root>"
# If the completed revision has a feature bookmark:
jj bookmark forget <feature-bookmark>
```

Then clean up the feature workspace (Step 6) and abandon only the recorded
revisions:

```bash
jj abandon <recorded-revision-ids>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed to another
workspace when one exists and use the `WORKSPACE_ROOT` value captured in
Step 2, from before that directory change. They also use the captured
`WORKSPACE_NAME` when unregistering it.

**If this is the repository's only workspace:** There is no secondary
workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `.rocketclaw/workspaces/`, `.workspaces/`, or
`workspaces/`, or exactly matches the using-git-worktrees pattern
`.tmp/jj-workspace-$WORKSPACE_NAME-<numeric-pid>-<numeric-counter>/workspace`:**
We own cleanup. Do not treat any other `.tmp` path as owned. First inspect the
working-copy revision:

```bash
jj -R "$WORKSPACE_ROOT" status
jj -R "$WORKSPACE_ROOT" diff --summary -r @
```

If `@` contains changes that were not included in the integrated revision,
or files that exist nowhere else, never delete them on your own initiative.
Show your human partner what is at stake and ask:

```
Workspace cleanup found changes that were not integrated:

<file list>

1. Record them in a revision before cleanup
2. Move them into <integration workspace root>
3. Delete them (unrecoverable)

Which?
```

At the change-description composition site for option 1, inspect the
repository's existing change descriptions with `jj log` and infer its current
conventions. Follow the local style when it is clear; otherwise apply the Go
guidance to the specific change's purpose and details. Do not impose a fixed
prefix, type, scope, capitalization, or subject syntax. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Carry out the choice. Once the workspace contains nothing that would be
lost, explain that ignored files are not visible to `jj status` or `jj diff`
and ask for explicit confirmation before recursive deletion:

```
Workspace cleanup will recursively delete <path>. Ignored files may exist
there even though jj status and jj diff are clean.

Type 'cleanup' to confirm.
```

Wait for that exact confirmation. Then unregister the captured workspace name
and delete its directory from outside it:

```bash
jj workspace forget "$WORKSPACE_NAME"
rm -rf -- "$WORKSPACE_ROOT"
```

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
| 1. Merge locally | yes | - | - | yes, if any |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes, if any (abandon revisions) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.rocketclaw/workspaces/`, `.workspaces/`, `workspaces/`, or the exact owned `.tmp/jj-workspace-$WORKSPACE_NAME-<numeric-pid>-<numeric-counter>/workspace` pattern. Everything else belongs to the host. |
| "The working copy is already a revision, so cleanup cannot lose anything" | Ignored or otherwise unincluded files can still exist only in that workspace. Explicit human confirmation is required before recursive deletion even when JJ reports a clean workspace. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — overriding the remote will fix it" | A rejected push means the remote moved. Fetch, inspect, and resolve the bookmark state; do not bypass Jujutsu's push safety checks. |
