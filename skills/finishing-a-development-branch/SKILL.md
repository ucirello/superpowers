---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the change
---

# Finishing a Development Change

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
jj workspace list
jj bookmark list -r '::@'
```

From this output, record the current `<workspace-name>`, any
`<feature-bookmark>` that names the work, and the completed
`<feature-revision>` as its stable change ID. The completed revision is
usually `@`, or `@-` when `@` is an empty change, but do not carry that
workspace-relative symbol into another workspace. Record its change ID
from `jj log` instead. Obtain the integration workspace from repository
instructions or explicit confirmation; JJ does not designate a primary
workspace. Record its path as `REPO_ROOT`:

```bash
REPO_ROOT="<confirmed-integration-workspace-path>"
jj -R "$REPO_ROOT" workspace root
```

Capture these values now, while still inside the workspace. Step 5 may
change directory before Step 6 needs them.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| Primary workspace | Standard 3 options | No secondary workspace to clean up |
| Named-bookmark secondary workspace | Standard 3 options | Provenance-based (see Step 6) |
| Anonymous externally managed workspace | Reduced 2 options (no merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the bookmark's tracked remote bookmark. If it is
not already known, ask: "This change split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Primary workspace and named-bookmark secondary workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the change as-is (I'll handle it later)

Which option?
```

**Anonymous externally managed workspace — present exactly these 2 options:**

```
Implementation complete. This is an anonymous externally managed workspace.

1. Push as a new bookmark and create a Pull Request
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

```bash
# Integrate from the confirmed integration workspace, outside a secondary feature workspace
cd "$REPO_ROOT"
jj status
```

If the primary workspace contains unrelated work, stop and ask your human
partner before moving its working copy.

Then fetch and create the merge change:

```bash
jj git fetch --remote origin
jj new <base-bookmark> <feature-revision>
jj status
```

If fetching leaves the base bookmark conflicted or divergent, stop and
resolve its remote state before integrating.

If the merge change contains unresolved conflicts, stop and resolve them
before describing it or running tests.

Follow repository-local commit-message instructions and conventions first;
they take precedence. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

```bash
jj describe -m "<merge-description>"

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the workspace and bookmarks
in place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the merged result is green, move the base bookmark to the merge change:

```bash
jj bookmark set <base-bookmark> -r @
```

Clean up the feature workspace (Step 6) and delete the feature bookmark.
Deleting a bookmark does not abandon its revisions, so the merged history
remains reachable from the base bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
# Make the bookmark name the completed change, then update remote state
jj bookmark set <feature-bookmark> -r <feature-revision>
jj git fetch --remote origin
jj git push --remote origin --bookmark <feature-bookmark>

# For anonymous work, create and push a new bookmark instead:
# jj bookmark create <new-bookmark> -r <feature-revision>
# jj git fetch --remote origin
# jj git push --remote origin --bookmark <new-bookmark>
```

Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping bookmark <name>. Workspace preserved at <path>."

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

Before asking, show the exact changes that would be abandoned and check for
descendants outside that set:

```bash
jj log -r '<base-bookmark>..<feature-revision>'
jj log -r '(<base-bookmark>..<feature-revision>):: ~ (<base-bookmark>..<feature-revision>)'
```

If the second command shows revisions belonging to other bookmarks or
workspaces, stop instead of abandoning the set; abandoning would rewrite those
descendants too.

Wait for that exact confirmation. When it arrives, change to the primary
workspace, clean up the feature workspace (Step 6), delete its bookmark if
it remains, and abandon only the feature changes:

```bash
cd "$REPO_ROOT"
# Run only when the feature bookmark exists
jj bookmark delete <feature-bookmark>
jj abandon '<base-bookmark>..<feature-revision>'
```

`jj abandon` rewrites descendants and, by default, deletes bookmarks that
point to abandoned revisions. Never add `--retain-bookmarks` here: discard
means the feature bookmark must not move backward and survive accidentally.

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the workspace. Both callers have already changed to the primary
workspace — forgetting and deleting a secondary workspace must run from
outside it — and use the `WORKSPACE_ROOT` and `<workspace-name>` values
captured in Step 2.

**If this is the primary workspace:** No secondary workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `$REPO_ROOT/.rocketclaw/workspaces/`:**
RocketClaw created this workspace, so we own cleanup. `jj workspace forget`
removes the workspace registration but intentionally leaves its files on
disk; delete that one verified path afterward:

```bash
jj workspace forget <workspace-name>
rm -rf -- "$WORKSPACE_ROOT"
```

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
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
| "This other workspace looks stale — I'll clean it too" | Clean up only the current workspace when it is under `$REPO_ROOT/.rocketclaw/workspaces/`. Everything else belongs to the host. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — retrying will fix it" | A rejected push means the remote bookmark moved or diverged. Fetch, inspect, and resolve it; never bypass JJ's remote-state safety without your human partner's explicit request. |
