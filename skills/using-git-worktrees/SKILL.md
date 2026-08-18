---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Detect existing isolation before creating anything, then use `jj workspace` commands so every working copy remains attached to the same repository.

**Core principle:** Detect existing isolation first. Create a dedicated workspace only with consent. Identify work by revisions and change IDs, not by an active branch.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, inspect the current workspace and all registered workspaces.**

```bash
current_root=$(jj workspace root)
jj workspace list
jj status
```

`jj workspace root` prints the current workspace root. `jj workspace list` prints each registered workspace with its working-copy revision and, when available, its root path. Use the list, the current path, and the session context to determine whether the current workspace was already created as task isolation. Do not infer an active branch: Jujutsu has no active/current bookmark.

If the current workspace is already dedicated to this task, do not create another one. Report:

> "Already in isolated workspace at `<path>` on revision `<change-id>` (`<commit-id>`)."

Use `jj log -r @` when the working-copy revision or its bookmarks need inspection. A bookmark is only a named pointer to a revision; its presence or absence does not determine whether the workspace is isolated.

If the current workspace is not dedicated to the task, check whether the user has already declared a workspace preference. If not, ask for consent:

> "Would you like me to set up an isolated workspace? It protects the current working copy from task changes."

Honor an existing declared preference without asking. If the user declines, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**Use these mechanisms in order.**

### Prefer Native Workspace Tools

After the user has consented to isolation, first use any harness-native facility already available, such as `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a workspace flag. Native tools own directory placement, lifecycle, and cleanup; bypassing one can create workspace state the harness cannot manage. Continue with the Jujutsu-specific inspection and description guidance below after entering the native workspace.

Only use the manual Jujutsu fallback when no native workspace tool is available.

### Jujutsu Workspace Fallback

### Choose The Parent Revision

Choose the revision the task should start from. Prefer an explicit revision from the user or plan. Otherwise use the appropriate local or remote bookmark after inspecting `jj bookmark list`; if no bookmark is appropriate, use the current working-copy parent `@-` rather than copying unfinished changes from `@`.

Jujutsu workspaces each have their own working-copy commit. Passing `-r <revision>` to `jj workspace add` creates the new workspace's working-copy commit on that revision. Without `-r`, the new working-copy commit receives the same parents as the current working-copy commit.

### Choose The Directory

Explicit user instructions always win. Otherwise keep temporary workspaces under the current workspace root:

```bash
project_root=$(jj workspace root 2>/dev/null || pwd -P)
workspace_base="$project_root/.tmp/workspaces"
workspace_path="$workspace_base/$WORKSPACE_NAME"
```

The `pwd -P` fallback applies only if `jj workspace root` cannot resolve the root. Do not use a global temporary directory. Ensure `.tmp/` is ignored before creating a workspace beneath it; Jujutsu honors `.gitignore` files and automatically tracks new, non-ignored files when it snapshots the working copy. If `.tmp/` is not ignored, ask before changing ignore rules or choose another user-approved project-local path.

### Create And Enter The Workspace

```bash
mkdir -p "$workspace_base"
jj workspace add --name "$WORKSPACE_NAME" -r "$START_REVISION" "$workspace_path"
cd "$workspace_path"
jj workspace root
jj workspace list
jj status
```

Use a unique workspace name. If creation fails because the destination or name already exists, inspect `jj workspace list` and reuse the matching workspace only when it belongs to this task; otherwise choose a different name. If creation is blocked by filesystem permissions, report the block and ask whether to use another project-local path or work in place.

Do not stage files. Jujutsu snapshots working-copy changes automatically at the start of nearly every `jj` command, and updates the working copy after commands that modify `@`. `jj status` both snapshots and reports the current working-copy revision.

### Describe The Change

When the task is understood, compose a useful change description based on the repository's descriptions and the task. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and commit-message syntax observed in `git log` at runtime always win; apply compatible Go guidance to quality, clarity, and structure without imposing a fixed prefix, template, or syntax. Then run `jj describe` and enter the composed description in the configured editor.

## Step 2: Project Setup

Inspect the project's own contributor instructions and use its documented setup procedure. If the project has no setup guidance, retain the conservative language-specific fallback:

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

Run setup from the isolated workspace so generated and ignored files remain local to it.

## Step 3: Verify Clean Baseline

Run the project's documented baseline checks before implementation. If no command is documented, use the project-appropriate fallback (`npm test`, `cargo test`, `pytest`, or `go test ./...`). Record the exact commands and results.

**If checks fail:** Report the pre-existing failures and ask whether to proceed or investigate.

**If checks pass:** Report the workspace ready.

### Report

```text
Workspace ready at <full-path>
Revision <change-id> (<commit-id>)
Baseline checks passing (<summary>)
Ready to implement <feature-name>
```

## Finishing And Cleanup

Work remains attached to its Jujutsu revision even without a bookmark. If a stable name is needed for collaboration or GitHub, create or move a bookmark explicitly with `jj bookmark set <name> -r <revision>` after inspecting existing bookmarks. Do not describe a bookmark as checked out or current.

Before removing a workspace, identify its work by change ID, make sure the work is preserved where intended, and leave the workspace directory. Then unregister it from another workspace:

```bash
jj workspace list
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` does not delete files from disk. Delete the directory separately only with explicit approval and only after confirming it contains no needed untracked or ignored files. If another workspace becomes stale because its working-copy commit was rewritten elsewhere, enter that workspace and run `jj workspace update-stale`.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in task-specific workspace | Skip creation |
| Native workspace tool available | Use it before the manual fallback |
| Need current root | `jj workspace root` |
| Need registered workspaces | `jj workspace list` |
| Need a new isolated workspace | `jj workspace add --name <name> -r <revision> <path>` |
| No start revision specified | Inspect bookmarks; usually start at the appropriate bookmark or `@-` |
| Need task name on a revision | `jj bookmark set <name> -r <revision>` |
| Need working-copy state | `jj status` |
| Need workspace cleanup | `jj workspace forget <name>`; files remain on disk |
| Workspace is stale | `jj workspace update-stale` from that workspace |
| Permission error on create | Ask for another project-local path or consent to work in place |
| Baseline checks fail | Report failures and ask |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously isolated; no need to check" | Run `jj workspace root` and `jj workspace list`. Existing harness-created workspaces are easy to miss. |
| "Manual `jj workspace add` is quicker than using the native tool" | Native tools own placement and cleanup. Bypassing them creates state the harness may not manage. |
| "I should create a branch for the workspace" | Jujutsu workspaces have independent working-copy commits. Bookmarks are optional named revision pointers, not active branches. |
| "I need to stage selected files" | Jujutsu has no staging index. It automatically snapshots non-ignored working-copy changes. |
| "A system temp directory is safer" | Keep temporary workspace paths under `$(jj workspace root)/.tmp`; fall back to `$(pwd -P)/.tmp` only when the root cannot be resolved. |
| "Forgetting the workspace deletes it" | `jj workspace forget` only unregisters it. Files remain until separately removed. |
| "The workspace is fresh; baseline checks can wait" | A failing baseline makes later failures ambiguous. Run the documented checks now; proceeding past failures is the user's call. |
