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
WORKSPACE_NAME=$(jj workspace list -T 'if(target.current_working_copy(), name ++ "\n")')
WORKSPACE_PATH=$WORKSPACE_ROOT
jj workspace list
jj status
jj bookmark list --all-remotes
```

Identify the feature head: normally `@` when the working-copy change contains
the completed work, or `@-` when `@` is the empty change created by `jj commit`.
Resolve it to a stable change ID with `jj log --no-graph -r <feature-head> -T
'change_id ++ "\n"'` and record that as `FEATURE_REVISION`. Record an existing
feature bookmark that points to that revision; if none exists, create one before
pushing.

Jujutsu has no active bookmark and no detached-HEAD state. A workspace edits a
revision while bookmarks are independent pointers, so every workspace gets the
same three-option menu.

Before composing, editing, validating, or recommending any JJ change description
or commit message, apply this exact instruction:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Run `GIT_DIR=$(jj git root) git log -n <repository-appropriate-history-count>
--format=fuller` before applying that instruction. Repository-local syntax and
history win, including conventions for prefixes, types, scopes, capitalization,
summary shape, body use, and trailers. Where compatible with those conventions,
follow the Go guidance to keep the summary clear and concise and to use a body
when it helps explain what changed and why. Do not prescribe a fixed prefix,
type, scope, subject, body, or example. Compose
`<message-derived-from-repository-history-and-change>`, then set it with `jj
describe -r <revision>` and validate the resulting description against the same
instruction. Every non-empty revision to be integrated or pushed must have a
meaningful description.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan or conversation, or visible in the revision graph. If it is not already
known, ask: "This work split from <your best guess> - is that correct?"
Confirm before integrating: moving the wrong bookmark is expensive to undo.

## Step 4: Present Options

**Present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming from
the list above. Discarding the work happens only in response to your human
partner explicitly asking for it (see "If your human partner asks to discard
the work" below). Wait for their answer; the integration decision is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

From the feature workspace, update the Git remote and rebase the feature onto
the base bookmark:

```bash
jj git fetch --remote <remote>
jj rebase -b <feature-bookmark-or-FEATURE_REVISION> -o <base-bookmark>

# Verify tests on integrated result
<test command>
```

If tests fail on the integrated result: stop, leave the workspace and bookmarks
in place, and investigate — nothing has been pushed, so the operation is local
and recoverable.

Once the integrated result is green, move the base bookmark to the feature
head:

```bash
jj bookmark move <base-bookmark> --to <feature-bookmark-or-FEATURE_REVISION>
```

Then clean up the workspace (Step 6) and forget the feature bookmark:

```bash
jj bookmark forget <feature-bookmark>  # If present
```

### Option 2: Push and Create PR

```bash
jj bookmark create <feature-bookmark> -r <FEATURE_REVISION>
# If the bookmark already exists:
# jj bookmark move <feature-bookmark> --to <FEATURE_REVISION>
jj git push --bookmark <feature-bookmark> --remote <remote>
```

Then create the pull/merge request against `<base-bookmark>` with the forge's
tooling — its CLI if one is available, or the creation URL most forges print
when you push — following the repo's PR template and conventions if present,
and report the URL to your human partner. For GitHub from a non-colocated JJ
repository, use `GIT_DIR=$(jj git root) gh pr create --base <base-bookmark>
--head <feature-bookmark>`.

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping work at <revision-or-bookmark>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work
away. Confirm first:

```
This will permanently abandon:
- Bookmark <name>, if present
- All revisions: <revision-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, clean up the workspace
(Step 6), then forget the bookmark and abandon the revisions from a retained
workspace:

```bash
jj bookmark forget <feature-bookmark>  # If present
jj abandon '<base-bookmark>..<FEATURE_REVISION>'
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Workspace removal must run from a different, retained workspace.

**If this is the only workspace:** No additional workspace to clean up. Done.

**If `WORKSPACE_PATH` is under `.worktrees/` or `worktrees/`:** RocketClaw
created this workspace — we own cleanup:

```bash
jj workspace forget <workspace-name>
```

After forgetting it, remove the recorded workspace directory with the host
filesystem tool. `jj workspace forget` does not remove files from disk.

**Otherwise:** The host environment owns this workspace — leave it in place.
If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Cleanup Bookmark |
|--------|-----------|------|----------------|------------------|
| 1. Integrate locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (then abandon) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the revision you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment. |
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. Bookmarks and workspaces stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Moving the wrong bookmark is expensive to undo. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; bypass JJ's remote-state checks only on your human partner's explicit request. |
