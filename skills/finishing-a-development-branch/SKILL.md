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
WORKSPACE_PATH=$(jj workspace root)
jj workspace list
jj status
jj log -r '@ | @-'
jj bookmark list -r '::@'
```

Determine `FEATURE_REV` from the completed work, not from a fixed relative
position. If `@` contains the completed work, use `@`; if the preceding
workflow left an empty `@` after recording the completed work, use `@-`.
Confirm with `jj diff -r <feature-revision>`.

Determine `FEATURE_BOOKMARK`, when needed, from the plan, conversation, or
bookmarks in `::<feature-revision>`. Do not assume a bookmark points directly
to the completed revision: Jujutsu does not automatically advance bookmarks.
Ask if more than one non-base bookmark could represent the work.

This determines how publishing and cleanup work:

| State | Menu | Cleanup |
|-------|------|---------|
| Feature revision has a known local bookmark | Standard 3 options | Provenance-based (see Step 6) |
| Feature revision has no feature bookmark | Standard 3 options; create one only for publishing | Provenance-based (see Step 6) |
| Multiple bookmarks could represent the work | Stop and ask which bookmark represents it | Do not clean up until clarified |

Record the current workspace name from `jj workspace list`, the workspace path
as `WORKSPACE_PATH`, the completed revision as `FEATURE_REV`, and the selected
bookmark, when present, as `FEATURE_BOOKMARK`.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the tracked remote bookmark. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the change as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Merge Locally

Use only the applicable integration path. Determine ancestry with `jj log -r
'<base-bookmark>::<feature-revision>'`; do not create a two-parent revision for
a fast-forward. Before composing or editing the integration revision's
description, read repo-local instructions and run the repository-prescribed
`git log` command, or plain `git log` when none is prescribed.
Repo-local instructions and the syntax used in `git log` always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Describe the reason for the integration and preserve the semantic content of the integrated work; derive the form from the repository rather than using a fixed message, type, scope, prefix, template, or example.

```bash
# Update the remote view first. A tracked base bookmark advances automatically.
jj git fetch --remote origin

# If <base-bookmark> is an ancestor of <feature-revision>, fast-forward it.
jj bookmark move <base-bookmark> --to <feature-revision>

# If the histories diverged, create a two-parent integration revision instead.
jj new <base-bookmark> <feature-revision>
jj describe
jj bookmark move <base-bookmark> --to @

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the workspace and bookmarks in
place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the integrated result is green: forget the feature bookmark locally when
one exists, then
clean up the workspace (Step 6). Use `forget`, not `delete`, so cleanup does not
schedule deletion of an existing remote bookmark:

```bash
jj bookmark forget <feature-bookmark>  # only when a feature bookmark exists
```

### Option 2: Push and Create PR

```bash
# Existing feature bookmark: first move it to the completed revision.
jj bookmark move <feature-bookmark> --to <feature-revision>
jj git push --remote origin --bookmark <feature-bookmark>

# Work without a feature bookmark: create and push one at the completed revision.
jj git push --remote origin --named <new-bookmark>=<feature-revision>
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping change <revision> as-is. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Bookmark <name>
- All revisions: <revision-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
# Stop if another bookmark or workspace depends on a descendant of this range.
jj log -r '(<base-bookmark>..<feature-revision>):: & (bookmarks() | working_copies()) ~ (<base-bookmark>..<feature-revision>)'
jj log -r '<base-bookmark>..<feature-revision>'
jj bookmark forget <feature-bookmark>  # only when one exists
jj abandon '<base-bookmark>..<feature-revision>'
```

If the first command lists another bookmark or workspace revision, stop and
show the dependency; the original confirmation did not authorize rewriting
that work. Otherwise, clean up the workspace (Step 6).

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Use the workspace name and `WORKSPACE_PATH` captured
in Step 2.

**If `WORKSPACE_PATH` equals the destination recorded by the workspace-creation
workflow and that destination is under the owning workspace root's `.tmp/`
directory:** this workflow created the workspace, so we own cleanup. Verify
the recorded owning root and destination against `jj workspace list` and
`jj workspace root --name <workspace-name>`; never infer ownership from a
similar-looking path alone.
First inspect `jj status` and the workspace directory for ignored or otherwise
untracked scratch files. Jujutsu snapshots tracked working-copy changes
automatically, but ignored files may exist only there.

If there are no such files, change to the owning workspace, forget the
workspace registration from there, and remove only the captured path:

```bash
cd <owning-workspace-root>
jj workspace forget <workspace-name>
rm -rf -- "$WORKSPACE_PATH"
```

Never remove a path outside that repo-local namespace. If Jujutsu is
unavailable while selecting a temporary location, use the current directory's
`.tmp/` as the local fallback; never use an OS-global temporary directory.

**If scratch files are present:** the workspace holds files that exist nowhere
else — plans, notes, or ignored work. Never delete them on your own initiative.
Show your human partner what is at stake and ask:

```
Workspace cleanup found files that are not in a revision:

<file list>

1. Include them in <bookmark> before cleanup
2. Move them into <owning workspace root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice, then forget and remove the workspace.

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (abandon) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only the captured workspace at its recorded path under the owning root's `.tmp/`. Everything else belongs to the host. |
| "The files are probably reproducible — `rm -rf` is just finishing cleanup" | Ignored files may exist only in that workspace. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — I'll bypass the safety check" | A rejected push means the remote moved. Run `jj git fetch --remote <remote>`, resolve the bookmark conflict, and retry. |
