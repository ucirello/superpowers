---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - creates and manages an isolated Jujutsu workspace
---

# Using Jujutsu Workspaces

## Overview

Use a separate Jujutsu workspace when work needs an isolated working copy. Workspaces share repository history and operations, but each has its own working-copy commit and files.

**Core principle:** Confirm the current workspace first, choose an explicit base revision, then create one registered workspace in a safe location.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Inspect Existing Workspaces

Before creating anything, confirm that this is a Jujutsu repository and inspect its registered workspaces:

```bash
CURRENT_ROOT=$(jj workspace root)
jj -R "$CURRENT_ROOT" workspace list
```

`jj workspace root` is authoritative for the current workspace. `jj workspace list` shows every workspace and its available root path.

If the current root is already the isolated workspace selected for this task, do not create another one. Report:

```
Already in isolated workspace at <full-path>.
```

Do not assume that the first or `default` workspace is isolated merely because Jujutsu calls every working copy a workspace. Use the path, workspace list, and the user's instructions to identify task-specific isolation.

If a registered workspace for this task already exists elsewhere, use `jj workspace root --name "$WORKSPACE_NAME"` to locate it and continue there rather than creating a duplicate.

If no task workspace exists and the user has not already requested or approved isolation, ask:

> "Would you like me to set up an isolated Jujutsu workspace? It keeps this task's working copy separate from your current one."

Honor an existing declared preference without asking. If the user declines, work in the current workspace and skip to Step 3.

## Step 1: Choose Base And Directory

### Base Revision

Run `jj status` in the current workspace before choosing the base:

```bash
REPO_ROOT=$(jj workspace root)
jj -R "$REPO_ROOT" status
```

Use the revision or bookmark named by the user. Otherwise use `@` only when its contents and parentage are the intended base. If the current working-copy commit contains unrelated changes or its base is ambiguous, stop and ask which revision or bookmark to use. Do not silently carry unrelated work into the new workspace.

Bookmarks are named revision pointers, not active branches. A workspace does not require a bookmark. Use `jj bookmark list` when selecting a named base, and create or move a bookmark only when the work needs a stable name for sharing or pushing.

### Directory Selection

Follow this order:

1. Use an explicit destination from the user's instructions.
2. Reuse the repository-local `.tmp/workspaces/` convention when it already exists.
3. Otherwise default to `<current-workspace-root>/.tmp/workspaces/<workspace-name>`.

Use a short, task-specific workspace name. Before creation, ensure `jj workspace list` contains neither that name nor destination.

### Safety Verification

A workspace nested under the current working copy must not be tracked by the containing workspace. Verify `.tmp/` is ignored before creating the destination. Use a temporary probe and remove it immediately:

```bash
REPO_ROOT=$(jj workspace root)
mkdir -p "$REPO_ROOT/.tmp"
PROBE="$REPO_ROOT/.tmp/.jj-ignore-check.$$.$RANDOM"
( set -C; : > "$PROBE" ) || { echo "could not create unique ignore probe" >&2; exit 1; }
trap 'rm -f -- "$PROBE"' EXIT
jj -R "$REPO_ROOT" file list ".tmp/${PROBE##*/}"
rm -f -- "$PROBE"
trap - EXIT
jj -R "$REPO_ROOT" status
```

The `jj file list` command snapshots the containing workspace. If it prints the probe path, `.tmp/` is not ignored. Add `.tmp/` to the repository's `.gitignore`, verify the probe again, and record that ignore change separately before proceeding. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and the message syntax established by repository history always win; inspect history with the runtime's available command. Apply compatible Go guidance to clarity and structure: use a concise summary that explains what the change does and add an explanatory body when useful. Do not impose a fixed prefix, type, scope, subject, or body. If the probe is silent, the path is ignored.

If the user selected a destination outside the current workspace, the nested-directory ignore check does not apply. Still reject a destination that is inside another registered workspace.

## Step 2: Create The Workspace

Create the workspace from the explicitly selected base. Always address the source repository dynamically rather than relying on the shell's current directory:

```bash
REPO_ROOT=$(jj workspace root)
DESTINATION=${DESTINATION:-"$REPO_ROOT/.tmp/workspaces/$WORKSPACE_NAME"}
jj -R "$REPO_ROOT" workspace add "$DESTINATION" --name "$WORKSPACE_NAME" -r "$BASE_REVISION"
WORKSPACE_ROOT=$(jj -R "$REPO_ROOT" workspace root --name "$WORKSPACE_NAME")
cd "$WORKSPACE_ROOT"
```

Do not pass a fixed `--message`. When the task's working-copy change receives a description, follow the composition standards above and derive it from the actual change.

Confirm registration and location:

```bash
jj workspace list
jj workspace root
jj status
```

If creation fails, report the exact error and stop. Do not fall back to another VCS CLI or silently work in place.

## Step 3: Project Setup

Auto-detect and run the appropriate repository setup in the selected workspace:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

Keep temporary setup artifacts under the repository-local `.tmp/` directory when the tool permits choosing their location.

## Step 4: Verify Clean Baseline

Run the project-appropriate baseline tests in the isolated workspace.

If tests fail, report the failures and ask whether to proceed or investigate. If tests pass, report:

```
Workspace ready at <full-path>
Baseline tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Stale Workspace Recovery

Operations in one workspace can rewrite another workspace's working-copy commit. If Jujutsu reports that the current workspace is stale, update it from inside that workspace:

```bash
WORKSPACE_ROOT=$(jj workspace root)
jj -R "$WORKSPACE_ROOT" workspace update-stale
jj -R "$WORKSPACE_ROOT" status
```

Review the result. `update-stale` can create a recovery commit when the operation previously associated with the working copy has been lost; do not discard that recovery commit without inspecting it.

## Bookmarks

Do not create a bookmark merely to imitate a branch-per-workspace workflow. Changes are identified independently of workspace names.

When the completed work needs a local name for sharing or pushing, inspect existing names first, then set the requested bookmark at the intended revision:

```bash
REPO_ROOT=$(jj workspace root)
jj -R "$REPO_ROOT" bookmark list
jj -R "$REPO_ROOT" bookmark set "$BOOKMARK_NAME" -r "$TARGET_REVISION"
```

Never move an existing bookmark without confirming that its current target and the requested target are correct.

## Cleanup

Use `superpowers:finishing-a-development-branch` when the surrounding workflow routes completion there. Before removing a task workspace, inspect its status and preserve any change that is still needed.

Run cleanup from another registered workspace, not from the directory being removed:

```bash
REPO_ROOT=$(jj workspace root)
WORKSPACE_ROOT=$(jj -R "$REPO_ROOT" workspace root --name "$WORKSPACE_NAME")
jj -R "$WORKSPACE_ROOT" status
test -n "$WORKSPACE_ROOT"
test "$WORKSPACE_ROOT" != "$REPO_ROOT"
jj -R "$REPO_ROOT" workspace forget "$WORKSPACE_NAME"
jj -R "$REPO_ROOT" workspace list
```

`jj workspace forget` only unregisters the workspace; it does not delete files. Forget only the named workspace. Retain the directory unless the user explicitly approves deleting all tracked, untracked, and ignored contents after reviewing the exact canonical path. If the status contains unpreserved work, stop before forgetting or deleting anything.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in the task workspace | Reuse it; do not create another |
| Task workspace registered elsewhere | Locate it with `workspace root --name` |
| Base revision is unclear | Ask; do not inherit unrelated `@` changes |
| No destination preference | Use `.tmp/workspaces/<workspace-name>` |
| `.tmp/` probe is tracked | Ignore `.tmp/`, record that change separately, and verify again |
| Need isolated working copy | `jj workspace add <destination> --name <name> -r <base>` |
| Need a branch-like name | Set a bookmark only when sharing or pushing requires one |
| Workspace is stale | Run `jj workspace update-stale` inside it |
| Creation fails | Report and stop; no other VCS fallback |
| Cleanup approved | Inspect, forget by name, and retain files unless deletion is explicitly approved |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Every Jujutsu checkout is already isolated" | Every checkout is a workspace, but the current one may be the user's primary working copy. Inspect the registered roots. |
| "Using `@` is always safe" | `@` may contain unrelated changes or have unintended parents. Confirm the base explicitly. |
| "A nested workspace cannot be tracked" | The containing workspace sees ordinary files unless `.tmp/` is ignored. Run the probe first. |
| "The workspace name is basically a branch" | Workspace names identify working copies; bookmarks identify revisions for sharing and pushing. |
| "Forgetting cleans up the directory" | `jj workspace forget` only unregisters metadata. Inspect first and delete the exact returned root separately. |
| "A stale warning can be ignored" | Another operation may have rewritten the working-copy commit. Run `update-stale` and inspect any recovery commit. |
