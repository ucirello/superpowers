---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests -> Detect environment -> Present options -> Execute choice -> Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests and Descriptions

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop; the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** identify the completed stack and its tip with `jj log`. Inspect every
revision in `<base-bookmark>..<tip-revision>` and ensure each meaningful revision has
an accurate, non-empty description before integration or push. Use `jj describe
<revision>` to edit a description; do not supply a canned description on the command
line. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
Runtime repository instructions and the repository-prescribed `git log` syntax
take precedence. Where compatible, keep the description clear and concise and
preserve useful rationale rather than merely restating the diff. Do not impose a
fixed message, prefix, type, scope, subject, body, or template. Then continue to
Step 2.

## Step 2: Detect Environment

```bash
# Capture now, while still inside the workspace; cleanup may run elsewhere.
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list -T 'name ++ "\t" ++ root ++ "\n"'
jj bookmark list
jj log -r '<base-bookmark>..<tip-revision>'
```

From the workspace-list row whose root matches `WORKSPACE_ROOT`, record the workspace
name as `WORKSPACE_NAME`. Also determine whether a local bookmark identifies the
completed tip. Jujutsu does not require a bookmark for local work, so an anonymous
change is normal and can still be integrated or pushed.

Under Git Bash or another Windows POSIX compatibility shell, normalize paths
returned by Jujutsu with `cygpath -u` before using them in POSIX filesystem
commands.

Resolve the base and tip to exactly one revision each, verify that the base is
an ancestor of the tip, and record the exact stack commit IDs in
`<reviewed-stack-revset>`, joined with `|`. This keeps later integration and
discard operations from widening the reviewed selection. Also record the tip's
stable change ID as `<tip-change-id>` before rewriting.

This determines how later commands and cleanup work:

| State | Push | Cleanup |
|-------|------|---------|
| Tip has a local bookmark | Push that bookmark | Provenance-based (see Step 6) |
| Tip is anonymous | Push it under a new bookmark name | Provenance-based (see Step 6) |
| Only one workspace is registered | Either push form | No additional workspace to clean up |

If the current working-copy revision is an empty child created after the final
described revision, `<tip-revision>` is normally `@-`, not `@`. Confirm from `jj log`
rather than assuming.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from, usually named in the plan, the
conversation, or the revision graph. If it is not already known, inspect `jj log` and
all remote bookmarks with `jj bookmark list --all-remotes`, then ask: "This work split from <your best guess> - is
that correct?" Confirm before integration; moving the wrong base bookmark is expensive
to untangle even though Jujutsu records the operation.

## Step 4: Present Options

Present exactly these 3 options:

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written: concise, with every option coming from the list
above. Discarding the work happens only in response to your human partner explicitly
asking for it (see "If your human partner asks to discard the work" below). Wait for
their answer; the integration decision is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

First update the remote view and inspect the resulting graph:

```bash
jj git fetch --remote <remote>
jj log -r '<base-bookmark>@<remote>..<tip-revision>'
jj bookmark list <base-bookmark>
```

If the local base bookmark has not advanced automatically to its tracked remote,
advance it only when the remote target is a descendant. If the bookmark is conflicted
or the targets diverged, stop and ask how to reconcile them; do not use
`--allow-backwards` as a shortcut.

```bash
jj bookmark move <base-bookmark> --to <base-bookmark>@<remote>
```

Rebase only the exact reviewed stack onto the updated base. Do not use `-b` or
`-s` here because either can select descendants outside that stack:

```bash
jj rebase -r '<reviewed-stack-revset>' -o <base-bookmark>
```

Resolve any conflicts before continuing. Verify the rebased tip and run the full test
suite on that result before moving the base bookmark. Create a new empty
working-copy child of the stable rebased tip so the checked-out tree is exactly
the tree being tested:

```bash
jj new 'exactly(<tip-change-id>, 1)'
jj log -r '<base-bookmark>..exactly(<tip-change-id>, 1)'
<test command>
```

If tests fail on the rebased result: stop, leave the workspace and bookmarks in place,
and investigate. Nothing has been pushed, and `jj op log` plus `jj undo` or
`jj op restore` preserve recovery options.

Once the rebased result is green, advance the base bookmark to the rebased tip, then
forget the local feature bookmark. `forget` removes the local name without scheduling
deletion of a similarly named remote bookmark.

```bash
jj bookmark move <base-bookmark> --to 'exactly(<tip-change-id>, 1)'
jj bookmark forget <feature-bookmark>
```

Skip the final command for an anonymous stack.
Then clean up the workspace (Step 6).

### Option 2: Push and Create PR

Ensure the bookmark points to the completed tip, then push only that bookmark. If the
tip is anonymous, create and track the requested remote bookmark as part of the push:

```bash
# Existing local bookmark:
jj bookmark move <feature-bookmark> --to <tip-revision>
jj git push --remote <remote> --bookmark <feature-bookmark>

# Anonymous tip:
jj git push --remote <remote> --named <new-bookmark>=<tip-revision>
```

If the push is rejected because the remote changed, run `jj git fetch --remote
<remote>`, inspect and reconcile the bookmark state, and retry. Do not bypass the
lease-style safety checks.

Then create the pull/merge request against `<base-bookmark>` with the forge's tooling,
following the repository's PR template and conventions, and report the URL to your
human partner. For GitHub, `gh` may need the backing repository path when the Jujutsu
repository is not colocated:

```bash
GIT_DIR=$(jj git root) gh pr create --base <base-bookmark> --head <pushed-bookmark>
```

Keep the workspace; your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

For a named tip, report: "Keeping bookmark <name>. Workspace preserved at <path>."
For an anonymous tip, report its change ID and workspace path instead.

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work away.
Show the exact revisions selected by `<reviewed-stack-revset>` with `jj log`,
then confirm first:

```
This will remove from the visible revision graph:
- Bookmark <name>, if present
- All listed revisions: <revision-list>
- Workspace registration and files at <path>, if this workflow owns it

Jujutsu operations may remain recoverable until operation data is garbage-collected.
Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, forget the local bookmark first so
no remote deletion is scheduled, then abandon the work revisions. Use the already
reviewed revset, and skip the first command for an anonymous stack:

```bash
jj bookmark forget <feature-bookmark>
jj abandon '<reviewed-stack-revset>'
```

Then clean up the workspace (Step 6).

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve the
workspace. Use the `WORKSPACE_ROOT` and `WORKSPACE_NAME` values captured in Step 2.

**If only one workspace is registered:** no additional workspace exists to clean up.
Done.

**If `WORKSPACE_ROOT` is under the recorded `.workspaces/<project>/` container
created by superpowers:using-jj-workspaces:** this workflow owns the workspace.
Before removing anything, inspect its working-copy revision:

```bash
jj -R "$WORKSPACE_ROOT" status
jj -R "$WORKSPACE_ROOT" diff --summary
```

The working-copy revision must be empty and conflict-free. Also inspect ignored files
that Jujutsu status does not report before deleting the directory. If there are
workspace-only changes or files, show your human partner what is at stake and ask:

```
Workspace cleanup would remove these workspace-only files or changes:

<file list>

1. Preserve them in a described change before cleanup
2. Move them into <primary workspace root>
3. Delete them (unrecoverable once operation data and filesystem recovery are gone)

Which?
```

If they choose to preserve the changes in a revision, use `jj describe <revision>`
rather than a fixed command-line message. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
Runtime repository instructions and the repository-prescribed `git log` syntax
take precedence. Where compatible, keep the description clear and concise and
preserve useful rationale rather than merely restating the diff. Do not impose a
fixed message, prefix, type, scope, subject, body, or template. Carry out the
choice and re-check status.

From a different registered workspace, record its root as
`OTHER_WORKSPACE_ROOT`, forget the owned workspace registration, then remove
only the captured owned directory:

```bash
jj -R "$OTHER_WORKSPACE_ROOT" workspace forget <workspace-name>
rm -rf -- "$WORKSPACE_ROOT"
```

Never run the removal command unless the path provenance and safety checks above have
both passed. Never broaden the path or substitute a parent directory.

**Otherwise:** the host environment owns this workspace; leave it in place. If the
platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Cleanup Bookmark |
|--------|-----------|------|----------------|------------------|
| 1. Integrate locally | yes | - | - | yes, if named |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes, if named |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature; I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes removal. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale; I'll clean it too" | Clean up only the captured workspace created under the recorded `.workspaces/<project>/` container. Everything else belongs to the host. |
| "The working-copy revision is empty, so every file is safe to delete" | Ignored files are not reported as revision changes. Inspect them before removing the directory. |
| "The rebased-result failure is probably flaky" | A failing rebased result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Moving the wrong base is expensive to untangle. |
| "The push was rejected; overriding safety checks will fix it" | A rejected push means the remote moved or bookmark state conflicts. Fetch and investigate; do not bypass Jujutsu's lease-style checks. |
