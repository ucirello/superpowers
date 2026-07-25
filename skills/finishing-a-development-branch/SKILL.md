---
name: finishing-a-development-branch
description: Use when implementation is complete, all required checks pass, and you need to decide how to integrate the work
---

# Finishing a Development Change

## Overview

**Core principle:** Verify checks -> inspect repository state -> present options -> execute the choice -> clean up only owned resources.

**Announce at start:** State that you are using the finishing-a-development-branch skill to complete the work.

## Step 1: Inspect Instructions and History

Before deciding what to run or how to describe the changes, inspect the
repository's instructions and recent history from the current Jujutsu snapshot:

```bash
jj workspace root
jj file list
jj file show -r @ <instruction-path>
jj log -r 'ancestors(@, <history-depth>)'
```

Discover applicable instruction files with `jj file list`; do not assume a
fixed filename or location. Repository instructions and conventions observed in
history at runtime always win over this skill. Do not replace them with a fixed
description syntax or canned wording.

At the one point where change descriptions are composed, edited, validated, or
recommended, apply this instruction:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use `jj log` to inspect that history and `jj describe <revision>` to edit a
change description. Apply only compatible Go quality guidance; never override
repository-specific conventions.

## Step 2: Verify Checks

Run the full validation required by the repository instructions. For a Go
repository with no more specific instructions, the compatible default is:

```bash
go test ./...
```

If any required check fails, report the actual failures and stop. Present the
completion options only after the required checks pass on the exact tree being
considered for integration.

## Step 3: Capture Jujutsu State

Capture state before any command rewrites changes or cleanup changes the current
directory:

```bash
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list
jj status
jj bookmark list --all-remotes
jj log -r @
```

Retain the workspace name recorded when it was created and verify that name and
its target with `jj workspace list`. If no creation record supplies both the
name and canonical root, treat the workspace as externally managed and never
remove it. Identify and retain stable change IDs for the work tip and work
changes. A bookmark pointing at the work is optional: Jujutsu has no active
bookmark, and bookmarks do not advance merely because new work is created.

Resolve `<work-tip>` deliberately. If `@` is a disposable empty working-copy
change above the completed work, use the completed parent; otherwise use `@`.
Inspect the candidate range with:

```bash
jj log -r '<base>..<work-tip>'
```

Stop on conflicts, divergent change IDs, a conflicted bookmark, or an ambiguous
work tip. Do not publish, integrate, or abandon an uncertain revset.

Workspace provenance controls cleanup:

| State | Completion menu | Cleanup |
|-------|-----------------|---------|
| Root is inside the creating workspace's `.tmp/rocketclaw/` directory | Standard three options | Eligible for owned cleanup |
| Any other root | Standard three options | Externally managed; leave in place |

The presence or absence of a work bookmark does not change the menu. Create one
only if publication requires it.

## Step 4: Determine the Base

The base is the revision from which the work started, normally identified by
the plan, conversation, repository instructions, or graph. Confirm the exact
base bookmark and remote when they are not already explicit. Use `jj log` and
revsets such as `fork_point(<candidate-base>|<work-tip>)` to verify the graph.

Do not assume a conventional bookmark name. Integrating onto the wrong base is
expensive to undo.

## Step 5: Present Options

After the checks pass, present exactly these semantic choices using the actual
base and work identifiers:

1. Integrate the work onto the base locally.
2. Publish the work bookmark and create a pull request.
3. Keep the changes and workspace as they are.

Ask which option to execute and wait for the answer. Do not offer discard as a
menu item. Discarding is available only after an explicit request and the
confirmation in the discard section.

## Step 6: Execute the Choice

### Option 1: Integrate Locally

Fetch the configured base remote, then re-check the base bookmark and range:

```bash
jj git fetch --remote <base-remote>
jj status
jj bookmark list <base-bookmark>
jj log -r '<base-bookmark>..<work-tip>'
```

If the base bookmark moved, use its fetched position. Before rebasing, inspect
descendants of the selected work and stop if the operation would rewrite
unrelated descendants. Then rebase the selected work changes onto the base;
`-r` preserves dependencies within the selected set:

```bash
jj rebase -r '<base-bookmark>..<work-tip>' -o <base-bookmark>
```

Resolve any conflicts according to repository instructions. Run the required
checks again on the rebased result before moving the base bookmark. If they
fail, stop with the base bookmark unchanged and preserve the workspace for
investigation.

After the rebased result passes, advance the base bookmark to the rewritten
work tip:

```bash
jj bookmark set <base-bookmark> -r <work-tip>
```

If a separate local work bookmark exists, forget it rather than deleting it;
`forget` removes the local name without scheduling deletion of a corresponding
remote bookmark:

```bash
jj bookmark forget <work-bookmark>
```

Then perform owned-workspace cleanup in Step 7.

### Option 2: Publish and Create a Pull Request

Create or update a work bookmark at the exact work tip, then push only that
bookmark to the selected remote:

```bash
jj bookmark set <work-bookmark> -r <work-tip>
jj git push --remote <publication-remote> --bookmark <work-bookmark>
```

Jujutsu push safety compares the remote bookmark with its last fetched state.
If the push is rejected, fetch and resolve the resulting state; do not bypass
the safety check without explicit authorization.

When composing or validating the pull-request title or body, apply this
instruction:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Inspect conventions through `jj log`, follow the repository's pull-request
instructions and template, and use neutral content derived from the actual
changes rather than a fixed title or body. `gh pr create --repo <repository>
--base <base-bookmark> --head <work-bookmark>` is allowed when GitHub CLI is
appropriate. Report the resulting URL.

Keep the workspace so review feedback can be addressed there.

### Option 3: Keep As-Is

Report the actual change ID, any bookmark, and the preserved workspace path. Do
not move bookmarks, rewrite changes, or clean up the workspace.

### If Explicitly Asked to Discard the Work

This path exists only in response to an explicit request to throw the work
away. First show the exact consequences, populated from:

```bash
jj log -r '<base>..<work-tip>'
jj bookmark list -r '<base>..<work-tip>'
jj workspace list
```

State that the listed changes, local work bookmarks, and any eligible owned
workspace will be removed. Require the exact typed word `discard`; no paraphrase
authorizes deletion.

After that exact confirmation, forget local work bookmarks first so abandoning
their targets does not schedule unintended remote bookmark deletion, then
abandon exactly the confirmed changes:

```bash
jj bookmark forget <work-bookmark>
jj abandon '<base>..<work-tip>'
```

Do not abandon the base or unrelated descendants. Then perform owned-workspace
cleanup in Step 7. Externally managed workspaces remain on disk with Jujutsu's
new empty working-copy change.

## Step 7: Cleanup Workspace

Run this step only after successful local integration or confirmed discard.
Publication and keep-as-is always preserve the workspace.

Only a workspace whose canonical root is strictly below the creating
workspace's `.tmp/rocketclaw/` directory is owned by RocketClaw. For an owned
workspace, verify the captured name and path again, forget its working-copy
change from the repository, leave the directory, and remove exactly that
directory:

```bash
jj workspace list
jj workspace forget <workspace-name>
cd <verified-parent-of-workspace-root>
rm -rf -- <verified-workspace-root>
```

Refuse cleanup if the path is empty, is the repository root, is the
`.tmp/rocketclaw` directory itself, does not have the verified owned prefix, or no
longer matches the captured workspace. `jj workspace forget` does not delete
files; filesystem removal is intentionally separate.

For any external workspace, leave it in place. If its environment provides an
exit mechanism, use that mechanism instead.

If temporary artifacts are ever required while following this workflow, use
`$(jj workspace root)/.tmp/rocketclaw`, falling back to the current workspace's
`.tmp/rocketclaw` only when root discovery fails. Create the directory with a
restrictive umask and `mkdir -p --`; do not use an operating-system-wide
temporary location.

```bash
if WORKSPACE_ROOT=$(jj workspace root 2>/dev/null) && [ -n "$WORKSPACE_ROOT" ]; then
    TEMP_ROOT="$WORKSPACE_ROOT/.tmp/rocketclaw"
else
    TEMP_ROOT=".tmp/rocketclaw"
fi
(umask 077 && mkdir -p -- "$TEMP_ROOT")
```

## Quick Reference

| Choice | Rebase work | Move base bookmark | Push work bookmark | Preserve workspace |
|--------|-------------|--------------------|--------------------|--------------------|
| Integrate locally | yes | after checks pass | no | only if external |
| Create pull request | no | no | yes | yes |
| Keep as-is | no | no | no | yes |
| Confirmed discard | abandon confirmed changes | no | no | only if external |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Checks passed earlier" | Run the required checks on the exact tree being integrated or published. |
| "The base name is obvious" | Confirm it from instructions, conversation, and the graph. |
| "The bookmark identifies my current work" | Jujutsu has no active bookmark; inspect the graph and stable change IDs. |
| "The base can move before post-rebase checks" | Keep it unchanged until the rebased result passes. |
| "Deleting and forgetting a bookmark are equivalent" | Deletion is propagated on a later push; forgetting does not schedule remote deletion. |
| "The pull request exists, so the workspace is disposable" | Preserve it for review feedback. |
| "This workspace looks stale" | Clean up only a verified RocketClaw-owned workspace in `.tmp/rocketclaw/`. |
| "A rejected push needs an unsafe override" | Fetch and investigate the remote movement first. |
| "The discard request was close enough" | Only the exact confirmation authorizes abandonment. |
