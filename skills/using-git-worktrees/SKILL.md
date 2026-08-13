---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated workspace exists via native harness tools or a Jujutsu workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer the harness's native isolation mechanism. Fall back to a Jujutsu workspace only when no native mechanism is available; each Jujutsu workspace has its own working-copy commit while sharing the same repository.

**Core principle:** Detect existing isolation first, then use native harness isolation, then fall back to a Jujutsu workspace. Never fight the harness.

**Announce at start:** State that you are using the `using-git-worktrees` skill to set up an isolated workspace.

## Step 0: Detect Existing Isolation

**Before creating anything, check whether the harness already identifies the current directory as an isolated worktree or workspace.** Verify that it is also a registered Jujutsu workspace with `jj workspace root`. Its path may be outside `.tmp`, but downstream workflows require Jujutsu registration. If the check succeeds, report the harness-provided workspace root and continue at Step 2. If it fails, do not treat that isolation as usable for this JJ-only workflow.

Harnesses expose isolation in different ways. Preserve their native lifecycle:

| Harness capability | Discovery and compatibility behavior |
|--------------------|--------------------------------------|
| `EnterWorktree` | Use the current worktree if already entered; otherwise this is an agent-callable creation tool in Step 1a. |
| `WorktreeCreate` or another workspace-creation tool | Use the current harness workspace if already active; otherwise invoke the tool in Step 1a. |
| `/worktree` | If the user already activated it, use the resulting workspace. If it is user-facing rather than agent-callable, do not pretend to invoke it or start a nested harness. |
| `--worktree`, `--workspace`, or another harness workspace flag | If the session was launched with it, use the resulting workspace. Launch-time flags are discovery mechanisms, not commands to relaunch the current session. |
| Platform-managed worktree or detached workspace | Trust the platform-managed isolation and do not create or clean up a nested workspace. |

If the harness does not identify existing isolation, check whether the current directory is already a registered Jujutsu workspace:

```bash
command -v jj >/dev/null 2>&1 && CURRENT_ROOT=$(jj workspace root 2>/dev/null)
```

If both checks succeed, inspect the registered workspaces and current workspace root:

```bash
jj workspace list
jj workspace root
```

Treat the current workspace as created by this procedure only when its root is
the expected repository-root `.tmp/<workspace-name>` path and its registered
name and root agree with `jj workspace list`. Do not infer ownership from an
arbitrary `/.tmp/` substring. If it matches, report its full root and continue
at Step 2.

Otherwise, honor any existing instruction that grants or declines workspace creation. If no preference exists, ask whether to create an isolated workspace to protect the current working copy. If consent is declined, work in place and continue at Step 2.

## Step 1: Create Isolated Workspace

Use these mechanisms in order.

### 1a. Native Harness Isolation (preferred)

The user has asked for an isolated workspace, either directly or through Step 0 consent. Check the available tools for `EnterWorktree`, `WorktreeCreate`, another worktree or workspace-creation tool, an agent-callable `/worktree` command, or an equivalent harness mechanism. The user's consent to create an isolated workspace is authorization to use the native tool.

If an agent-callable native tool is documented to create a registered Jujutsu workspace, use it, verify the result with `jj workspace root`, and continue at Step 2. Native tools own directory placement and cleanup. Do not create a nested Jujutsu workspace inside it.

If the native tool creates only another version-control system's worktree, preserve its mapping but do not invoke it for this workflow; continue to Step 1b and create a Jujutsu workspace instead.

User-facing `/worktree` commands and launch-time flags such as `--worktree` or `--workspace` cannot be invoked mid-session unless the harness explicitly exposes them to the agent. Do not relaunch the harness or claim that the flag was used. When no agent-callable native tool exists and the current session is not already isolated, continue to Step 1b.

### 1b. Jujutsu Workspace Fallback

Use this only when the harness neither supplied an isolated workspace nor exposes an agent-callable native creation tool. Verify that `jj` is available and the current directory belongs to a Jujutsu workspace:

```bash
command -v jj >/dev/null 2>&1 && ROOT=$(jj workspace root 2>/dev/null)
if command -v cygpath >/dev/null 2>&1; then ROOT=$(cygpath -u "$ROOT"); fi
```

If this fails, explain that neither native isolation nor Jujutsu workspace creation is available and work in the current directory. Do not create a substitute with another version-control system or in OS-global temporary storage.

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
WORKSPACE_PATH="$ROOT/.tmp/$WORKSPACE_NAME"
mkdir -p "$ROOT/.tmp"
jj workspace add -r @ --name "$WORKSPACE_NAME" "$WORKSPACE_PATH"
cd "$WORKSPACE_PATH"
```

`-r @` creates the new working-copy commit from the current working-copy commit, so spec or plan changes already present in the current workspace are included in the implementation workspace.

If creation fails, report the reason and work in the current directory only after the user agrees to proceed without isolation. At this point both native creation and Jujutsu workspace creation are unavailable. Do not fall back to another version-control system or an external temporary directory.

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

If the harness created the isolated workspace, leave cleanup to the harness's native lifecycle. Do not run Jujutsu cleanup against it.

For a manually created Jujutsu workspace, record its change ID and
confirm that the working-copy change is empty, landed, or retained by the
intended bookmark or a descendant. Then leave that workspace and forget it from
another registered Jujutsu workspace:

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
| Harness identifies an isolated workspace | Trust it and use the harness-reported root |
| Agent-callable native tool such as `EnterWorktree` or `WorktreeCreate` exists | Use it before considering Jujutsu |
| User-facing `/worktree` or launch-time workspace flag already activated | Use the resulting workspace; do not relaunch the harness |
| No native isolation and `jj` unavailable or current directory is not a Jujutsu workspace | Explain the loss of isolation and work in place |
| Already isolated by this procedure | Use the current workspace |
| Jujutsu fallback approved | Create `$ROOT/.tmp/$WORKSPACE_NAME` with `jj workspace add -r @` |
| Workspace name already registered | Inspect it with `jj workspace root --name`; reuse intentionally or choose another name |
| Native and Jujutsu creation are unavailable | Ask before working in place; do not create another fallback |
| Baseline verification fails | Report failures and ask whether to proceed |
| Native workspace is no longer needed | Use the harness lifecycle; do not clean it up with Jujutsu |
| Manual Jujutsu workspace is no longer needed | From another Jujutsu workspace, run `jj workspace forget`, then remove files separately if safe |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I am obviously isolated, so no check is needed." | Check harness isolation first, then `jj workspace root` and `jj workspace list`; filesystem appearance alone is not authoritative. |
| "A Jujutsu workspace is more consistent than the native tool." | Native isolation owns placement and cleanup and is the first choice. Bypassing `EnterWorktree`, `WorktreeCreate`, or equivalent creates state the harness cannot manage. |
| "A copied directory is equivalent." | It does not provide a Jujutsu working-copy commit or registered workspace. Work in place when Jujutsu isolation is unavailable. |
| "A system temporary directory is safer." | Manual workspaces belong under the repository root's `.tmp`; do not use OS-global temporary storage. |
| "The default revision is close enough." | Use `-r @` so current spec or plan changes are present in the implementation workspace. |
| "I can reuse that workspace name after deleting its directory." | The workspace remains registered until `jj workspace forget`; inspect registrations before creating anything. |
| "Forgetting the workspace cleans up its files." | `jj workspace forget` does not touch the directory. Remove it separately only after checking for needed work. |
| "The workspace is fresh, so baseline verification can wait." | A dirty baseline makes every later failure ambiguous. Proceeding past failures is the user's decision. |
