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

```bash
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_NAME=$(jj workspace list -T 'name ++ "\t" ++ root ++ "\n"' |
  while IFS="$(printf '\t')" read -r name root; do
    [ "$root" = "$WORKSPACE_ROOT" ] && printf '%s\n' "$name"
  done)
WORKSPACE_COUNT=$(jj workspace list -T '"workspace\n"' | wc -l | tr -d ' ')
WORKSPACE_OWNER_ROOT=$(jj workspace list -T 'root ++ "\n"' |
  while IFS= read -r root; do
    if [ "$WORKSPACE_ROOT" = "$root/.tmp/$WORKSPACE_NAME" ]; then
      printf '%s\n' "$root"
      break
    fi
  done)
```

Identify `FEATURE_BOOKMARK`, the local bookmark naming this work, from the
plan, conversation, and `jj bookmark list`. Leave it empty if the work has no
local bookmark. Capture these values now, before cleanup changes directory.

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `WORKSPACE_COUNT == 1` (only workspace), feature bookmark present | Standard 3 options | No workspace to clean up |
| Additional workspace, feature bookmark present | Standard 3 options | Provenance-based (see Step 6) |
| No feature bookmark | Reduced 2 options (no merge) | Externally managed — leave in place |

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the bookmark's tracked remote. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Only workspace and named-bookmark workspace — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

**No feature bookmark — present exactly these 2 options:**

```
Implementation complete. This change has no feature bookmark (externally managed workspace).

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

Fetch first. If this produces a bookmark conflict, stop and resolve it before
integrating:

```bash
jj git fetch --remote <remote>
REMOTE_BASE='<base-bookmark>@<remote>'
FEATURE_HEAD='<feature-head>'
jj log --no-graph -r "$REMOTE_BASE & ::$FEATURE_HEAD"
```

If the log prints the remote base, the feature result already contains the
fetched base. Verify `<feature-head>`, then advance the local base bookmark to
that revision; do not create an unnecessary merge change.

If the log is empty, the histories diverged. Create and verify an integration
change with both revisions as parents:

```bash
jj new "$REMOTE_BASE" "$FEATURE_HEAD"
```

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and conventions always win. Apply compatible Go
guidance to clarity and structure without imposing syntax, and describe the
integration with `jj describe -m "<message composed from the standards above>"`.

Verify the selected result before moving the base bookmark:

```bash
<test command>
jj bookmark set <base-bookmark> -r <verified-feature-or-integration-change>
```

If tests fail on the merged result: stop, leave the workspace and bookmarks in
place, and investigate — nothing has been pushed, so the merge change is local
and recoverable.

Once the merged result is green, forget the local feature bookmark without
propagating a deletion to any remote bookmark, then clean up the workspace
(Step 6):

```bash
jj bookmark forget <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
# With an existing feature bookmark:
jj bookmark set <feature-bookmark> -r <feature-head>
jj git push --bookmark <feature-bookmark> --remote <remote>

# With no feature bookmark, create and push one:
jj git push --named <new-bookmark>=<feature-head> --remote <remote>
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
- Bookmark <name, if present>
- All changes: <change-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, identify the exact change
IDs recorded for this work. Show the list and confirm that no listed change is
retained by another bookmark, workspace, or descendant. Do not infer ownership
from a range, because merged history can include unrelated changes. Then forget
the bookmark and abandon only those exact confirmed changes:

```bash
if [ -n "$FEATURE_BOOKMARK" ]; then
  jj bookmark forget "$FEATURE_BOOKMARK"
fi
jj abandon <exact-change-id>...
```

Then clean up the workspace (Step 6).

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Use the `WORKSPACE_ROOT`, `WORKSPACE_NAME`, and
`WORKSPACE_COUNT` values captured in Step 2.

**If `WORKSPACE_COUNT == 1`:** This is the only workspace. Do not forget or
remove it. Done.

**If `WORKSPACE_OWNER_ROOT` is non-empty:** The workspace is rooted under
another registered workspace's `.tmp/` directory, so this workflow owns
cleanup. First inspect its final state:

```bash
jj status
```

Jujutsu snapshots eligible working-copy files automatically, but ignored files
can still exist only in this workspace. Before removal, enumerate all filesystem
entries, including ignored files, and compare them with `jj file list`; `jj
status` alone is insufficient. If this reveals plans, notes, generated files,
scratch work, or any other workspace-only file, never remove them on your own
initiative. Show your human partner what is at stake and ask:

```
Workspace cleanup would remove files that are not preserved in a change:

<file list>

1. Record them in <feature-change> before cleanup
2. Move them into <primary workspace root>
3. Delete them (unrecoverable)

Which?
```

If recording them in a change, follow this instruction before composing its
description: Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use the repository's local conventions and a neutral revision placeholder:

```bash
jj describe <feature-change>
```

Carry out the choice. Do not continue until every workspace-only file has been
preserved or explicitly approved for deletion. Then forget the workspace
registration from outside its directory and remove the directory:

```bash
cd "$(dirname "$WORKSPACE_ROOT")"
jj -R "$WORKSPACE_ROOT" workspace forget "$WORKSPACE_NAME"
rm -rf "$WORKSPACE_ROOT"
```

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only the current workspace when it is anchored under another registered workspace's `.tmp/` directory. Everything else belongs to the host. |
| "Those ignored files are probably disposable" | They may exist only in that workspace. Removing the directory destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmarks and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — overriding the lease will fix it" | A rejected push means the remote moved. Fetch and investigate; override Jujutsu's remote-bookmark safety only on your human partner's explicit request. |
