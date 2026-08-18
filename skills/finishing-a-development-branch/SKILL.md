---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing Development Work

## Overview

**Core principle:** Verify tests -> identify revisions and workspace -> present options -> execute the choice -> clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite using the command established by the project or current session.

If tests fail, report the failures and stop. Do not offer integration choices until the suite is green.

If tests pass, continue to Step 2.

## Step 2: Identify Revisions and Workspace

Jujutsu has no active bookmark and no detached-bookmark state. The working-copy revision is `@`; bookmarks are movable names for revisions.

Record:

```bash
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list
jj status
jj log -r '::@' --limit 20
jj bookmark list --all-remotes
```

From this output, identify and retain:

- The current workspace name and root.
- The feature-tip revision. Use a stable change ID when later commands may rewrite its commit ID.
- Any local bookmark already naming the feature tip.
- Whether this is the repository's primary workspace or a workflow-owned workspace under `.tmp/workspaces/`, `.workspaces/`, or `workspaces/`, and the root of another retained workspace from which cleanup commands can run.
- Whether the workspace is externally managed and its host blocks bookmark or push operations.

If scratch storage is needed, use `$(jj workspace root)/.tmp`. If `jj workspace root` is unavailable, use the local `./.tmp` directory. Do not use a global temporary directory. Ensure the selected path is ignored before creating files there so Jujutsu does not snapshot them.

## Step 3: Determine the Base Bookmark

The base bookmark is the revision from which the work diverged, usually recorded in the plan or conversation. Use `jj log` and the relevant remote bookmark to verify the relationship. If the base is not known, ask for confirmation using the best-supported guess. Confirm before integrating because moving the wrong bookmark is expensive to unwind.

Also identify the backing remote used by the project with `jj git remote list` rather than assuming `origin`.

## Step 4: Present Options

**Normal or workflow-owned workspace: present exactly these choices:**

```text
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push a feature bookmark and create a Pull Request
3. Keep the revisions and workspace as-is (I'll handle them later)

Which option?
```

**Externally managed workspace where the host blocks bookmark or push operations: present exactly these choices:**

```text
Implementation complete. This workspace is externally managed.

1. Use the host's Create branch control and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Do not offer discard as a routine option. Discarding happens only after an explicit request. Wait for your human partner's decision.

## Step 5: Execute the Choice

For the externally managed two-option menu, leave repository state and workspace cleanup to the host. If option 1 is selected, ensure the recorded `<feature-tip>` has an appropriate description, using `jj describe <feature-tip>` under the message policy below if it must be composed or edited, then direct your human partner to the host's native **Create branch** control and continue with its Pull Request flow. If option 2 is selected, report the retained revision and workspace path. Do not run the standard three-option commands below.

### Option 1: Integrate Locally

Fetch the configured remote, check for bookmark conflicts, rebase the graph branch containing the feature tip onto the updated base, and then advance the base bookmark to the rebased feature tip:

```bash
jj git fetch --remote <remote>
jj status
jj rebase -b <feature-tip-change-id> -o <base-bookmark>
jj bookmark move <base-bookmark> --to <feature-tip-change-id>
```

`jj rebase -b` rebases the branch containing the feature tip relative to the destination. Stop if fetch produces a conflicted base bookmark or if rebase produces unresolved file conflicts. Do not move the base bookmark until the intended rebased result is clear.

Run the project's established test command on the integrated working-copy revision. If the working copy is not at the integrated tip, create a new working-copy revision there first:

```bash
jj new <feature-tip-change-id>
```

If the integrated result fails, stop and investigate. Do not push or clean up. The operation log retains the local operations for inspection and recovery.

Once the integrated result is green, clean up a workflow-owned workspace as described in Step 6. If a feature bookmark exists, forget it locally without scheduling deletion of a same-named remote bookmark:

```bash
jj bookmark forget <feature-bookmark>
```

### Option 2: Push and Create a Pull Request

Before pushing, inspect every revision in the proposed range and ensure each non-empty revision has an appropriate description; `jj git push` rejects empty descriptions by default.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and commit-message syntax observed in `git log` at runtime always win. Apply only compatible Go guidance to message quality, clarity, and structure. Use `jj describe <revision>` for any description that must be composed or edited; do not impose a fixed message format or example.

Create a feature bookmark at the feature tip if none exists, or move the existing feature bookmark forward if needed, then push only that bookmark:

```bash
jj bookmark create <feature-bookmark> -r <feature-tip>
# If the bookmark already exists instead:
jj bookmark move <feature-bookmark> --to <feature-tip>
jj git push --remote <remote> --bookmark <feature-bookmark>
```

Create the pull request against the base bookmark with the forge's tooling. Follow the repository's pull-request template and conventions, and report the resulting URL. For GitHub, `gh` is acceptable; in a non-colocated Jujutsu repository, invoke it with `GIT_DIR=$(jj git root)` and explicit `--repo`, `--head <feature-bookmark>`, and `--base <base-bookmark>` arguments.

Keep the workspace because review feedback is handled there.

### Option 3: Keep As-Is

Report the retained feature revision or bookmark and workspace path in the local runtime's style. Make no repository changes.

### Explicit Discard Request

Discard is available only in response to an explicit request to throw the work away. Show the exact revisions selected by `<base-bookmark>..<feature-tip>`, the feature bookmark if present, and the workspace path. Explain that `jj abandon` removes revisions from visible history but the operation log may still recover them. Require the user to type `discard` before proceeding, while phrasing the warning in the local runtime's style.

After that exact confirmation, forget the local feature bookmark so no remote deletion is scheduled, abandon only the displayed revisions, and then perform Step 6 for a workflow-owned workspace:

```bash
jj bookmark forget <feature-bookmark>
jj abandon '<base-bookmark>..<feature-tip>'
```

Skip the bookmark command if there is no feature bookmark. Do not delete a remote bookmark unless the user separately and explicitly requests that remote action.

## Step 6: Clean Up a Workspace

Run this only after successful local integration or confirmed discard. Options 2 and 3 preserve the workspace.

The primary workspace is not disposable. Leave it in place.

For a workflow-owned workspace under `.tmp/workspaces/`, `.workspaces/`, or `workspaces/`, first inspect `jj status`. Jujutsu normally snapshots non-ignored files automatically, but ignored files can still exist only in that workspace. Inspect the filesystem for such files and explain what would be lost before deleting anything.

If unique files or unresolved work remain, offer locally styled choices to retain them in a described revision, move them to the primary workspace, or delete them. If the user chooses to describe a revision, apply this instruction:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and commit-message syntax observed in `git log` at runtime always win. Apply only compatible Go guidance to message quality, clarity, and structure. Use `jj describe` without prescribing fixed message syntax, then complete the selected integration or discard operation before returning to cleanup.

When the workspace is safe to remove, change to another retained workspace in the same repository, make the repository forget the disposable workspace by name, and delete that workspace's directory separately:

```bash
cd <retained-workspace-root>
jj workspace forget <workspace-name>
rm -rf <workspace-root>
```

`jj workspace forget` only removes workspace metadata; it does not delete files. Never run `rm -rf` unless the path has been verified as the exact workflow-owned workspace root and the preceding safety checks are complete.

For any other workspace path, the host environment owns it. Leave it in place and use a workspace-exit facility if the runtime provides one.

## Quick Reference

| Option | Rebase and advance base | Push bookmark | Keep workspace | Forget feature bookmark |
|--------|--------------------------|---------------|----------------|-------------------------|
| 1. Integrate locally | yes | no | primary only | yes, if present |
| 2. Create PR | no | yes | yes | no |
| 3. Keep as-is | no | no | yes | no |
| Discard, explicitly requested | no | no | primary only | yes, if present |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier in the session" | Run the suite on the revision being integrated. A green run proves only the tree it tested. |
| "They obviously want it integrated" | Integration is the user's decision. Present the choices and wait. |
| "They seem done, so I should offer discard" | Do not offer it. Discard happens only after an explicit request and confirmation. |
| "A bookmark is checked out, so it will follow new revisions" | Jujutsu has no active bookmark. Move the bookmark explicitly. |
| "Fetch is the same as pull" | Jujutsu has no direct pull equivalent. Fetch remote state, resolve bookmark conflicts, then rebase deliberately. |
| "The PR is open, so the workspace is clutter" | Review feedback is handled in that workspace. Preserve it. |
| "Forgetting the workspace deletes it" | `jj workspace forget` removes metadata only. Filesystem deletion is separate and guarded. |
| "Abandon is permanent" | Abandoned revisions leave visible history, but the operation log can often recover them. |
| "The base is obviously main" | Verify the divergence point and remote state before rebasing or moving bookmarks. |
| "The push was rejected, so force-push is required" | `jj git push` already applies lease-like safety checks. Fetch and resolve remote movement or bookmark conflicts rather than bypassing them. |
