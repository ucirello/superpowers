---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Each workspace has its own working-copy commit while sharing the same repository.

**Core principle:** Detect existing isolation first, then create a Jujutsu workspace only when needed.

**Announce at start:** State that you are using the `using-git-worktrees` skill to set up an isolated workspace.

## Message Composition

At every reporting point below: Write complete sentences with correct punctuation, just like for your comments in Go. Repository-local message syntax takes precedence. The examples describe required information, not fixed wording, and must not be copied as a rigid template.

## Step 0: Detect Existing Isolation

**Before creating anything, verify that `jj` is available and the current directory belongs to a Jujutsu workspace.**

```bash
command -v jj >/dev/null 2>&1 && CURRENT_ROOT=$(jj workspace root 2>/dev/null)
```

If either check fails, explain that Jujutsu workspace isolation is unavailable and work in the current directory. Do not create a substitute with `/tmp`, `TMPDIR`, `mktemp`, `tempfile`, or another version-control system. Continue at Step 2.

Inspect the registered workspaces and current workspace root:

```bash
jj workspace list
jj workspace root
```

Treat the current workspace as created by this procedure only when its root is
the expected repository-root `.tmp/<workspace-name>` path and its registered
name and root agree with `jj workspace list`. Do not infer ownership from an
arbitrary `/.tmp/` substring. If it matches, report its full root and continue
at Step 2.

A harness may provide isolation outside `.tmp`. If the harness identifies the current directory as its isolated workspace, trust that state, report the root from `jj workspace root`, and continue at Step 2.

Otherwise, honor any existing instruction that grants or declines workspace creation. If no preference exists, ask whether to create an isolated Jujutsu workspace to protect the current working copy. If consent is declined, work in place and continue at Step 2.

## Step 1: Create Isolated Workspace

### Choose the Name and Path

Use a repository-local workspace naming convention when one exists. Otherwise derive a short, unique, filesystem-safe name from the task. Repository-local syntax always wins.

All manually created workspaces go under `.tmp` at the current Jujutsu workspace root. Do not use a system temporary directory or environment-provided temporary directory.

Before creating one, verify that the workspace root's `.gitignore` contains
`.tmp/`. If it does not, add that exact repository-local ignore rule before
creating the directory; otherwise the parent workspace can snapshot the nested
workspace files.

Before creating the workspace, use `jj workspace list` to avoid reusing a registered name. If the desired name is registered, inspect its root before deciding whether to reuse it:

```bash
jj workspace list
jj workspace root --name "$WORKSPACE_NAME"
```

Reuse it only when it is the intended workspace and its directory is available.
In that case, set `WORKSPACE_PATH=$(jj workspace root --name
"$WORKSPACE_NAME")`, enter it, and continue at Step 2. Otherwise choose a new
unique name. Do not forget an existing workspace merely to reuse its name.

### Create the Workspace

```bash
ROOT=$(jj workspace root)
WORKSPACE_PATH="$ROOT/.tmp/$WORKSPACE_NAME"
mkdir -p "$ROOT/.tmp"
jj workspace add --name "$WORKSPACE_NAME" "$WORKSPACE_PATH"
cd "$WORKSPACE_PATH"
```

With no revision argument, `jj workspace add` creates a new working-copy commit on the parent or parents of the current working-copy commit. This isolates new work from changes in the original workspace.

If creation fails, report the reason and work in the current directory only after the user agrees to proceed without isolation. Do not fall back to another version-control system or an external temporary directory.

## Step 2: Project Setup

Auto-detect and run the appropriate repository setup. Repository-local setup instructions take precedence over these examples.

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

Run the repository's baseline verification command so later failures can be distinguished from pre-existing failures.

```bash
# Use the repository-appropriate command.
npm test / cargo test / pytest / go test ./...
```

If verification fails, report the failures and ask whether to proceed or investigate. If it passes, report the full workspace path, the successful baseline, and readiness for the requested work.

## Cleanup

After the work no longer needs an isolated workspace, record its change ID and
confirm that the working-copy change is empty, landed, or retained by the
intended bookmark or a descendant. Then leave that workspace and forget it from
another registered workspace:

```bash
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` only stops tracking the workspace's working-copy commit;
it does not remove files from disk. Do not forget a workspace whose change is
not safely retained. Remove `"$WORKSPACE_PATH"` separately only after confirming
that no needed changes remain, including ignored files. Never forget the current
workspace by accident.

## Quick Reference

| Situation | Action |
|-----------|--------|
| `jj` unavailable or current directory is not a Jujutsu workspace | Explain the loss of isolation and work in place |
| Already isolated by this procedure | Use the current workspace |
| Harness identifies an isolated workspace | Trust it and use the root reported by `jj workspace root` |
| Workspace creation approved | Create `$ROOT/.tmp/$WORKSPACE_NAME` with `jj workspace add` |
| Workspace name already registered | Inspect it with `jj workspace root --name`; reuse intentionally or choose another name |
| Workspace creation fails | Ask before working in place; do not create another fallback |
| Baseline verification fails | Report failures and ask whether to proceed |
| Workspace is no longer needed | From another workspace, run `jj workspace forget`, then remove files separately if safe |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I am obviously isolated, so no check is needed." | Run `jj workspace root` and `jj workspace list`; filesystem appearance is not workspace registration. |
| "A copied directory is equivalent." | It does not provide a Jujutsu working-copy commit or registered workspace. Work in place when Jujutsu isolation is unavailable. |
| "A system temporary directory is safer." | Manual workspaces belong under the repository root's `.tmp`; do not use `/tmp`, `TMPDIR`, `mktemp`, or `tempfile`. |
| "I can reuse that workspace name after deleting its directory." | The workspace remains registered until `jj workspace forget`; inspect registrations before creating anything. |
| "Forgetting the workspace cleans up its files." | `jj workspace forget` does not touch the directory. Remove it separately only after checking for needed work. |
| "The workspace is fresh, so baseline verification can wait." | A dirty baseline makes every later failure ambiguous. Proceeding past failures is the user's decision. |
