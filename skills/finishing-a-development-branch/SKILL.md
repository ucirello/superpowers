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

**If tests fail**, report the failures and stop; the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

```bash
# Capture these now; cleanup may run from another workspace.
WORKSPACE_ROOT=$(jj workspace root)
WORKSPACE_NAME=$(jj workspace list -T 'if(target.current_working_copy(), name ++ "\n")')
OTHER_WORKSPACE_NAME=
while IFS= read -r name; do
    if [ -n "$name" ]; then
        OTHER_WORKSPACE_NAME=$name
        break
    fi
done < <(jj workspace list -T 'if(!target.current_working_copy(), name ++ "\n")')
jj status
jj log -r '@ | @- | heads(::@ & bookmarks())'
```

Identify the completed feature tip from the status and graph. It is `@` when
the current change contains the completed work, or a completed ancestor such
as `@-` when `@` is a fresh empty change. Then determine how integration and
cleanup work:

| State | Action | Cleanup |
|-------|--------|---------|
| Feature tip has one feature bookmark | Use it | Provenance-based (see Step 6) |
| Feature tip has no feature bookmark | Ask for a bookmark name, then create it | Provenance-based (see Step 6) |
| Nearest bookmark is behind the feature tip | Confirm it represents this work, then advance it | Provenance-based (see Step 6) |
| Feature tip has multiple bookmarks | Ask which bookmark represents this work | Provenance-based (see Step 6) |

Create or advance the selected bookmark to the completed feature tip:

```bash
jj bookmark create <feature-bookmark> -r <feature-tip>
# If it already exists behind the feature tip:
jj bookmark set <feature-bookmark> -r <feature-tip>
```

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from, usually named in the
plan, the conversation, or the revision graph. If it is not already known,
ask: "This work split from <your best guess> - is that correct?" Confirm
before integrating; choosing the wrong base is expensive to undo.

## Step 4: Present Options

Present exactly these 3 options:

```
Implementation complete. What would you like to do?

1. Integrate back to <base-bookmark> locally
2. Push and create a pull/merge request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written: concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Change Descriptions

Repository-local instructions and the message syntax visible in `git log`
always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped body explaining what changed and why when needed. Do not impose a fixed message, prefix, type, scope, subject, body, template, or example.

If the completed feature tip needs a description, apply that guidance with
`jj describe <feature-tip>` and let the editor collect the description.

## Step 5: Execute Choice

### Option 1: Integrate Locally

```bash
# Refresh the base, then move the feature stack and its descendants onto it.
jj git fetch --remote <base-remote>
jj rebase -b <feature-bookmark> -o <base-bookmark>

# Verify tests on the integrated result.
<test command>
```

If the rebase introduces conflicts, resolve them before testing. If tests fail
on the integrated result, stop and investigate. Nothing has been pushed, and
the operation can be inspected with `jj op show` or reversed with `jj undo`.

Once the integrated result is green, advance the base bookmark, remove the
now-redundant feature bookmark, then clean up the workspace (Step 6):

```bash
jj bookmark set <base-bookmark> -r <feature-bookmark>
jj bookmark forget <feature-bookmark>
```

### Option 2: Push and Create Pull/Merge Request

```bash
jj git push --remote <feature-remote> --bookmark <feature-bookmark>
<provider-appropriate PR/MR command, or use the creation URL emitted by the push>
```

On GitHub, the provider command is `gh pr create --base <base-bookmark> --head
<feature-bookmark>`. Follow the repository's pull or merge request template and conventions,
then report the URL to your human partner. Keep the workspace; your human
partner iterates on review feedback there.

### Option 3: Keep As-Is

Report: "Keeping bookmark <name>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work
away. Show the exact revisions selected by
`<base-bookmark>..<feature-bookmark>` with `jj log`, then confirm first:

```
This will abandon locally:
- Bookmark <name>
- All listed revisions: <revision-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, abandon the feature
revisions; bookmarks pointing to abandoned revisions are removed with them:

```bash
jj abandon '<base-bookmark>..<feature-bookmark>'
```

Then clean up the workspace (Step 6).

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve
the workspace. Use the `WORKSPACE_NAME`, `WORKSPACE_ROOT`, and
`OTHER_WORKSPACE_NAME` values captured in Step 2.

**If `OTHER_WORKSPACE_NAME` is empty:** This is the only workspace. There is
no workspace to clean up. Done.

**If `WORKSPACE_ROOT` is under `.tmp/rocketclaw/workspaces/`:** RocketClaw
created this workspace, so it owns cleanup. Forget the captured workspace,
leave its directory, then remove only that directory:

```bash
jj workspace forget "$WORKSPACE_NAME"
cd "$(dirname "$WORKSPACE_ROOT")"
rm -rf -- "$WORKSPACE_ROOT"
```

**Otherwise:** The host environment owns this workspace; leave it in place.
If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Integrate | Push | Keep Workspace | Cleanup Bookmark |
|--------|-----------|------|----------------|------------------|
| 1. Integrate locally | yes | - | - | yes |
| 2. Create pull/merge request | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature; I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment. |
| "The review request is up, so the workspace is clutter now" | Review feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale; I'll clean it too" | Clean up only the captured workspace under `.tmp/rocketclaw/workspaces/`. Everything else belongs to the host. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. The bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Integrating into the wrong base is expensive to undo. |
| "The push was rejected; bypassing safety checks will fix it" | A rejected push means the remote moved. Fetch and investigate; override safety only on your human partner's explicit request. |
