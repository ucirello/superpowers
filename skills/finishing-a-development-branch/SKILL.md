---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate a Jujutsu change
---

# Finishing a Development Change

## Overview

**Core principle:** Verify tests -> inspect changes and workspace ownership ->
present options -> execute the choice -> clean up.

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
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list
jj status
jj log -r '::@' --limit 20
```

Capture `WORKSPACE_ROOT` now because cleanup may leave the workspace. Determine
whether the harness owns this workspace from its native workspace state and
the session instructions. A path under project-local `.workspaces/` or
`workspaces/` is manually managed by this workflow; every other isolated path
belongs to the harness unless the user says otherwise.

Jujutsu work is identified by change IDs and revsets, so unnamed state does
not require a reduced menu or named reference. Record `FEATURE_TIP` as the
finalized change supplied by the calling workflow. Otherwise use `@`, except
when `@` is a fresh empty child created after finalizing the work; in that
case use `@-`. Resolve the selection to exactly one full change ID and stop if
it is missing or ambiguous:

```bash
FEATURE_TIP_REV=${FINALIZED_FEATURE_TIP:-@}
if [[ -z "${FINALIZED_FEATURE_TIP:-}" && -z "$(jj diff --summary)" && -z "$(jj log -r @ --no-graph -T 'description')" ]]; then
  FEATURE_TIP_REV=@-
fi
FEATURE_TIP=$(jj log -r "$FEATURE_TIP_REV" --no-graph -T 'change_id ++ "\n"')
[[ $(printf '%s\n' "$FEATURE_TIP" | grep -c .) -eq 1 ]] || { echo "feature tip must resolve to exactly one change" >&2; exit 1; }
jj show "$FEATURE_TIP"
```

Use that exact revision throughout this workflow.

## Step 3: Determine Base Revision

The base bookmark or revision is whatever this work forked from, usually named
in the plan, conversation, or repository instructions. Inspect likely local and
remote bookmarks with:

```bash
jj bookmark list --all-remotes
jj log -r "heads(::$FEATURE_TIP & bookmarks())"
```

If the base is not already known, ask: "This change is based on <your best
guess> - is that correct?" Confirm before rebasing or advancing a bookmark;
integrating onto the wrong base is expensive to undo.

After confirmation, inspect exactly what will be integrated:

```bash
jj log -r "<base-revision>..$FEATURE_TIP"
jj diff -r "<base-revision>..$FEATURE_TIP"
```

If the revset includes unrelated changes, stop and correct the boundary before
continuing.

## Step 4: Present Options

Present exactly these 3 options:

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push a bookmark and create a Pull Request
3. Keep the change as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written: concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Finalize Change Descriptions

Before Option 1 or 2, ensure every change in `<base-revision>..$FEATURE_TIP` has a useful,
non-empty description. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and syntax established by `git log` always win; apply compatible Go guidance to clarity and structure without imposing fixed prefixes, types, scopes, subjects, bodies, or templates. Each dynamically composed description must explain what its change does and, when the reason is not obvious, why it is needed and any notable behavior.

Apply descriptions to the intended revisions with `jj describe -r <revision>`.
Do not squash or rewrite change boundaries solely to imitate another VCS.

### Option 1: Integrate Locally

```bash
# Refresh the remote view when the repository has a configured remote.
jj git fetch --remote <remote>

# Rebase only the confirmed feature revset, preserving its internal order.
jj rebase -r "<base-revision>..$FEATURE_TIP" -o <base-revision>

# Put the rebased feature tree in the working copy for verification.
jj edit "$FEATURE_TIP"
VERIFIED_COMMIT=$(jj log -r "$FEATURE_TIP" --no-graph -T 'commit_id ++ "\n"')
<test command>
jj status
[[ "$(jj log -r "$FEATURE_TIP" --no-graph -T 'commit_id ++ "\n"')" == "$VERIFIED_COMMIT" ]] || { echo "verification modified the reviewed feature change; inspect before integrating" >&2; exit 1; }

jj bookmark set <base-bookmark> -r "$FEATURE_TIP"
```

Use the repository's local base revision when no remote exists. If the base
bookmark moved after fetching, stop and re-confirm the destination before
rebasing.

If tests fail on the rebased result, stop, leave the workspace and changes in
place, and investigate. Nothing has been pushed, and Jujutsu's operation log
keeps the rewrite recoverable. Once the result is green and the base bookmark
has advanced, clean up the workspace in Step 6. If this workspace will remain
active because it is primary or harness-owned, first run `jj new
<base-bookmark>` so later edits start in a new empty change. A locally owned
workspace scheduled for removal does not need that extra change.

### Option 2: Push and Create PR

```bash
jj bookmark set <feature-bookmark> -r "$FEATURE_TIP"
jj git push --remote <remote> --bookmark <feature-bookmark>
jj new <feature-bookmark>
```

If the push reports stale remote state, run `jj git fetch --remote <remote>`,
inspect bookmark conflicts, and resolve them without bypassing lease checks.

Then create the pull/merge request against `<base-bookmark>` with the forge's
tooling: its CLI if one is available, or the creation URL most forges
print when you push. Follow the repo's PR template and conventions if
present, and report the URL to your human partner.

`jj new` leaves the published change fixed at the bookmark and prepares an
empty child for follow-up work. Keep the workspace; your human partner iterates
on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping change <change-id>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Changes: <change-list>
- Any local feature bookmark: <bookmark-or-none>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, abandon only the confirmed
feature revset:

```bash
jj abandon "<base-revision>..$FEATURE_TIP"
```

If a local feature bookmark exists, delete it with `jj bookmark delete
<feature-bookmark>`. This records a remote deletion for the next push; do not
push that deletion unless the explicit discard request also covers the remote
bookmark. Then clean up the workspace in Step 6.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace.

If this is the primary workspace, there is nothing to clean up.

If `WORKSPACE_ROOT` is under project-local `.workspaces/` or `workspaces/`,
this workflow owns it. While still in that workspace, forget its working-copy
registration, then leave it and remove only the captured directory:

```bash
jj workspace forget
cd <project-root>
rm -rf "$WORKSPACE_ROOT"
jj workspace list
```

Before removal, verify the path is the exact captured workspace root, is under
one of the two project-local workspace directories, and is not the project
root. `jj workspace forget` does not delete files; directory removal is a
separate, deliberately guarded operation.

Otherwise, the harness owns the workspace. Leave it in place or use the
harness's native workspace-exit control. Do not call `jj workspace forget` on
a harness-owned workspace.

## Quick Reference

| Option | Rebase | Advance/Push Bookmark | Keep Workspace |
|--------|--------|-----------------------|----------------|
| 1. Integrate locally | yes | advance base | no, if locally owned |
| 2. Create PR | no | push feature | yes |
| 3. Keep as-is | no | no | yes |
| Discard (explicit request only) | abandon | delete local feature bookmark | no, if locally owned |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature, so I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale, so I'll clean it too" | Clean up only the captured, locally owned workspace. Everything else belongs to the harness or another task. |
| "The rebased-result failure is probably flaky" | A failing rebased result stops everything. Changes and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the base revision or ask. Rebasing and advancing the wrong bookmark is expensive to undo. |
| "The push was rejected, so I should bypass the lease" | Fetch and inspect the remote bookmark. Do not bypass Jujutsu's remote-state safety checks without explicit authorization. |
