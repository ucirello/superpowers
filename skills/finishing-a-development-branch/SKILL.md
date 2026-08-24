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

Jujutsu has no index, detached state, or active bookmark. The working copy is
the revision `@`; bookmarks are independent names that may point to it.

```bash
# Capture now, while still inside the workspace. Later steps may change CWD.
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_NAME=$(jj workspace list -T 'if(target.current_working_copy(), name ++ "\n")')
WORK_REVSET=@
if [ -z "$(jj diff -r @ --summary)" ] && [ -z "$(jj log --no-graph -r @ -T 'description')" ]; then
  WORK_REVSET=@-
fi
WORK_REVISION=$(jj log --no-graph -r "exactly($WORK_REVSET, 1)" -T 'commit_id ++ "\n"')
WORK_BOOKMARKS=$(jj log --no-graph -r "$WORK_REVISION" -T 'local_bookmarks.map(|b| b.name()).join("\n") ++ "\n"')
```

If temporary files are needed, place them under `$(jj workspace root)/.tmp`;
if workspace-root lookup fails, use `.tmp`. Do not use a global temporary
directory.

If exactly one local bookmark points to `<work-revision>`, use it as `<work-bookmark>`. If
several do, ask which identifies this work. If none do, the work is an unnamed
revision and `<work-revision>` is the captured full commit ID. An empty,
undescribed `@` created after `jj commit` is skipped in favor of its single
parent.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Default workspace | Standard 3 options | No workspace to clean up |
| Workspace under `.rocketclaw/workspaces/` or `.workspaces/`, named bookmark | Standard 3 options | Provenance-based (see Step 6) |
| Other workspace, named bookmark | Standard 3 options | Externally managed — leave in place |
| Other workspace, unnamed revision | Reduced 2 options (no local merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or visible in the revision graph. If it is not already
known, inspect `jj log -r 'fork_point(@ | trunk()) | @ | trunk()'`, make a best
guess, and ask: "This work split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Commit Descriptions

Whenever a step below needs a revision description, read repository guidance
and inspect the repository's existing descriptions first. Repository-local
syntax wins over Go guidance. Apply compatible Go guidance for a clear, concise
subject and an explanatory body when useful, but do not impose a fixed prefix,
type, scope, subject, body, or template.
Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
Compose a description for the actual change; do not use canned merge wording or
another fixed message. Apply it with `jj describe -r <revision>` so the editor
can preserve multiline text, or with `jj describe -r <revision> -m '<composed-description>'`.

## Step 4: Present Options

**Default or named-bookmark workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

**Externally managed workspace with an unnamed revision — present exactly these 2 options:**

```
Implementation complete. This is an unnamed revision in an externally managed workspace.

1. Push under a new bookmark and create a Pull Request
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

Determine the intended remote with `jj git remote list`; if more than one is
plausible, ask rather than assuming `origin`. Fetch first. A tracked base bookmark advances on fetch when only the remote has
moved; stop and resolve it if the bookmark becomes conflicted.

```bash
jj git fetch --remote <remote>
jj bookmark list <base-bookmark>

# Create a merge revision with the updated base first and the work second.
jj new <base-bookmark> <work-revision>
```

Compose and apply the merge revision's description according to **Commit
Descriptions**, then verify tests on the merge result:

```bash
jj describe -r @
MERGE_REVISION=$(jj log --no-graph -r @ -T 'commit_id ++ "\n"')
<test command>
```

If tests fail on the merged result: stop, leave the workspace, merge revision,
and bookmarks in place, and investigate — nothing has been pushed, so the merge
is local and recoverable through Jujutsu's operation log.

Once the merged result is green, advance the base bookmark to the merge
revision:

```bash
jj bookmark move <base-bookmark> --to "$MERGE_REVISION"
```

Clean up the workspace (Step 6), then forget `<work-bookmark>` if the work had
one:

```bash
jj bookmark forget <work-bookmark>
```

`bookmark forget` is intentional: unlike `bookmark delete`, it does not
schedule deletion of a same-named remote bookmark.

### Option 2: Push and Create PR

Determine the intended remote with `jj git remote list`; if more than one is
plausible, ask rather than assuming `origin`.

Before pushing, ensure every revision in `<base-bookmark>..<work-revision>` has
a non-empty, repository-conformant description. Compose any missing description
according to **Commit Descriptions**; never bypass this with
`--allow-empty-description`.

For named work:

```bash
jj git push --remote <remote> --bookmark <work-bookmark>
```

For an unnamed revision, ask for a bookmark name, then create and push it in one
operation:

```bash
jj git push --remote <remote> --named <new-bookmark>=<work-revision>
```

Then create the pull/merge request against `<base-bookmark>` with the forge's
tooling — its CLI if one is available, or the creation URL most forges print
when you push — following the repo's PR template and conventions if present,
and report the URL to your human partner. `gh` may be used for GitHub.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

For named work, report: "Keeping bookmark <name>. Workspace preserved at <path>."
For unnamed work, report: "Keeping revision <change-id>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Show the revisions selected by
`jj log -r '<base-bookmark>..<work-revision>'` and confirm first:

```
This will abandon:
- Bookmark <name>, if present
- Revisions: <revision-list>
- Workspace at <path>, if owned by this workflow

Non-versioned files removed with the workspace are not recoverable.
Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, forget the bookmark without
propagating a remote deletion if one exists:

```bash
jj bookmark forget <work-bookmark>
```

Skip that command for unnamed work. Then abandon the work revisions:

```bash
jj abandon '<base-bookmark>..<work-revision>'
```

`jj abandon` remains recoverable through the operation log until repository
garbage collection. Then clean up the workspace (Step 6).

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Use the `WORKSPACE_ROOT` and `WORKSPACE_NAME` values captured in
Step 2.

**If this is the default workspace:** No workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `.rocketclaw/workspaces/`, `.workspaces/`,
`.tmp/workspaces/`, or the sibling `rocketclaw-workspaces/` location:**
This workflow owns cleanup. Jujutsu snapshots trackable working-copy files
automatically, but ignored and otherwise non-versioned files are not revisions.
Before deleting anything:

```bash
jj status
jj file list
```

Inventory the workspace's filesystem, including ignored files, and compare it
with `jj file list`. Exclude only Jujutsu's `.jj` metadata and temporary
inventory files under `$(jj workspace root)/.tmp` (or `.tmp` if root lookup
fails).

**If any non-versioned files exist:** they exist nowhere in Jujutsu — plans,
notes, build output, or scratch work. Show your human partner what is at stake
and ask:

```
Workspace removal would delete these non-versioned files:

<file list>

1. Add them to an appropriate revision before cleanup
2. Move them into the default workspace
3. Delete them (unrecoverable)

Which?
```

Carry out the choice and repeat the inventory. Only after no files are at risk,
change to the default workspace, forget the workspace registration, and remove
its directory:

```bash
DEFAULT_ROOT=$(jj workspace root --name default)
cd "$DEFAULT_ROOT"
jj workspace forget "$WORKSPACE_NAME"
rm -rf -- "$WORKSPACE_ROOT"
```

Never remove the default workspace. If no workspace named `default` exists,
use another preserved workspace returned by `jj workspace list` as
`DEFAULT_ROOT`; do not use the workspace being removed.

**Otherwise:** The host environment owns this workspace — leave it in place. If
your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
| 1. Merge locally | yes | - | - | yes (forget locally) |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (forget and abandon revisions) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the revision you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment and workspace deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only the captured workspace in one of the workflow-owned locations listed in Step 6. Everything else belongs to the host. |
| "Jujutsu snapshots everything, so filesystem deletion is safe" | Ignored and otherwise non-versioned files can exist only in that workspace. Inventory them and ask before deletion. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Revisions, bookmarks, and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — forcing it will fix it" | A rejected push means the remote moved or a safety check failed. Fetch and investigate; override safety only on your human partner's explicit request. |
