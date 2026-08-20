---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests → Identify revisions and workspace → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop — the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Identify the Work

Run:

```bash
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list
jj status
jj log -r '::@'
jj bookmark list --all-remotes
```

Record the current workspace name from `jj workspace list`, the revision that
contains the completed work, and any bookmark that should identify it. Jujutsu
has no active bookmark: a bookmark pointing at or below `@` does not by itself
prove which line of work is being completed.

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the bookmark's tracked remote. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before integrating: advancing the wrong base is expensive to undo.

Inspect every revision in `<base-bookmark>..<work-revision>` for a meaningful
description. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and the existing history take precedence; for Go repositories, keep descriptions compatible with Go quality conventions. Edit any inadequate description with `jj describe <revision>`; do not impose a fixed description syntax or stock wording.

## Step 3: Classify the Workspace

Use `WORKSPACE_ROOT` and `jj workspace list` to determine ownership:

| State | Cleanup |
|-------|---------|
| Sole workspace | No workspace registration or directory to clean up |
| Additional workspace under `.tmp/` | Tool-created; eligible for confirmed cleanup |
| Any other additional workspace | Externally managed; leave in place |

Capture the current workspace name and root now. Cleanup must be initiated from
another workspace after all repository operations are complete.

If temporary storage is needed, use `$(jj workspace root)/.tmp`. If the
workspace root cannot be determined, use the local `.tmp` directory. Do not use
system-wide temporary directories or global temporary-file facilities.

## Step 4: Present Options

Present exactly these three options:

```
Implementation complete. What would you like to do?

1. Integrate the work into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

First update the remote state and inspect the base bookmark. Use the repository's
configured fetch remote, or name the intended remote when the repository has
more than one:

```bash
jj git fetch --remote <remote>
jj bookmark list <base-bookmark> --all-remotes
```

If the base bookmark is conflicted or did not advance to the intended remote
target, stop and resolve that condition before integration.

Rebase the completed line of work onto the updated base and then advance the
base bookmark to its head:

```bash
jj rebase -r '<base-bookmark>..<work-revision>' -o <base-bookmark>
jj bookmark move <base-bookmark> --to <work-revision>

# Verify tests on the integrated result
<test command>
```

Use the recorded work revision's stable change ID after the rebase, not an
assumed revision symbol.
If the rebase produces conflicts, resolve them and verify the resulting diff
before testing.

If tests fail on the integrated result: stop, leave the workspace and bookmarks
in place, and investigate — nothing has been pushed, so the integration is
local and recoverable through `jj op log` and a carefully selected `jj undo`.

Once the integrated result is green, delete the now-redundant work bookmark if
one exists, then clean up the workspace according to Step 6:

```bash
jj bookmark delete <work-bookmark>
```

Do not delete a bookmark that is also the base bookmark or still identifies
work that was not integrated.

### Option 2: Push and Create PR

If the work already has a bookmark, move it to the completed revision and push
it. If it has no bookmark, choose a repository-appropriate name and push the
revision under that name:

```bash
jj bookmark move <work-bookmark> --to <work-revision>
jj git push --remote <remote> --bookmark <work-bookmark>

# Without an existing bookmark:
jj git push --remote <remote> --named <new-bookmark>=<work-revision>
```

Then create the pull/merge request against `<base-bookmark>` with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions except
for creator, model, harness, badge, attribution, and byline identification
fields, and report the URL to your human partner.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping revision <revision> with bookmark <bookmark-or-none>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Show the exact revisions selected by
`<base-bookmark>..<work-revision>` and confirm first:

```
This will abandon:
- Bookmark: <bookmark-or-none>
- Revisions: <revision list>
- Tool-created workspace registration and directory, if applicable: <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. Then abandon only the displayed revisions
and delete the work bookmark if one exists:

```bash
jj abandon '<base-bookmark>..<work-revision>'
jj bookmark delete <work-bookmark>
```

Jujutsu operations remain recoverable through the operation log, but that does
not make deleted workspace-only files recoverable. Continue with Step 6 only
for a tool-created workspace.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers must perform cleanup from outside the
workspace and use the workspace name and `WORKSPACE_ROOT` captured in Step 2.

**If this is the sole workspace:** no workspace cleanup is needed.

**If `WORKSPACE_ROOT` is under `.tmp/`:** inspect the
workspace before deleting anything:

```bash
jj -R "$WORKSPACE_ROOT" --ignore-working-copy status
jj -R "$WORKSPACE_ROOT" --ignore-working-copy diff --summary -r @
find "$WORKSPACE_ROOT" -mindepth 1 -print
```

Jujutsu snapshots eligible working-copy files automatically, while ignored or
explicitly untracked files may exist only on disk. The complete filesystem
listing above is therefore required. The workspace may hold files that exist
nowhere else — plans, notes, or scratch work. Never delete them on your own
initiative. Show your human partner what is at stake and ask:

```
Workspace cleanup found files that may exist only in this workspace:

<file list>

1. Preserve them in <work-revision> before cleanup
2. Move them into <main workspace root>
3. Delete them (unrecoverable)

Which?
```

If workspace-only files need to be preserved in a revision, track only the
intended files if necessary. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and the existing history take precedence; for Go repositories, keep descriptions compatible with Go quality conventions. Describe the resulting revision with `jj describe <revision>`, and return to the relevant integration or discard step before cleanup.

Carry out the choice, then forget and remove the workspace.

After confirmation, change to another workspace, forget the workspace by its
captured name, and only then delete its directory:

```bash
cd <other-workspace-root>
jj workspace forget <workspace-name>
rm -rf -- "$WORKSPACE_ROOT"
```

`jj workspace forget` removes only the repository registration; it does not
touch files on disk. Do not substitute a guessed workspace name or path.

**Otherwise:** the host environment owns this workspace. Leave it in place. If
the platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Rebase and advance base | Push | Keep workspace | Delete work bookmark |
|--------|--------------------------|------|----------------|----------------------|
| 1. Integrate locally | yes | no | only if externally managed | yes, if redundant |
| 2. Create pull request | no | yes | yes | no |
| 3. Keep as-is | no | no | yes | no |
| Discard (explicit request only) | no | no | only if externally managed | yes, if present |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this work — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment and workspace deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only tool-created workspaces under `.tmp/`. Everything else belongs to the host. |
| "Workspace cleanup found files — deletion is just finishing the cleanup" | Those files may exist only in that workspace. Deletion destroys them permanently. Show your human partner and ask. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the revision relationship or ask. Advancing the wrong bookmark is expensive to undo. |
| "The push was rejected — bypassing safety checks will fix it" | Fetch the remote state and resolve bookmark conflicts; override safety only on your human partner's explicit request. |
