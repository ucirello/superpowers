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
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_COUNT=$(jj workspace list -T 'name ++ "\n"' | wc -l | tr -d ' ')
FEATURE_REVISION=$(jj log --no-graph -r @ -T 'if(empty, "@-", "@")')
FEATURE_BOOKMARKS=$(jj bookmark list -r "$FEATURE_REVISION" -T 'name ++ "\n"')
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| One workspace | Standard 3 options | No additional workspace to clean up |
| Additional workspace under `.worktrees/` or `worktrees/` | Standard 3 options | Provenance-based (see Step 6) |
| Additional workspace elsewhere | Reduced 2 options (no local integration) | Externally managed — leave in place |

If multiple bookmarks point to the feature revision, ask which one represents
the work. A bookmark is optional for local integration but required for the
bookmark-specific push command. Repository-local bookmark and remote conventions
take precedence over the placeholders below.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the tracked remote bookmark. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before integrating:
moving the wrong base bookmark is expensive to undo.

## Step 4: Present Options

**Single workspace and workflow-owned additional workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

**Externally managed additional workspace — present exactly these 2 options:**

```
Implementation complete. This is an externally managed workspace.

1. Push under a new bookmark and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Present the applicable menu exactly as written — concise, with every option
coming from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

```bash
# Refresh the configured remote, reconcile the local base with its remote,
# then rebase the feature stack onto the reconciled local base.
jj git fetch --remote <remote>
jj rebase -b <base-bookmark> -o <base-bookmark>@<remote>
jj rebase -s 'roots(<base-bookmark>..<feature-revision>)' -o <base-bookmark>

# Verify tests on the integrated result before moving the base bookmark.
<test command>
```

If tests fail on the integrated result: stop, leave the workspace and bookmarks
in place, and investigate — nothing has been pushed, so the rebase is local
and recoverable.

Once the integrated result is green, move the base bookmark to the feature
head, forget the local feature bookmark, then clean up the workspace (Step 6).
Forgetting does not schedule deletion of a same-named remote bookmark:

```bash
jj bookmark move <base-bookmark> --to <feature-revision>
# If the work has a separate local feature bookmark:
jj bookmark forget <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
# If the feature already has a bookmark:
jj git push --bookmark <feature-bookmark> --remote <remote>
# Otherwise, create and push a named bookmark at the feature revision:
jj git push --named <new-bookmark>=<feature-revision> --remote <remote>
```

Before composing or updating a change description, follow repository-local
conventions. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
Use `jj describe <revision>` if the change needs a description before pushing.

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report that the change, any bookmark, and the workspace were preserved,
including their names and path.

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Bookmark <name>
- All changes: <change-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. Before changing anything, capture the
revisions to abandon so forgetting the bookmark does not make the revset
unresolvable:

```bash
REVISIONS=$(jj log -r '<base-bookmark>..<feature-bookmark>' --no-graph -T 'commit_id ++ "\n"')
```

Then forget the bookmark, abandon its changes, and clean up the workspace
(Step 6):

```bash
jj bookmark forget <feature-bookmark>
jj abandon $REVISIONS
```

For an anonymous change, capture and abandon the confirmed range directly:

```bash
REVISIONS=$(jj log -r '<base-bookmark>..@' --no-graph -T 'commit_id ++ "\n"')
jj abandon $REVISIONS
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Use the `WORKSPACE_ROOT` and `WORKSPACE_COUNT` values
captured in Step 2.

**If `WORKSPACE_COUNT == 1`:** No additional workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `.worktrees/` or `worktrees/`:** This workflow
owns the workspace cleanup:

```bash
jj workspace forget
cd "$(dirname "$WORKSPACE_ROOT")"
rm -rf "$WORKSPACE_ROOT"
```

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

If any temporary files are needed during this workflow, put them under
`$(jj workspace root)/.tmp`; if that cannot be created, fall back to `./.tmp`.
Do not use a global temporary directory.

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
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only additional workspaces under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Moving the wrong base is expensive to undo. |
| "The push was rejected — bypassing safety checks will fix it" | A rejected push means the remote moved. Fetch, investigate, and resolve bookmark conflicts; override safety only on your human partner's explicit request. |
