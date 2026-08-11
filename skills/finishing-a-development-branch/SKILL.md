---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Bookmark

## Overview

**Core principle:** Verify tests -> Detect environment -> Present options -> Execute choice -> Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop; the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

```bash
# Capture now, while still inside the workspace. Cleanup may later forget it.
CURRENT_COMMIT=$(jj log -r @ --no-graph -T 'commit_id ++ "\n"')
jj workspace list -T 'name ++ "\t" ++ target.commit_id() ++ "\n"'
WORKSPACE_ROOT=$(jj workspace root)
jj bookmark list
jj log -r '@ | @-'
```

Identify the current workspace as the unique `jj workspace list` entry whose
target commit equals `CURRENT_COMMIT`, record its name, and confirm that `jj
workspace root --name <workspace-name>` resolves to the same `WORKSPACE_ROOT`.
If the match is absent or ambiguous, stop and resolve the identity; do not infer
it from whether `.jj` is a file or directory.

Determine cleanup ownership only from provenance established when the workspace
was created. A matching creation record at
`<owner-root>/.tmp/workspaces/.rocketclaw-owned/<workspace-name>` must name this
workspace, its exact destination, and the owner repository root. Capture that
record's path. The default owned destination from the workspace skill is
`<owner-root>/.tmp/workspaces/<workspace-name>`. A path
under that directory is not evidence by itself. Without a matching creation
record, classify the workspace as externally managed and never forget or delete
it. The primary workspace is likewise not cleanup-owned.

Determine the feature tip before identifying or moving a bookmark. If `@` is an
empty, undescribed, single-parent working-copy change created by finalizing the
completed feature, and the completion record and graph show that `@-` is the
completed change, set `FEATURE_TIP=@-`. Otherwise set `FEATURE_TIP=@`. Confirm
that its tree is the tree tested in Step 1. Do not describe or bookmark the fresh
empty `@`, and do not create another empty change merely to finish this workflow.

Determine the feature bookmark from the plan, conversation, or bookmarks on the
current stack. A JJ bookmark does not automatically advance with new changes.
Before treating it as the feature bookmark, confirm that moving it to
`FEATURE_TIP` is intended. If several bookmarks are plausible, ask rather than
guessing.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Feature bookmark identified | Standard 3 options | Creation-provenance based (see Step 6) |
| No feature bookmark identified | Reduced 2 options (no local merge) | Creation-provenance based (see Step 6) |

If temporary files are required during this workflow, use
`$(jj workspace root)/.tmp`. The repository-root `.tmp/` is ignored. Use `.tmp`
relative to the current directory only when `jj workspace root` fails because
there is no JJ repository. If the repository-local directory cannot be created,
stop rather than silently changing locations. Do not use an OS-global temporary
directory.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from, usually named in the plan,
the conversation, or the bookmark's tracked remote. If it is not already known,
inspect the graph with `jj log`, then ask: "This work split from <your best
guess> - is that correct?" Confirm before merging; merging into the wrong base
is expensive to undo.

## Step 4: Present Options

**Workspace with a feature bookmark: present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**No feature bookmark: present exactly these 2 options:**

```
Implementation complete. This work has no feature bookmark.

1. Push under a new bookmark and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Present the applicable menu exactly as written: concise, with every option from
the list above. Discarding the work happens only in response to your human
partner explicitly asking for it (see "If your human partner asks to discard the
work" below). Wait for their answer; the integration decision is theirs.

## Step 5: Execute Choice

### Before Push or Merge

The tested feature revision is `FEATURE_TIP`, selected in Step 2. Use `jj log -r
'<base-bookmark>..<feature-tip>'` to inspect the descriptions of every feature
change that will be pushed or merged. Fill any empty description on those
changes, but not on a fresh working-copy `@`, with a neutral `<description>`.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and the syntax used in history take precedence.
Do not impose a fixed type, scope, subject, or body template. Update descriptions
with `jj describe -r <revision> -m "<description>"`. When a feature bookmark
exists, explicitly move it to the feature tip; bookmarks do not auto-advance:

```bash
jj bookmark move <feature-bookmark> --to <feature-tip>
```

If the bookmark cannot move forward to the feature tip, stop and inspect the
graph. Do not use `--allow-backwards` unless your human partner explicitly
approves a backward or sideways move.

### Option 1: Merge Locally

Update remote state, then explicitly fast-forward the local base bookmark. Do
not substitute a rebase for the requested merge:

```bash
jj git fetch --remote origin
jj bookmark move <base-bookmark> --to <base-bookmark>@origin
```

If the base bookmark cannot move forward, stop and resolve the divergence. Then
compose a merge description using a neutral `<merge-description>` placeholder.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and the syntax used in history take precedence;
do not impose a fixed message template.

Create a true multi-parent merge change and verify that it has both the updated
base and tested feature as parents:

```bash
jj new <base-bookmark> <feature-bookmark> -m "<merge-description>"
jj log -r 'parents(@)'

# Verify tests on the merge change
<test command>
```

Confirm `parents(@)` contains both distinct intended parents. If JJ did not
create that two-parent merge, stop; do not advance either bookmark.

If the tests fail on the merge change: stop, leave the workspace and bookmarks
in place, and investigate. Nothing has been pushed, so the merge is local and
recoverable with JJ's operation log.

Once the merge change is green, explicitly advance the base bookmark to it,
because creating a change does not advance bookmarks:

```bash
jj bookmark move <base-bookmark> --to @
```

Forget the local feature bookmark before workspace cleanup. `forget` performs
local bookmark cleanup without scheduling remote deletion:

```bash
jj bookmark forget <feature-bookmark>
```

Then clean up the workspace (Step 6).

### Option 2: Push and Create PR

For work with a feature bookmark, the preflight above has moved it to the tested
revision:

```bash
jj git push --remote origin --bookmark <feature-bookmark>
```

For work without a feature bookmark, create and push one directly at the tested
revision:

```bash
jj git push --remote origin --named <new-bookmark>=<feature-tip>
```

Then create the pull/merge request against `<base-bookmark>` with the forge's
tooling, using its CLI if available or the creation URL most forges print when
you push. Follow the repository's PR template and conventions, and report the
URL to your human partner.

Keep the workspace; your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping bookmark <name>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work
away. Use the `FEATURE_TIP` selected in Step 2, identify the exact revset with
`jj log -r '<base-bookmark>..<feature-tip>'`, and confirm first:

```
This will permanently abandon:
- Bookmark <name>
- All changes: <change-list>
- Workspace registration <workspace-name>
- Workspace directory at <path>

Type 'discard' to confirm.
```

Include the workspace registration and directory lines only when the creation
provenance in Step 2 authorizes both operations; otherwise omit them. Wait for
the exact confirmation. When it arrives, abandon only the listed changes. When
Always use `--retain-bookmarks` so `jj abandon` cannot silently delete any
bookmark that was not identified and confirmed above. When a feature bookmark
exists, forget that confirmed bookmark deliberately without scheduling remote
deletion:

```bash
jj abandon --retain-bookmarks '<base-bookmark>..<feature-tip>'
jj bookmark forget <feature-bookmark>
```

When no feature bookmark exists, keep `--retain-bookmarks` and omit only the
`jj bookmark forget` command. Then perform Step 6.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Use only the workspace name, `WORKSPACE_ROOT`, owner root, and
cleanup ownership captured from matching creation provenance in Step 2.

**If there is no matching creation provenance:** The primary or externally
managed workspace is not owned by this workflow. Leave both its JJ registration
and directory in place. If the platform provides a workspace-exit tool, use it.

**If matching creation provenance grants cleanup ownership:** Re-verify that the
captured name still resolves to the captured root. For the default workspace-skill
location, also verify the exact root is
`<owner-root>/.tmp/workspaces/<workspace-name>`. Any mismatch revokes cleanup
authorization; stop without forgetting or deleting anything.

Workspace registration and filesystem removal are separate operations. First
move to the captured owner repository's primary workspace (or another registered
workspace outside `WORKSPACE_ROOT`) and verify `jj workspace root` there. Never
try to forget the workspace while the shell is inside it. Then forget only the
captured registration:

```bash
jj workspace forget <workspace-name>
```

After that succeeds, delete only the exact captured root authorized by the
creation record, then remove the exact captured provenance record:

```bash
rm -rf -- "$WORKSPACE_ROOT"
rm -f -- "<captured-provenance-record>"
```

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
| 1. Merge locally | yes, multi-parent | - | unless creation provenance owns cleanup | yes, forget locally |
| 2. Create PR | - | yes, via `jj git` | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | unless creation provenance owns cleanup | yes, forget locally |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "Rebasing onto the base is close enough" | The promised local merge is a real multi-parent JJ change. Do not replace it with a rebase. |
| "The bookmark probably followed my commits" | JJ bookmarks do not auto-advance. Explicitly move the feature bookmark to the tested revision and the base bookmark to the tested merge. |
| "They seem done with this feature; I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment and deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "Forgetting the workspace deletes its directory" | `jj workspace forget` only removes the registration. Directory deletion is a separate, provenance-gated operation. |
| "This path looks like one of ours" | Paths do not establish ownership. Clean up only the exact workspace named by matching creation provenance; everything else belongs to the host. |
| "The empty `@` needs a description before I finish" | A fresh empty working-copy change is not the completed feature. Use the verified feature tip, usually `@-`, and do not add or describe meaningless empty changes. |
| "The merged-result failure is probably flaky" | A failing merge result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected; forcing it will fix it" | A rejected push means the remote moved or JJ's safety checks failed. Fetch and investigate; rewrite remote state only on your human partner's explicit request. |
