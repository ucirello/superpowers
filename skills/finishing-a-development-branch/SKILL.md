---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing Development Work

## Overview

**Core principle:** Verify tests -> identify the change stack and workspace -> present options -> execute the choice -> clean up only what RocketClaw owns.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite using the command established by the repository.

**If tests fail**, report the failures and stop. The menu comes only after a green suite:

```text
Tests failing (<failure-count>). Must fix before completing:

<failure-summary>
```

**If tests pass:** continue to Step 2.

## Step 2: Identify The Repository, Change, And Workspace

```bash
if WORKSPACE_ROOT=$(jj workspace root 2>/dev/null); then
  TMP_ROOT="$WORKSPACE_ROOT/.tmp"
else
  WORKSPACE_ROOT=
  TMP_ROOT=.tmp
fi
mkdir -p "$TMP_ROOT"
```

Outside a Jujutsu repository, `.tmp` is the local fallback for temporary files. Do not use a global temporary directory. Finishing and integrating changes requires a Jujutsu repository; if `WORKSPACE_ROOT` is empty, report that and stop.

Inspect the repository state and list every workspace with its name and root. Use `@` as the tip when it contains work or has a deliberate description. If `@` is the empty, undescribed change automatically created after `jj commit`, use its parent as the tip instead:

```bash
jj status
jj log -r '::@'
jj workspace list -T 'name ++ "\t" ++ root ++ "\n"'
if [ "$(jj log --no-graph -r @ -T 'if(empty && !description, "yes", "no")')" = yes ]; then
  TIP_REV=@-
else
  TIP_REV=@
fi
TIP_CHANGE=$(jj log --no-graph -r "$TIP_REV" -T 'change_id ++ "\n"')
```

If `@-` has multiple parents or the graph does not have one unambiguous feature tip, stop and select the intended tip with your human partner instead of guessing.

From the workspace listing, record these dynamic values before any cleanup changes the current directory:

- `WORKSPACE_NAME`: the name whose listed root equals `WORKSPACE_ROOT`
- `SURVIVING_WORKSPACE`: another listed workspace root in the same repository, if one exists
- `ROCKETCLAW_OWNED`: true only when `WORKSPACE_ROOT` is beneath the repository's `.tmp/workspaces/` directory

Every Jujutsu checkout is a workspace. A workspace is not a bookmark, and a bookmark is not a container for changes. The work being finished is the stack of changes after the base bookmark through `TIP_CHANGE`; a feature bookmark is only a durable name for integration or publication.

## Step 3: Confirm The Base And Descriptions

The base is the bookmark from which the work started, usually recorded in the plan or conversation. If it is not known, inspect bookmarks and the graph:

```bash
jj bookmark list --all-remotes
jj log -r 'all()'
```

Ask: "This work started from `<best-base-bookmark>`; is that correct?" Confirm before integrating because advancing the wrong bookmark is expensive to unwind.

Record the confirmed bookmark and selected remote as dynamic shell values. If the base exists only as an untracked remote bookmark, track that exact remote bookmark first.

```bash
BASE_BOOKMARK='<confirmed-base-bookmark>'
REMOTE='<selected-remote>'
jj bookmark track "${BASE_BOOKMARK}@${REMOTE}"  # Only when the remote bookmark is not tracked.
```

Use the confirmed base to inspect exactly the proposed stack:

```bash
jj log -r "$BASE_BOOKMARK..$TIP_CHANGE"
jj log -r "($BASE_BOOKMARK..$TIP_CHANGE)::"
```

Every meaningful change in that revset must have a repository-conformant description before integration or push. When a description must be composed or revised, preserve the semantic requirements of the change rather than applying a fixed message.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

```bash
jj describe -r <change-id> -m '<description-derived-from-the-change-and-repository-conventions>'
```

Re-run both logs after descriptions are updated. The first is the proposed stack; the second shows its descendants. Stop if the stack is empty, contains unrelated changes, has unresolved conflicts, includes changes that should not be integrated together, or has descendants outside the intended work.

## Step 4: Present Options

Present exactly these three semantic choices, substituting the confirmed dynamic values:

```text
Implementation complete. What would you like to do with changes <base-bookmark>..<tip-change>?

1. Integrate the changes into <base-bookmark> locally
2. Push <feature-bookmark-or-new-bookmark> and create a pull request
3. Keep the changes and workspace as-is

Which option?
```

Do not offer discard as a menu option. Discarding happens only when your human partner explicitly asks for it. Wait for their answer; the integration decision is theirs.

## Step 5: Execute The Choice

### Option 1: Integrate Locally

Fetch first so the tracked base bookmark reflects the remote state. Inspect the base bookmark after fetching and stop if it is conflicted or if the remote movement needs a decision.

```bash
jj git fetch --remote "$REMOTE"
jj bookmark list "$BASE_BOOKMARK" --all-remotes
```

If the updated base is already an ancestor of the feature tip, local integration can advance the base bookmark directly. Otherwise, create a merge change with both endpoints as parents, resolve any conflicts, and describe that merge using the repository-local standards from Step 3.

```bash
if [ -n "$(jj log --no-graph -r "$BASE_BOOKMARK & ::$TIP_CHANGE" -T 'commit_id')" ]; then
  INTEGRATED_TIP="$TIP_CHANGE"
else
  jj new "$BASE_BOOKMARK" "$TIP_CHANGE"
  INTEGRATED_TIP=@
fi
jj log -r "$BASE_BOOKMARK..$INTEGRATED_TIP"
jj status
```

If the merge change has conflicts, stop and resolve them before proceeding. Jujutsu records the conflicted change immediately; there is no interrupted merge to continue.

Run the repository's full test suite on `INTEGRATED_TIP`. If it fails, stop. Leave the base bookmark unmoved and preserve the workspace and feature bookmark while investigating.

Once the rebased result is green, advance the base bookmark to the tip:

```bash
jj bookmark move "$BASE_BOOKMARK" --to "$INTEGRATED_TIP"
jj bookmark list "$BASE_BOOKMARK"
```

This is local integration: do not push the base bookmark. If a local feature bookmark names the tip, forget it so no bookmark deletion is scheduled for a remote:

```bash
[ -z "${FEATURE_BOOKMARK:-}" ] || jj bookmark forget "$FEATURE_BOOKMARK"
```

Then clean up the workspace according to Step 6.

### Option 2: Push And Create A Pull Request

Use an existing, unambiguous local feature bookmark at `TIP_CHANGE`, or create a repository-conformant dynamic name. Do not move the base bookmark.

```bash
jj bookmark list -r "$TIP_CHANGE"
FEATURE_BOOKMARK='<bookmark-derived-from-the-work-and-repository-conventions>'
jj bookmark create "$FEATURE_BOOKMARK" -r "$TIP_CHANGE"
jj git push --remote "$REMOTE" --bookmark "$FEATURE_BOOKMARK"
```

If the bookmark already exists at the tip, omit `jj bookmark create`. A rejected push means the remote state must be fetched and inspected; do not bypass the lease-like safety checks or move a remote bookmark destructively without explicit approval.

Create the pull request against the confirmed base using the repository's template and conventions. Derive the title and body from the actual change stack; do not use a fixed title or body:

```bash
gh pr create --base "$BASE_BOOKMARK" --head "$FEATURE_BOOKMARK" --title '<title-derived-from-the-change-stack>' --body '<body-derived-from-the-change-stack-and-repository-template>'
```

Report the resulting URL. Preserve the workspace because pull-request feedback is handled there.

### Option 3: Keep As-Is

Report the dynamic change, bookmark state, and workspace path:

```text
Keeping changes through <tip-change>. Bookmark state: <bookmark-summary>. Workspace preserved at <workspace-root>.
```

### If Your Human Partner Asks To Discard The Work

This path exists only in response to an explicit request to throw the work away. Show the exact changes and workspace impact first:

```bash
jj log -r "$BASE_BOOKMARK..$TIP_CHANGE"
```

Ask for confirmation with the dynamic details:

```text
This will permanently abandon:
- Changes: <change-list>
- Local feature bookmark: <feature-bookmark-or-none>
- RocketClaw workspace: <workspace-root-or-preserved-external-workspace>

Type 'discard' to confirm.
```

Wait for that exact confirmation. If a local feature bookmark exists, forget it rather than scheduling remote deletion, then abandon only the confirmed stack:

```bash
[ -z "${FEATURE_BOOKMARK:-}" ] || jj bookmark forget "$FEATURE_BOOKMARK"
jj log -r "($BASE_BOOKMARK..$TIP_CHANGE):: ~ ($BASE_BOOKMARK..$TIP_CHANGE)"
jj abandon "$BASE_BOOKMARK..$TIP_CHANGE"
```

The descendant query must be empty before `jj abandon`; if it lists anything, stop and ask how to handle those descendants. Jujutsu automatically rebases descendants of abandoned changes, so this check must happen first. After a confirmed discard, clean up the workspace according to Step 6.

## Step 6: Clean Up The Workspace

Run this step only after successful local integration or confirmed discard. Options 2 and 3 always preserve the workspace.

**If `ROCKETCLAW_OWNED` is false:** preserve the workspace. The host environment owns it. If the platform provides a workspace-exit tool, use that tool without forgetting or deleting the workspace yourself.

**If `ROCKETCLAW_OWNED` is true:** verify all of the following before cleanup:

- `WORKSPACE_ROOT` is the exact root captured in Step 2.
- Its path is beneath the repository's `.tmp/workspaces/`.
- `WORKSPACE_NAME` matches that root in `jj workspace list`.
- `SURVIVING_WORKSPACE` is a different workspace in the same repository.
- No needed change is present only in the workspace being removed.

Then leave the workspace directory, forget its working-copy registration from the surviving workspace, and remove only the captured workspace directory:

```bash
cd "$SURVIVING_WORKSPACE"
jj workspace forget "$WORKSPACE_NAME"
rm -rf -- "$WORKSPACE_ROOT"
jj workspace list
```

`jj workspace forget` does not remove files from disk, which is why filesystem removal is a separate, provenance-gated step. If any validation fails or no surviving workspace exists, preserve the workspace and report why cleanup was skipped.

## Quick Reference

| Option | Merge with updated base when needed | Advance base bookmark | Push feature bookmark | Keep workspace |
|--------|-------------------------------------|-----------------------|-----------------------|----------------|
| 1. Integrate locally | yes | yes, locally | no | only if externally managed or cleanup is unsafe |
| 2. Create pull request | no | no | yes | yes |
| 3. Keep as-is | no | no | no | yes |
| Discard (explicit request only) | no | no | no | externally managed only |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the exact tree being integrated. A green run proves only the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "A bookmark contains the work" | Changes contain work; bookmarks only point to commits. Record the tip change and inspect the base-to-tip revset. |
| "I need to commit pending files first" | Jujutsu snapshots the working copy automatically. Describe and structure the current change instead of staging files. |
| "Fetch means the feature is integrated" | Fetch updates remote bookmark knowledge. Merge the selected feature tip with a divergent updated base before advancing the base bookmark. |
| "The pull request is open, so the workspace is clutter" | Feedback is handled in that workspace. Preserve it until the work lands. |
| "This workspace looks stale" | Forget and remove only a validated workspace under the repository's `.tmp/workspaces/`; preserve host-managed workspaces. |
| "Forgetting a workspace deletes its directory" | `jj workspace forget` only removes repository tracking. Filesystem cleanup is separate and provenance-gated. |
| "Deleting the feature bookmark is local cleanup" | `jj bookmark delete` schedules deletion on tracked remotes. Use `jj bookmark forget` for local-only cleanup. |
| "The push was rejected, so I should force it" | `jj git push` has lease-like safety checks. Fetch and investigate remote movement; destructive movement requires explicit approval. |
| "The base is obviously main" | Confirm the actual base bookmark. Advancing the wrong bookmark is expensive to unwind. |
