---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - creates an isolated Jujutsu workspace and verifies a clean baseline
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace with its own working-copy change.

**Core principle:** Detect existing isolation first, then create a sibling workspace without importing unrelated working-copy changes.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

Before creating anything, inspect the current workspace and repository state:

```bash
jj workspace root
jj workspace list
jj status
```

Use `jj file list` to locate repository-tracked instruction files, read each applicable file with `jj file show -r @ <instruction-path>`, and use `jj log` to inspect local history. Follow runtime instructions before this skill. If the harness or instructions already placed the task in a dedicated workspace, report its root and skip to Step 2. Do not create a nested workspace.

If isolation was not already requested or approved, ask whether to create a workspace. Honor an existing preference without asking. If declined, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

Use an explicit destination preference when one exists. Otherwise use `$(jj workspace root)/.tmp/rocketclaw`; if the root cannot be resolved, use the current workspace's local `.tmp/rocketclaw` directory.

Before creating the destination, verify that the applicable `.gitignore` rules ignore `.tmp/rocketclaw/`. If they do not, add that rule and review the change with `jj status` and `jj diff` before proceeding. This prevents the containing workspace from recording the nested workspace.

Choose a unique workspace name, then create and enter it:

```bash
if root=$(jj workspace root 2>/dev/null) && [ -n "$root" ]; then
    :
else
    root=$(pwd -P)
fi
location="$root/.tmp/rocketclaw"
case "$WORKSPACE_NAME" in
    ""|.|..|*/*) printf 'invalid workspace name: %s\n' "$WORKSPACE_NAME" >&2; exit 2 ;;
esac
path="$location/$WORKSPACE_NAME"
[ ! -L "$root/.tmp" ] || { printf 'refusing symlinked temporary root\n' >&2; exit 2; }
(umask 077 && mkdir -p "$root/.tmp")
[ ! -L "$location" ] || { printf 'refusing symlinked temporary directory\n' >&2; exit 2; }
(umask 077 && mkdir -p "$location")
jj workspace add --name "$WORKSPACE_NAME" "$path"
cd "$path"
```

By default, `jj workspace add` creates a new working-copy change with the same parent as the current working-copy change. This keeps the current working-copy change's contents in the original workspace. Only pass `--revision` when the task explicitly requires another base revision.

Do not create a bookmark merely to enter the workspace. Jujutsu has no active bookmark, and a bookmark created at the initial empty change would not automatically advance with later changes.

If workspace creation is blocked by permissions, report the failure and work in the current directory. Then run setup and baseline verification in place.

## Step 2: Project Setup

Auto-detect and run the project's established setup command. Common cases include:

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi
if [ -f go.mod ]; then go mod download; fi
```

For Go projects, honor the module's declared Go version and toolchain; do not upgrade either as part of setup.

## Step 3: Verify Clean Baseline

Run the project-appropriate test command to ensure the workspace starts clean.

If tests fail, report the failures and ask whether to proceed or investigate. If they pass, report the workspace root and successful baseline, then begin implementation.

## Changes and Bookmarks

Use `jj status`, `jj diff`, and `jj log` to inspect work. Before composing, editing, validating, or recommending a change description or commit message, apply this instruction:

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and conventions observed with `jj log` take precedence. Apply Go guidance only where it is compatible with those present standards. Set the resulting description with `jj describe`. Keep work as Jujutsu changes; Jujutsu records working-copy files automatically.

Create a bookmark at the finished change only when a stable name is needed for sharing or pushing. Use `jj bookmark create` for a new name and `jj bookmark move` for an existing name. Verify its target with `jj bookmark list`.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in a dedicated workspace | Skip creation |
| Isolation declined | Work in place |
| No destination preference | Use `$(jj workspace root)/.tmp/rocketclaw` |
| Workspace root unavailable | Use local `.tmp/rocketclaw` |
| Destination not ignored | Add `.tmp/rocketclaw/` to `.gitignore` and review |
| Different base explicitly required | Pass `--revision` to `jj workspace add` |
| Stable name needed at finish | Create or move a bookmark to the finished change |
| Permission error on creation | Report and work in place |
| Baseline tests fail | Report failures and ask |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I am obviously isolated." | Check `jj workspace root`, `jj workspace list`, and the runtime instructions first. |
| "The current change should come along automatically." | The sibling change is deliberate isolation; select another base only when required. |
| "A workspace needs a bookmark immediately." | Workspaces own working-copy changes; bookmarks are named revision pointers, not workspace state. |
| "The destination is surely ignored." | Verify `.tmp/rocketclaw/` before nesting a workspace there. |
| "Baseline tests can wait." | A dirty baseline makes later failures ambiguous; proceeding after failures requires the user's decision. |
