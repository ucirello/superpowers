---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists via native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer the harness's native isolation tools. Fall back to `jj workspace` commands only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to `jj workspace add`. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check whether the harness already placed the session in an isolated workspace.** Session instructions or a harness-managed workspace are authoritative; do not create another workspace inside one.

Confirm that the current directory belongs to a Jujutsu workspace and inspect the registered workspaces:

```bash
jj workspace root
jj workspace list
```

`jj workspace root` prints the current workspace root. `jj workspace list` shows every workspace registered with the repository and its working-copy commit.

If the session is already isolated, skip to Step 2. Report:

> "Already in isolated workspace at `<path>`."

Merely being in a Jujutsu repository does not prove that the current workspace was created for this task. If the harness and instructions do not establish isolation, check whether the user already declared a workspace preference. If not, ask for consent:

> "Would you like me to set up an isolated workspace? It protects your current workspace from task changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**Use these mechanisms in order.**

### 1a. Native Isolation Tools (preferred)

If the harness provides a native command or tool for entering an isolated workspace, use it and skip to Step 2.

Native tools own directory placement, lifecycle, and cleanup. Creating a workspace manually when a native tool is available can produce state the harness cannot see or manage.

Only proceed to Step 1b when no native isolation tool is available.

### 1b. Jujutsu Workspace Fallback

Use `jj workspace add` to create a working copy backed by the current repository.

#### Directory Selection

Explicit user preferences always win. Otherwise, place temporary workspaces under `.tmp` at the current workspace root:

```bash
root=$(jj workspace root 2>/dev/null || pwd)
path="$root/.tmp/$WORKSPACE_NAME"
```

Use a unique, filesystem-safe workspace name. Jujutsu defaults the workspace name to the destination directory's basename; pass `--name` when those should differ.

#### Ignore Verification

Before creating a project-local workspace, verify that the root `.tmp/` directory is ignored by the repository's ignore rules. Jujutsu honors `.gitignore` files; there is no `.jjignore`.

If `.tmp/` is not ignored, add it to the root `.gitignore` and record that change according to the project's normal workflow before proceeding.

**Why critical:** Jujutsu automatically tracks new files by default. Ignoring `.tmp/` prevents one workspace from tracking another workspace's files.

#### Choose the Starting Revision

Ask for or infer the intended base revision from the task and repository conventions. A local bookmark, a remote bookmark such as `main@origin`, or another unambiguous revset can identify the base. Do not create a bookmark merely to create a workspace; workspaces and bookmarks are independent concepts.

If no base is specified, `jj workspace add` creates the new working-copy commit with the same parent or parents as the current working-copy commit. Prefer an explicit `-r` when the task has a known base.

#### Create the Workspace

```bash
jj workspace add --name "$WORKSPACE_NAME" -r "$BASE_REVISION" "$path"
cd "$path"
jj workspace root
jj status
```

`jj workspace add -r` creates a new working-copy commit whose parent is the specified revision. It does not check out that revision directly and does not create or move a bookmark.

If the workflow later requires a bookmark for publishing, create it at the completed change with `jj bookmark create "$BOOKMARK_NAME" -r @`. Use `jj bookmark set` only when intentionally creating or updating a bookmark under the repository's conventions.

**Sandbox fallback:** If `jj workspace add` fails because the sandbox denies directory creation, tell the user that the sandbox blocked workspace creation and work in the current directory instead. Then run setup and baseline tests in place.

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

Run tests to ensure the workspace starts clean:

```bash
# Use project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```text
Workspace ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Descriptions and Commit Messages

When composing a Jujutsu change description or a commit message, follow runtime-local conventions rather than imposing a fixed syntax:

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Inspect repository-local instructions and relevant history at runtime. Their
syntax and style always win; apply the Go guidance only where compatible by
keeping the first line concise and using a plain-text body to explain what
changed and why when useful. Never impose a fixed type, scope, prefix, subject,
body, or template.

## Cleanup

When a manually created workspace is no longer needed, first identify its registered name and root:

```bash
jj workspace list
jj workspace root --name "$WORKSPACE_NAME"
```

From another workspace, stop tracking its working-copy commit:

```bash
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` does not modify or delete files on disk. Remove the workspace directory separately only after confirming it contains nothing that must be retained. Harness-managed workspaces must be cleaned up with the harness's native lifecycle tools instead.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Harness already provides isolation | Skip creation (Step 0) |
| Native isolation tool available | Use it (Step 1a) |
| No native tool | Use `jj workspace add` (Step 1b) |
| User specifies a location | Use it |
| No location preference | Use root `.tmp/<workspace-name>` |
| Root `.tmp/` is not ignored | Add it to root `.gitignore` and record the change |
| Task has a known base | Pass it to `jj workspace add -r` |
| Publishing requires a bookmark | Create or set one explicitly at the intended revision |
| Permission error on create | Sandbox fallback; work in place |
| Tests fail during baseline | Report failures and ask |
| Workspace is finished | `jj workspace forget`, then separately remove files |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I can tell this is the main workspace without checking" | Run `jj workspace root` and `jj workspace list`, and honor harness context. Filesystem appearance alone does not establish isolation. |
| "Manual creation is quicker than finding the native tool" | The harness owns native workspace placement and cleanup. Bypassing it can create state the harness cannot manage. |
| "A workspace needs a matching bookmark" | Workspaces track working-copy commits. Bookmarks are separate references and are needed only for workflows such as publishing. |
| "Omitting `-r` starts from the current change" | By default, the new working-copy commit gets the current working-copy commit's parents, not the current working-copy commit itself. Pass the intended base explicitly. |
| "The `.tmp` directory is surely ignored" | Verify it. Jujutsu automatically tracks new files unless ignore rules exclude them. |
| "Forgetting a workspace deletes it" | `jj workspace forget` only removes repository tracking. Files remain on disk until removed separately. |
| "The workspace is fresh, so baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is the user's call. |
