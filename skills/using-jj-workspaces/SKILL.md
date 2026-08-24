---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Prefer a harness-provided Jujutsu workspace tool when one exists; otherwise use `jj workspace add` directly.

**Core principle:** Detect existing isolation first. Then use native tools. Then use `jj workspace add`. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated Jujutsu workspace."

## Step 0: Inspect Existing Workspace State

**Before creating anything, check whether the current directory is already a dedicated workspace.**

```bash
CURRENT_ROOT=$(jj workspace root)
jj workspace list
jj status
jj log -r @ --no-graph
```

`jj workspace list` is the source of truth for the repo's workspaces and their working-copy revisions. Compare its recorded paths with `CURRENT_ROOT` and the surrounding session context.

**If the harness or user placed the session in a dedicated workspace:** Skip to Step 2. Do not create another workspace.

Report its revision state:

> Already in isolated Jujutsu workspace at `<path>`, editing `<change-id>`.

Do not report an "active bookmark." Jujutsu has no active/current/checked-out bookmark. A bookmark is only a named pointer to a revision, and a workspace owns an independent working-copy revision (`@`).

**If this is the session's ordinary/default workspace:** Check whether the user already authorized isolated workspace creation. If not, ask:

> Would you like me to set up an isolated Jujutsu workspace? It keeps this workspace's working-copy revision undisturbed.

Honor any existing declared preference without asking. If the user declines, work in place and skip to Step 2.

Before selecting a base revision, inspect `jj status`:

- If `@` contains no file changes, use `@` as the base.
- If `@` contains changes, do not silently carry them into or exclude them from the new workspace. Ask whether to base the workspace on `@` or on another revision.
- If the user named a bookmark or revision, resolve and use that revision. A bookmark name is valid revision syntax, but it does not become active in the new workspace.

## Step 1: Create Isolated Workspace

### 1a. Harness-Provided JJ Workspace Tool

If the platform provides a tool that explicitly creates a **Jujutsu workspace**, use it and skip to Step 2. The user's consent from Step 0 is authorization to invoke that tool.

Do not use a workspace mechanism that fails to register the working copy in `jj workspace list`.

### 1b. `jj workspace add`

Use this when no harness-provided JJ workspace tool exists.

#### Directory Selection

Follow this priority order. Explicit user preference always wins.

1. Use the workspace location declared in the user's instructions.
2. Use an established project-local workspace directory such as `.rocketclaw/workspaces/` or `.workspaces/` only if its ignore coverage is already demonstrable.
3. Otherwise use a sibling directory outside the current workspace root: `$(dirname "$CURRENT_ROOT")/rocketclaw-workspaces/<project>/<workspace-name>/`.
4. If the sandbox denies that sibling location, try the repo-local fallback `$CURRENT_ROOT/.tmp/workspaces/<workspace-name>/`, but only when `.tmp/` is already ignored.
5. If no safe destination is writable, report the sandbox restriction and work in place.

Never use a global temporary directory for this fallback.

#### Safety Verification for Project-Local Destinations

Jujutsu honors `.gitignore` files; there is no `.jjignore`. Before creating a workspace beneath the current workspace root, inspect the applicable `.gitignore` files and verify that the exact destination is covered.

Do not infer ignore coverage merely because a directory exists. Do not create a probe file: most JJ commands snapshot new, non-ignored files automatically. If ignore coverage is absent or ambiguous, choose the sibling location instead of modifying repository content as a side effect of workspace setup.

**Why critical:** A nested workspace contains a working copy and `.jj/` metadata. The containing workspace must not snapshot it.

#### Create the Workspace and Revision

Choose a unique workspace name and an already-resolved base revision. Pass the base explicitly because omitting `-r` creates a sibling of the current working-copy revision, based on its parents, which may not preserve the intended base.

```bash
path="$LOCATION/$WORKSPACE_NAME"

jj workspace add "$path" --name "$WORKSPACE_NAME" -r "$BASE_REVISION"
cd "$path"
jj workspace root
jj workspace list
jj status
```

`jj workspace add -r <revision>` creates a new empty working-copy revision on top of that revision. The destination must not already contain files, and the workspace name must be unique.

If the feature needs a bookmark now, create it explicitly at the working-copy revision:

```bash
jj bookmark create "$BOOKMARK_NAME" -r @
```

Do this only when the user or workflow requires a named pointer. The workspace itself does not require a bookmark. Later, move an existing bookmark with `jj bookmark move <name> --to <revision>`; use `jj bookmark set` only when create-or-update behavior is intentional.

**Sandbox fallback:** If creation outside the repo fails with a permission error, retry under the ignored repo-local `$CURRENT_ROOT/.tmp/workspaces/` location. If that location is not already ignored or also fails, tell the user the sandbox blocked workspace creation and continue in the current workspace.

## Step 2: Project Setup

Auto-detect and run appropriate setup:

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

Run tests to ensure the workspace starts from a known baseline:

```bash
# Use the project-appropriate command
npm test / cargo test / pytest / go test ./...
```

Then run `jj status`. Setup may create ignored build artifacts, but it must not introduce unexpected tracked changes into the new working-copy revision.

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```text
Jujutsu workspace ready at <full-path>
Working-copy revision: <change-id>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Cleanup

Workspace metadata and files are separate. When an agent-owned workspace is no longer needed, leave it, run `jj workspace forget <workspace-name>` from another workspace, and delete its directory separately. Never forget or delete a harness-owned workspace unless the harness explicitly directs that cleanup.

If another workspace rewrites this workspace's working-copy revision and it becomes stale, run `jj workspace update-stale` inside the stale workspace before continuing.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in dedicated JJ workspace | Skip creation (Step 0) |
| Harness provides a JJ workspace tool | Use it (Step 1a) |
| No native JJ workspace tool | Use `jj workspace add` (Step 1b) |
| Current `@` has changes | Ask which base revision to use |
| Project-local location is provably ignored | It is safe to use |
| Ignore coverage is absent or ambiguous | Use sibling `rocketclaw-workspaces/` location |
| Sibling path is sandbox-blocked | Try ignored repo-local `.tmp/workspaces/` |
| No safe writable destination | Work in place and report why |
| Bookmark required | Create or move it explicitly |
| Tests fail during baseline | Report failures and ask |
| Workspace becomes stale | Run `jj workspace update-stale` |
| Agent-owned workspace is finished | `jj workspace forget`, then delete files separately |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a workspace; no need to check" | Every JJ working copy is a workspace, and harness-created isolation is easy to miss. Inspect `jj workspace list` and the recorded paths. |
| "A bookmark tells me which workspace I'm on" | JJ has no active bookmark. The workspace's `@` revision is the state that matters. |
| "Omitting `-r` should copy my current revision" | By default, `jj workspace add` bases the new working-copy revision on the current working-copy revision's parents. Pass the intended base explicitly. |
| "A nested directory is probably ignored" | JJ auto-tracks new files. Verify the applicable `.gitignore` rule or create the workspace outside the current root. |
| "I'll use a global temp directory if the sandbox blocks the path" | Use the ignored repo-local `.tmp/workspaces/` fallback. If it is unsafe or blocked, work in place. |
| "The workspace needs a feature bookmark" | Workspaces and bookmarks are independent. Create a bookmark only when a workflow or remote interaction needs one. |
| "Deleting the directory cleans up the workspace" | The repo still records it. Run `jj workspace forget <name>` and remove files separately. |
| "The workspace is fresh; baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
