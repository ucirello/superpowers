---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion by presenting structured options for local integration, a pull request, preservation, or cleanup
---

# Finishing Development Work

## Overview

Guide completion of development work by presenting clear options and handling the chosen Jujutsu workflow.

**Core principle:** Verify tests and descriptions -> detect revisions and workspace ownership -> present options -> execute choice -> clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run the project's test suite.
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**

```text
Tests failing (<N> failures). Must fix before completing:

<failure output>

Cannot proceed with integration or a pull request until tests pass.
```

Stop. Do not proceed to Step 2.

### Step 2: Detect Revision and Workspace State

Jujutsu has no active bookmark and no detached-HEAD mode. Identify revisions explicitly rather than inferring them from checkout state.

```bash
jj status
jj log -r '@ | @- | bookmarks()'
jj bookmark list -r '@ | @-'
jj workspace list
WORKSPACE_PATH=$(jj workspace root)
```

Determine and retain these values:

| Value | How to determine it |
|-------|---------------------|
| `<feature-tip>` | `@` when the working-copy revision contains the completed change; otherwise `@-` when `@` is the new empty revision above it |
| `<feature-bookmark>` | A local bookmark at `<feature-tip>`, if one exists; otherwise leave unset until an option requires one |
| `<workspace-name>` | Match the working-copy change ID shown by `jj log -r @` to `jj workspace list` |
| `<workspace-path>` | The exact output of `jj workspace root` |

If the revision selection is ambiguous, ask which revision is the completed feature tip before offering destructive or remote operations.

### Step 3: Determine the Base Bookmark

Inspect likely bases without assuming one from a branch name:

```bash
jj bookmark list main master
jj log -r 'heads((::<feature-tip> & bookmarks()) ~ <feature-tip>)'
```

Use the repository's actual primary bookmark. If more than one candidate remains, ask: "Is `<base-bookmark>` the integration base for this work?"

Now inspect and retain the candidate revisions before any fetch can move the base bookmark:

```bash
jj log -r '<base-bookmark>..<feature-tip>'
git log -n <history-count> --format=%B
# Record each candidate as an immutable commit ID for later repeated -r arguments.
jj log --no-graph -r '<base-bookmark>..<feature-tip>' -T 'commit_id ++ "\n"'
```

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Runtime repository syntax and history take precedence. Apply compatible Go commit-message guidance without imposing a fixed prefix, message, or template. Every non-empty candidate revision must have an accurate description suitable for the repository. Edit a deficient description with `jj describe <revision>` and inspect the stack again. Refresh the retained immutable commit IDs after any edit. Do not continue until descriptions satisfy the repository's present standards.

### Step 4: Present Options

Present exactly these four options:

```text
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a pull request
3. Keep the work as-is (I'll handle it later)
4. Discard this work

Which option?
```

Do not add explanation; keep the options concise.

### Step 5: Execute Choice

#### Option 1: Integrate Locally

Fetch the configured remote, rebase exactly the retained feature revisions onto the updated base, and advance the base bookmark. Jujutsu preserves dependencies within a `--revision` set and follows rewritten revisions by change ID.

```bash
jj git fetch --remote <remote>
jj rebase -r <retained-commit-id-1> -r <retained-commit-id-2> ... -o <base-bookmark>
jj bookmark move <base-bookmark> --to <feature-tip>

# Verify tests on the integrated result.
jj edit <base-bookmark>
<test command>
```

If rebasing produces conflicts, resolve them and rerun the tests before cleanup. Do not push the base bookmark unless explicitly requested.

Only after integration and tests succeed, clean up the workspace in Step 6. Inspect local and remote state with `jj bookmark list --all-remotes <feature-bookmark>`. If `<feature-bookmark>` exists only for this work and was never pushed, forget it without scheduling a remote deletion:

```bash
jj bookmark forget <feature-bookmark>
```

Use `jj bookmark delete <feature-bookmark>` instead only when the user explicitly wants a tracked remote bookmark deleted on the next push.

#### Option 2: Push and Create a Pull Request

Ensure a named bookmark points to the feature tip. Create it if absent; otherwise move it explicitly because bookmarks do not automatically advance when new revisions are added on top.

```bash
jj bookmark create <feature-bookmark> -r <feature-tip>
# Or, when it already exists:
jj bookmark move <feature-bookmark> --to <feature-tip>

jj git push --bookmark <feature-bookmark> --remote <remote>
```

Compose the pull request title and body from the verified revisions and repository requirements, using placeholders rather than a fixed title or body.

```bash
GIT_DIR=$(jj git root) gh pr create \
  --base <base-bookmark> \
  --head <feature-bookmark> \
  --title '<pull-request-title>' \
  --body '<pull-request-body>'
```

Do not clean up the workspace; it is needed to address review feedback.

#### Option 3: Keep As-Is

Report: "Keeping revision `<feature-tip>`<and bookmark ` <feature-bookmark>` when present>. Workspace preserved at `<workspace-path>`."

Do not clean up the workspace or create a bookmark solely for this option.

#### Option 4: Discard

Show the exact revisions first:

```bash
jj log -r '<base-bookmark>..<feature-tip>'
```

Confirm with a neutral, runtime-populated prompt:

```text
This will abandon:
- Bookmark: <feature-bookmark-or-none>
- Revisions: <revision-list>
- Workspace: <workspace-path-and-ownership-action>

Type 'discard' to confirm.
```

Wait for exact confirmation. If confirmed, abandon only the displayed feature revset. This is recoverable through Jujutsu's operation log, unlike a destructive filesystem reset.

```bash
jj abandon '<base-bookmark>..<feature-tip>'
```

Abandoning revisions deletes local bookmarks that point to them. If a corresponding tracked remote bookmark exists, do not push its deletion unless the user explicitly requests that remote effect. Then clean up an owned workspace in Step 6.

### Step 6: Clean Up an Owned Workspace

Only run for Options 1 and 4. Options 2 and 3 always preserve the workspace.

Jujutsu workspace registration and filesystem cleanup are separate. Before either action, record the exact workspace name and path, and select a surviving workspace from `jj workspace list` for repository commands after cleanup.

```bash
WORKSPACE_PATH=$(jj workspace root)
jj workspace list
```

Apply path provenance rules:

| Workspace state | Action |
|-----------------|--------|
| Durable/default workspace | Do not forget or remove it |
| Workspace strictly beneath `<durable-root>/.worktrees/` or `<durable-root>/worktrees/` | Owned; cleanup is permitted |
| Any other path | Externally managed; do not forget or remove it |

Never infer ownership from the workspace name alone. Obtain `<durable-root>` from `jj workspace root --name <durable-workspace>`, resolve both paths physically, and require the workspace path to be a strict child of one of those two managed directories. Reject an equal path, a parent path, symlink escape, or any path containing unresolved traversal.

For an owned workspace, leave its directory before forgetting it. Run the command from a surviving workspace so the repository remains addressable:

```bash
SURVIVING_ROOT=$(jj workspace root --name <surviving-workspace>)
cd "$SURVIVING_ROOT"
jj workspace forget <workspace-name>
```

After `jj workspace forget` succeeds, remove the forgotten workspace directory with the platform's approved workspace-removal mechanism. If none exists, leave the files in place and report the path; `jj workspace forget` deliberately does not delete files.

### Repository-Local Temporary Paths

If any completion step needs temporary files, use the repository workspace rather than an operating-system temporary directory:

```bash
if REPO_ROOT=$(jj workspace root 2>/dev/null); then
  TEMP_ROOT="$REPO_ROOT/.tmp"
else
  TEMP_ROOT="$PWD/.tmp"
fi
mkdir -p "$TEMP_ROOT"
```

Create task-specific children beneath `$TEMP_ROOT`, clean them when finished, and never use an operating-system temporary path, an environment-provided temporary directory, or a random temporary-file utility.

## Quick Reference

| Option | Rebase/integrate | Push | Keep workspace | Bookmark cleanup |
|--------|------------------|------|----------------|------------------|
| 1. Integrate locally | yes | no | only if unowned | forget local feature bookmark when appropriate |
| 2. Create pull request | no | yes | yes | no |
| 3. Keep as-is | no | no | yes | no |
| 4. Discard | abandon selected revisions | no | only if unowned | automatic for bookmarks on abandoned revisions |

## Common Mistakes

**Treating bookmarks like checked-out branches**
- **Problem:** Assuming a bookmark advances with new child revisions
- **Fix:** Identify `<feature-tip>` explicitly and move or create the bookmark before pushing

**Skipping test or description verification**
- **Problem:** Integrating broken code or publishing inaccurate revision descriptions
- **Fix:** Verify tests and inspect every candidate revision before offering options

**Using pull semantics that do not exist**
- **Problem:** Expecting one command to fetch and integrate remote changes
- **Fix:** Run `jj git fetch`, then explicitly rebase the feature stack onto the updated base bookmark

**Deleting a bookmark when forgetting is intended**
- **Problem:** `jj bookmark delete` schedules deletion on tracked remotes at the next applicable push
- **Fix:** Use `jj bookmark forget` for local-only cleanup

**Cleaning up the workspace for Option 2**
- **Problem:** Removing the workspace needed for review iteration
- **Fix:** Only clean up for Options 1 and 4

**Removing files before forgetting an owned workspace**
- **Problem:** Leaving stale workspace registration
- **Fix:** From a surviving workspace, run `jj workspace forget <workspace-name>` before approved filesystem removal

**Cleaning up an externally managed workspace**
- **Problem:** Removing a workspace owned by another process causes stale external state
- **Fix:** Require strict managed-path provenance; otherwise preserve it

**Using an operating-system temporary directory**
- **Problem:** Files escape repository-local path controls and cleanup expectations
- **Fix:** Use `$(jj workspace root)/.tmp`, with local `.tmp` only when no workspace root is available

## Red Flags

**Never:**
- Proceed with failing tests or deficient change descriptions
- Integrate without verifying tests on the rebased result
- Abandon revisions without displaying the exact revset and receiving typed confirmation
- Push a base bookmark or remote deletion without explicit approval
- Assume a bookmark is current because it names the feature
- Forget or remove an externally managed workspace
- Remove workspace files before `jj workspace forget` succeeds
- Use a system temporary path or utility

**Always:**
- Identify the feature tip and base bookmark explicitly
- Let runtime repository syntax and history override generic conventions
- Present exactly four options
- Get typed confirmation for discard
- Preserve the workspace for push and keep-as-is choices
- Check strict path provenance before workspace cleanup
- Run cleanup commands from a surviving workspace
