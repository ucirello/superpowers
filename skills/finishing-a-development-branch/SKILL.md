---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Change

## Overview

**Core principle:** Verify tests -> Detect environment -> Present options -> Execute choice -> Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop. The menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

Capture Jujutsu's repository and workspace state while still in the current
workspace. Step 5 may change directory before Step 6 needs these values.

```bash
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_PARENT=$(dirname "$WORKSPACE_ROOT")
WORKSPACE_OWNED=false
WORKSPACE_NAME=
while IFS= read -r candidate; do
  candidate_root=$(jj workspace root --name "$candidate")
  if [ "$candidate_root" = "$WORKSPACE_ROOT" ]; then
    WORKSPACE_NAME=$candidate
    break
  fi
done < <(jj workspace list -T 'name ++ "\n"')
[ -n "$WORKSPACE_NAME" ] || { printf 'current workspace is not registered\n' >&2; exit 1; }
FEATURE_REV=@
jj status
jj bookmark list
```

Set `WORKSPACE_OWNED=true` only when the conversation or plan confirms this
workspace was created manually by the `using-git-worktrees` Jujutsu fallback
for this task. A path under a conventional temporary directory is not proof of
ownership. Native and harness-managed workspaces remain host-owned.

Determine the feature bookmark from the plan or conversation and verify where
it points with `jj bookmark list`. If it is not known, ask. A bookmark may point
to `@`, to `@-` when `@` is an intentionally empty working-copy change, or to
another revision explicitly identified as the completed feature revision.
Set `FEATURE_BOOKMARK` to its name, or leave it unset for an anonymous change.
Set `FEATURE_REV` to the completed revision and verify it with:

```bash
jj log -r "$FEATURE_REV"
```

This determines which menu to show and how publication works:

| State | Menu | Publication |
|-------|------|-------------|
| Completed revision has a feature bookmark | Standard 3 options | Push that bookmark |
| Completed revision is anonymous | Standard 3 options | Create a bookmark only for publication |

An anonymous Jujutsu revision is not an error. Do not invent a bookmark unless
the human partner chooses publication.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from, usually named in the plan
or conversation. Confirm its current local and tracked-remote positions:

```bash
jj bookmark list --all-remotes <base-bookmark>
```

If the base is not already known, ask: "This change split from <your best
guess> - is that correct?" Confirm before integrating; moving the wrong
bookmark is expensive to undo.

Determine the remote from repository-local instructions and the bookmark's
tracked remote shown above. Inspect configured remotes with `jj git remote
list`. If more than one remote is plausible, ask rather than guessing. Set
`REMOTE` to the confirmed remote name and use it consistently below.

## Step 4: Present Options

**Present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the change as-is (I'll handle it later)

Which option?
```

Present the applicable menu exactly as written, concise and with every option
from the list above. Discarding the work happens only in response to the human
partner explicitly asking for it (see "If your human partner asks to discard
the work" below). Wait for their answer; the integration decision is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

First update remote bookmark state and inspect both revisions. Fetching does
not rewrite the completed change:

```bash
jj git fetch --remote "$REMOTE"
jj log -r "$BASE_BOOKMARK | $FEATURE_REV"
```

If the tracked remote base moved, update the local base bookmark deliberately
before integrating. Do not guess through a conflicted bookmark; inspect
`jj bookmark list` and resolve the bookmark target with `jj bookmark set` only
after confirming the intended revision. If that deliberately moves the local
bookmark backward or sideways, add `--allow-backwards`.

If the base bookmark is an ancestor of the completed feature revision, no
merge change is needed. Move the base bookmark directly:

```bash
jj bookmark set "$BASE_BOOKMARK" -r "$FEATURE_REV"
INTEGRATED_REV=$FEATURE_REV
```

If the base and feature revisions diverged, create a merge change with both as
parents:

```bash
jj new "$BASE_BOOKMARK" "$FEATURE_REV"
INTEGRATED_REV=@
jj status
jj resolve --list
```

Jujutsu records merge conflicts in the new change instead of interrupting the
operation. If `jj status` or `jj resolve --list` reports conflicts, resolve
them and repeat both commands. Do not describe the merge or move the base
bookmark until `jj resolve --list` is empty.

For this new merge change only, write a description before moving the base
bookmark. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
Derive the merge description at runtime from the actual integrated work and
repository-local instructions and history; their syntax and style always win.
Apply Go guidance only where compatible, and do not use a fixed description,
type, scope, prefix, subject, body, or template. Then apply it:

```bash
MERGE_DESCRIPTION=<runtime-derived-description>
jj describe -r "$INTEGRATED_REV" -m "$MERGE_DESCRIPTION"
jj bookmark set "$BASE_BOOKMARK" -r "$INTEGRATED_REV"
```

When a linear history is explicitly required instead of a merge, rebase the
feature change and its descendants onto the base, then move the base bookmark
to the rebased feature head:

```bash
FEATURE_CHANGE=$(jj log --no-graph -r "$FEATURE_REV" -T 'change_id ++ "\n"')
jj rebase -b "$FEATURE_REV" -o "$BASE_BOOKMARK"
FEATURE_REV=$FEATURE_CHANGE
jj bookmark set "$BASE_BOOKMARK" -r "$FEATURE_REV"
INTEGRATED_REV=$FEATURE_REV
```

Do not rebase by default; it rewrites the feature changes. Use it only when the
human partner or repository convention requires linear history.

Create a fresh working-copy change on the integrated revision and verify the
tests there:

```bash
jj new "$INTEGRATED_REV"
<test command>
```

If tests fail on the integrated result, stop. Leave the workspace, bookmarks,
and changes in place and investigate. Nothing has been pushed, and Jujutsu's
operation log preserves the local operations.

Once the integrated result is green, clean up an owned secondary workspace in
Step 6. The feature bookmark is no longer needed after the base bookmark names
the integrated result:

```bash
if [ -n "${FEATURE_BOOKMARK:-}" ]; then
  jj bookmark forget "$FEATURE_BOOKMARK"
fi
```

### Option 2: Push and Create PR

For an anonymous change, ask for the new bookmark name, then create it at the
completed revision. For an existing bookmark, first ensure it points to the
completed revision:

```bash
jj bookmark create "$FEATURE_BOOKMARK" -r "$FEATURE_REV"  # anonymous change only
jj bookmark set "$FEATURE_BOOKMARK" -r "$FEATURE_REV"     # existing bookmark only
jj git push --remote "$REMOTE" --bookmark "$FEATURE_BOOKMARK"
```

Never push `all:` or an incidental set of bookmarks. If the push is rejected,
fetch and inspect the remote bookmark state; do not bypass lease protection.

Derive the Pull Request title and description at runtime from the actual
changes, repository history, and PR template. Do not use fixed text. With
GitHub's CLI, the runtime-derived invocation is:

```bash
PR_TITLE=<runtime-derived-title>
PR_BODY=<runtime-derived-description>
gh pr create --base "$BASE_BOOKMARK" --head "$FEATURE_BOOKMARK" --title "$PR_TITLE" --body "$PR_BODY"
```

For another forge, use its CLI or the creation URL it prints, preserve the same
runtime-derived title and description, target the base bookmark, follow
repository conventions, and report the URL to the human partner.

Keep the workspace; the human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report the bookmark, if any, the completed revision's change ID, and the path:

```bash
jj log -r "$FEATURE_REV" -T 'change_id ++ "\n"'
jj workspace root
```

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work
away. Show the runtime-derived revisions that are unique to the feature and
confirm first:

```
This will permanently abandon:
- Bookmark <name, if any>
- Changes: <runtime-derived-change-list>
- Owned workspace at <path, if applicable>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, forget the local feature
bookmark if it exists and abandon only the runtime-derived feature revisions.
Exclude every revision reachable from the base bookmark. Forgetting, rather
than deleting, the bookmark avoids scheduling deletion of a tracked remote
bookmark:

```bash
jj bookmark forget "$FEATURE_BOOKMARK"  # if one exists
DISCARD_REVS=<runtime-derived-feature-revset-excluding-base>
jj abandon "$DISCARD_REVS"
```

Then clean up an owned workspace in Step 6.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Run cleanup from outside `WORKSPACE_ROOT`.

**If `WORKSPACE_OWNED=true` and `WORKSPACE_ROOT` is under `.tmp/`,
`.workspaces/`, or `workspaces/`:** Make the repository forget the workspace,
then remove its files:

```bash
cd "$WORKSPACE_PARENT"
jj -R "$WORKSPACE_ROOT" workspace forget "$WORKSPACE_NAME"
rm -rf -- "$WORKSPACE_ROOT"
```

**Otherwise:** Ownership is absent or the host environment owns this workspace.
Leave it in place. If the platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Forget Feature Bookmark |
|--------|-----------|------|----------------|-------------------------|
| 1. Integrate locally | yes | - | primary/host: yes; owned secondary: no | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | primary/host: yes; owned secondary: no | yes |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the revision you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is the human partner's decision. Present the menu and wait. |
| "They seem done with this feature, so I'll offer to discard it" | The menu is complete as written. Discard happens only when the human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment and workspace removal. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale, so I'll clean it too" | Clean up only the current workspace under `.tmp/`, `.workspaces/`, or `workspaces/`. Everything else belongs to the host. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Bookmarks, changes, and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Moving the wrong bookmark is expensive to undo. |
| "The push was rejected, so bypassing the lease will fix it" | A rejected push means remote state moved. Fetch and investigate; rewrite remote history only on the human partner's explicit request. |
