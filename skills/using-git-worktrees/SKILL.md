---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Detect isolation supplied by the user or harness first; otherwise create a workspace with `jj workspace add`.

**Core principle:** A Jujutsu workspace is a separate working copy with its own working-copy commit. Bookmarks are shared named pointers, not checked-out branches, and are optional unless the work must be pushed or referred to by name.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated Jujutsu workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, verify that the current directory is in a Jujutsu repository and inspect its workspaces.**

```bash
workspace_root=$(jj workspace root) || exit 1
jj workspace list
jj status
```

`jj workspace root` is the authoritative current-workspace-root lookup. `jj workspace list` shows every working copy attached to the repository. Each listed workspace has its own working-copy commit, shown as `<workspace-name>@` in `jj log`.

If the user, harness, or current session says the current workspace was created for this task, trust that signal. Report `Already in isolated workspace at <path>.` and skip to Step 2. Do not infer isolation merely from a bookmark: Jujutsu has no active or checked-out bookmark.

If there is no explicit isolation signal, ask for consent unless the user already requested a workspace:

> "Would you like me to set up an isolated Jujutsu workspace? It keeps this task's working-copy commit separate from the current workspace."

Honor a declared preference without asking. If the user declines, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

### 1a. Native Workspace Tools

If the harness provides a native isolation tool such as `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag, use it and skip to Step 2. Native tools keep harness workspace state synchronized. Only create a Jujutsu workspace manually when no native isolation tool is available.

### 1b. Select a Path

Follow this priority order. Explicit user instructions always win:

1. Use the exact user-declared destination when one exists.
2. Use an existing `$(jj workspace root)/.workspaces/` directory.
3. Otherwise use an existing `$(jj workspace root)/workspaces/` directory.
4. If neither exists, default to `$(jj workspace root)/.workspaces/`.

Resolve and quote the path instead of assuming the current directory is the project root:

```bash
workspace_root=$(jj workspace root) || exit 1
workspace_name="$WORKSPACE_NAME"
workspace_parent="$workspace_root/.workspaces"  # Replace with the selected parent.
path="$workspace_parent/$workspace_name"
```

Use a short, task-specific workspace name that is valid as a path component. Reject empty names, `.` or `..`, absolute names, and names containing `/` rather than allowing path traversal.

### 1c. Verify File-Tracking Safety

Jujutsu automatically tracks new files unless they match an ignore rule. Because the default destination is inside the current workspace, ensure the selected workspace directory is ignored by the root `.gitignore`. Jujutsu uses `.gitignore`; there is no `.jjignore`.

If the selected directory is not covered by the repository's ignore conventions, add it to the root `.gitignore`. If it was previously tracked, the ignore rule alone is insufficient; untrack it explicitly:

```bash
jj file untrack .workspaces
jj file list .workspaces
jj status
```

`jj file list <workspace-directory>` must produce no tracked paths before proceeding. `jj file untrack` requires the path to be ignored first. Do not use staging commands: Jujutsu has no index, and ordinary new files are included in the working-copy commit automatically.

If changing `.gitignore` creates a repository change that should stand alone, inspect `git log` and describe that change before creating the workspace. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-specific standards and observed history take precedence; apply compatible Go guidance without imposing fixed prefixes or example wording. Use `jj describe` to set the description and `jj new` to start a new working-copy change.

### 1d. Create the Workspace

By default, `jj workspace add` creates the new workspace's working-copy commit on the same parent or parents as the current working-copy commit. Supply `--revision` only when the task has a specific requested base.

```bash
jj workspace add --name "$workspace_name" "$path"
cd "$path"
jj status
```

If a base revision was requested:

```bash
jj workspace add --name "$workspace_name" --revision "$BASE_REVISION" "$path"
cd "$path"
jj status
```

If creation fails because the sandbox denies the destination, report the permission failure and work in the current workspace only with user approval.

### 1e. Create a Bookmark Only When Needed

Do not create a bookmark merely to emulate a branch. Create one when the user requested a named line of work, repository policy requires one, or the change will be pushed with `jj git push` or used by `gh`:

```bash
jj bookmark list "$BOOKMARK_NAME"
jj bookmark create "$BOOKMARK_NAME" --revision @
```

Choose a new bookmark name; do not move an existing bookmark implicitly. A bookmark created at `@` follows rewrites of that change, but it does not automatically advance to a descendant change. To move it deliberately later, use `jj bookmark move "$BOOKMARK_NAME" --to @`; add `--allow-backwards` only after confirming a backward or sideways move is intended.

## Step 2: Project Setup

Auto-detect and run the repository's documented setup. Keep all paths relative to the new `jj workspace root`. Store temporary files created in the workspace under `.tmp/`; do not invent global cache or temporary paths.

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

## Step 3: Verify Clean Baseline

Run the repository's documented test command to ensure the workspace starts clean:

```bash
npm test / cargo test / pytest / go test ./...
```

If setup or baseline tests fail, report the failure and ask whether to proceed or investigate.

### Report

```text
Jujutsu workspace ready at <full-path>
Tests passing: <summary>
Bookmark: <name or none>
Ready to implement <feature-name>
```

## Workspace Lifecycle

Workspaces share repository history, bookmarks, and the operation log, but each has its own working-copy commit and sparse patterns. Commands in one workspace can rewrite a commit checked out by another workspace; if that makes the other working copy stale, run `jj workspace update-stale` in that workspace before continuing.

When the workspace is no longer needed, use `jj workspace forget <workspace-name>` from another workspace, then remove its files separately only after confirming the path. Forgetting a workspace does not delete its directory. Never remove a workspace directory merely because its bookmark was deleted.

## Quick Reference

| Situation | Action |
|-----------|--------|
| User or harness confirms current isolation | Keep current workspace |
| Need repository root | `jj workspace root` |
| Need attached working copies | `jj workspace list` |
| Need isolated working copy | `jj workspace add --name <name> <path>` |
| Need a specific base | Add `--revision <revset>` |
| Need current state | `jj status` |
| Need tracked paths | `jj file list [paths]` |
| Ignored path is already tracked | `jj file untrack <path>` |
| Need a shared name for a revision | `jj bookmark create <name> --revision @` |
| Need to advance an existing bookmark | `jj bookmark move <name> --to @` |
| Workspace became stale | `jj workspace update-stale` in that workspace |
| Workspace is finished | `jj workspace forget <name>`, then remove files separately |
| Setup or baseline tests fail | Report failure and ask |

## Common Mistakes

### Treating Bookmarks as Branches

- **Problem:** Reporting a "current bookmark" or assuming a bookmark moves because a workspace is active.
- **Fix:** Treat bookmarks as shared pointers. Use `jj bookmark list` and move them explicitly when required.

### Sharing a Working-Copy Commit

- **Problem:** Reusing or editing another workspace's working-copy commit can make that workspace stale.
- **Fix:** Let `jj workspace add` create a distinct working-copy commit; use `jj workspace update-stale` when Jujutsu reports staleness.

### Using Staging Commands

- **Problem:** Applying index-based habits obscures what Jujutsu snapshots automatically.
- **Fix:** Use `jj status`, `jj diff`, `jj file list`, `jj file track`, and `jj file untrack`. Use `jj split` or `jj squash` when changes need separation.

### Ignoring an Already-Tracked Path

- **Problem:** Adding an ignore rule does not untrack files already present in a commit.
- **Fix:** Add the ignore rule first, run `jj file untrack <path>`, and verify with `jj file list <path>`.

### Assuming Directory Location

- **Problem:** Hard-coded or OS-global paths violate project conventions and may escape the writable workspace.
- **Fix:** Follow explicit instructions, then existing project-local workspace directories, then `.workspaces/`; quote every path.

## Red Flags

**Never:**
- Create another workspace after explicit confirmation that the current one is isolated.
- Describe a bookmark as active, current, checked out, or workspace-local.
- Move or overwrite an existing bookmark without explicit intent.
- Use an OS-global temporary directory.
- Create a nested workspace path while it is tracked.
- Assume an ignore rule untracks existing files.
- Delete files as part of `jj workspace forget` without separately validating the path.
- Skip baseline test verification.

**Always:**
- Run Step 0 first.
- Resolve the root with `jj workspace root` and quote paths.
- Prefer native harness isolation, then the repository's established workspace directory, then `.workspaces/`.
- Use `jj workspace add` for isolation.
- Store temporary files under the workspace-local `.tmp/` directory.
- Verify state with `jj status` and tracking with `jj file list`.
- Keep bookmarks optional and explicit.
- Auto-detect and run documented project setup.
- Verify a clean test baseline.
