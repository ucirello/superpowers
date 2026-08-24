---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists via native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Prefer harness-native tools that explicitly support Jujutsu workspaces. Fall back to `jj workspace add` otherwise.

**Core principle:** Detect existing isolation first. Then use native tools that create Jujutsu workspaces. Then fall back to `jj workspace add`. Never fight the harness.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated Jujutsu workspace."

## Step 0: Detect Existing Isolation

Before creating anything, confirm that this is a Jujutsu repository and inspect its registered workspaces:

```bash
if CURRENT_ROOT=$(jj workspace root 2>/dev/null); then
    jj -R "$CURRENT_ROOT" workspace list
    jj -R "$CURRENT_ROOT" status
else
    CURRENT_ROOT=""
fi
```

`jj workspace root` is authoritative for the current workspace. `jj workspace list` shows every workspace registered with the repository, and `jj workspace root --name <name>` resolves a registered workspace's path. Do not infer task isolation merely from the presence of `.jj`: every Jujutsu workspace has one.

If `CURRENT_ROOT` is empty, report that the current directory is not in a Jujutsu repository and ask before working in place. Put temporary files needed while resolving that situation in the current directory's `.tmp`; never use an OS-global temporary directory.

If the user, harness, or current session says the current workspace was created for this task, reuse it and skip to Step 2. Report:

> Already in isolated Jujutsu workspace at `<path>`.

If a workspace with the intended task name is registered, do not create a duplicate. Resolve its path with:

```bash
jj workspace root --name "$WORKSPACE_NAME"
```

Ask whether to reuse it. A registered workspace may contain another session's work.

If there is no explicit isolation signal, check whether the user already requested or approved an isolated workspace. If not, ask:

> "Would you like me to set up an isolated Jujutsu workspace? It keeps this task's working-copy change separate from your current one."

Honor an existing declared preference without asking. If the user declines, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

### 1a. Native Workspace Tools (Preferred)

If the harness provides a native isolation tool such as `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag, use it and skip to Step 2 only when it explicitly creates and registers a Jujutsu workspace. A generic worktree tool does not qualify merely because it creates an isolated directory.

Qualifying native tools handle directory placement, Jujutsu workspace creation, and cleanup while keeping harness state synchronized. Creating a workspace manually when one is available can create state the harness cannot see or manage.

Proceed to Step 1b when no qualifying native isolation tool is available.

### 1b. Select the Base

Run `jj status` and identify the revision from which the new work should start. `jj workspace add --revision <revision>` creates a new working-copy change with that revision as its parent.

Use the revision or bookmark named by the user. Otherwise use `@` only when the current working-copy change, including its snapshotted content and parentage, is the intended base. If it contains unrelated work or the base is ambiguous, ask which revision or bookmark to use.

With no `--revision`, `jj workspace add` uses the current working-copy change's parents, not the current change itself. Always pass the selected base explicitly.

Record the selection as `BASE_REVISION=<selected-revision>` before creating the workspace.

Bookmarks are shared named pointers, not active branches. A workspace does not require a bookmark.

### 1c. Choose the Name and Destination

Choose a short, filesystem-safe task identifier. Follow any name rules supplied by the user, harness, or repository; do not invent additional naming conventions. Workspace names are repository-wide, so use `jj workspace list` to verify that the name is free.

Use the same identifier for the temporary workspace directory. Reserve a unique parent under `$(jj workspace root)/.tmp`, then leave the destination itself absent for `jj workspace add`. If `jj workspace root` fails, the only fallback is a local `.tmp` under the current directory:

```bash
if JJ_ROOT=$(jj workspace root 2>/dev/null); then
    TEMP_BASE="$JJ_ROOT/.tmp"
else
    TEMP_BASE="$(pwd -P)/.tmp"
fi

mkdir -p "$TEMP_BASE"
counter=0
while :; do
    TEMP_PARENT="$TEMP_BASE/jj-workspace-$WORKSPACE_NAME-$$-$counter"
    if mkdir "$TEMP_PARENT" 2>/dev/null; then
        break
    fi
    counter=$((counter + 1))
done
DESTINATION="$TEMP_PARENT/workspace"
```

Keep the reserved parent path for cleanup. Never create the destination itself before `jj workspace add`.

If `jj workspace root` failed, there is no Jujutsu repository in which `jj workspace add` can operate. The loop only reserves a local temporary path; report the missing repository and ask before working in place. Do not represent that directory as a Jujutsu workspace.

### 1d. Verify File-Tracking Safety

Jujutsu automatically tracks new files unless they match an ignore rule. Before adding a workspace below the current root, **MUST verify that the root's ignore rules exclude `.tmp/`**. Jujutsu honors Git-format ignore files; it does not have a separate jj ignore file.

Use a unique probe and remove it immediately:

```bash
mkdir -p "$JJ_ROOT/.tmp"
PROBE="$JJ_ROOT/.tmp/.jj-ignore-check.$$.$RANDOM"
( set -C; : > "$PROBE" ) || { printf '%s\n' "could not create unique ignore probe" >&2; exit 1; }
trap 'rm -f -- "$PROBE"' EXIT
jj -R "$JJ_ROOT" file list ".tmp/${PROBE##*/}"
rm -f -- "$PROBE"
trap - EXIT
jj -R "$JJ_ROOT" status
```

`jj file list` snapshots the containing workspace. Start with
`WORKSPACE_BASE="$BASE_REVISION"`. If the probe path is printed, `.tmp/` is not
ignored. Do not mix the ignore update into unrelated work:

```bash
ORIGINAL_REV=$(jj log -r @ --no-graph -T 'commit_id')
jj new "$BASE_REVISION"
# Add .tmp/ to the applicable root ignore file.
jj status
jj diff
```

Before composing, editing, validating, or recommending the ignore change's description, locate and read applicable repository instructions with `jj file list` and `jj file show -r @ <instruction-path>`. Inspect recent messages with the repository-prescribed `git log` syntax, or plain `git log` if none is prescribed. This required history inspection is the only direct Git CLI exception in this workflow. Repository-local instructions and repository-prescribed `git log` syntax take precedence over compatible Go guidance. Derive the description's syntax, vocabulary, structure, and detail from those sources and the actual diff; do not impose a fixed format, template, prefix, or example.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Apply the composed description, record its full commit ID, and return the
source workspace to its original revision:

```bash
jj describe
WORKSPACE_BASE=$(jj log -r @ --no-graph -T 'commit_id')
jj edit "$ORIGINAL_REV"
```

The task workspace starts from the ignore change, while the preserved
pre-existing change remains separate; do not abandon, rewrite, or absorb it.

Repeat the probe after the ignore change and proceed only when `jj file list` does not print the probe path.

### 1e. Add the Workspace

Create the workspace from the explicitly selected base and address the source repository dynamically:

```bash
jj -R "$JJ_ROOT" workspace add --name "$WORKSPACE_NAME" --revision "$WORKSPACE_BASE" "$DESTINATION"
cd "$DESTINATION"
jj workspace root
jj workspace list
jj status
```

Pass `--name` explicitly because the destination basename would otherwise become the workspace name.

If creation fails because the name is registered, inspect `jj workspace list` and `jj workspace root --name "$WORKSPACE_NAME"`; never silently choose another identity. If the destination exists, inspect it rather than deleting or replacing it. If the sandbox denies the destination, report the denial and ask for permission to use the repository-local `.tmp` path or to work in place. Do not fall back to another VCS CLI or an OS-global temporary directory.

### Bookmarks

Do not create a bookmark merely to emulate a branch. Create one only when the user's publishing or integration workflow needs a stable name. Follow the repository's naming rules, inspect existing names with `jj bookmark list`, and point a new bookmark at the intended revision with `jj bookmark create --revision <revision> <name>`.

Jujutsu does not automatically advance bookmarks as descendant changes are created. Before publishing, deliberately move an existing bookmark with `jj bookmark move --to <revision> <name>` and verify its target with `jj bookmark list`. Moving a bookmark backward or sideways requires `--allow-backwards`. Never move an existing bookmark without confirming that its current target and the requested target are correct.

## Step 2: Project Setup

Auto-detect and run the setup appropriate to the selected workspace, unless repository instructions specify another command:

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

Keep temporary setup artifacts under `$(jj workspace root)/.tmp` when the tool permits choosing their location. If no Jujutsu workspace exists, use the current directory's local `.tmp` instead of an OS-global temporary directory.

## Step 3: Verify the Baseline

Run the repository-prescribed verification commands to establish a clean baseline.

**If verification fails:** Report the failures and ask whether to proceed or investigate.

**If verification passes:** Report ready.

### Report

```
Workspace ready at <full-path>
Registered as <workspace-name>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Stale Workspace Recovery

Operations in one workspace can rewrite another workspace's working-copy change. If Jujutsu reports that the current workspace is stale, update it from inside that workspace:

```bash
WORKSPACE_ROOT=$(jj workspace root)
jj -R "$WORKSPACE_ROOT" workspace update-stale
jj -R "$WORKSPACE_ROOT" status
```

Review the result. `jj workspace update-stale` can create a recovery change when the operation previously associated with the working copy has been lost; do not discard that recovery change without inspecting it.

## Cleanup

When the isolated workspace is no longer needed, first confirm its registered name and resolve its root:

```bash
jj workspace list
WORKSPACE_ROOT=$(jj workspace root --name "$WORKSPACE_NAME")
jj -R "$WORKSPACE_ROOT" status
```

From another workspace in the same repository, stop tracking it:

```bash
JJ_ROOT=$(jj workspace root)
jj -R "$JJ_ROOT" workspace forget "$WORKSPACE_NAME"
jj -R "$JJ_ROOT" workspace list
```

`jj workspace forget` does not delete files. Delete the directory separately only after verifying that the resolved root equals the recorded temporary workspace path, all needed changes are retained elsewhere in the repository, and no process is using it. Never recursively delete an unverified path. If the workspace was not created under the temporary parent recorded in Step 1, leave deletion to the user or owning harness.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already isolated for this task | Reuse the current workspace |
| Intended name is registered | Resolve with `jj workspace root --name`; ask before reuse |
| Native workspace tool available | Use it |
| No native tool | Use `jj workspace add` |
| No declared isolation preference | Ask for consent |
| Jujutsu repository available | Reserve a unique parent under `$(jj workspace root)/.tmp` |
| No Jujutsu repository | Use a unique local `.tmp`; report and ask before working in place |
| Current `@` is the intended base | Add with `--revision @` |
| Current `@` contains unrelated work | Ask for another revision or bookmark |
| `.tmp/` probe is tracked | Create a separate ignore change, verify it, and use it as the workspace base |
| Stable publishing name required | Create or deliberately move a bookmark |
| Workspace is stale | Run `jj workspace update-stale` inside it |
| Permission error on create | Ask for repository-local-path permission or work in place |
| Baseline verification fails | Report failures and ask |
| Workspace finished | `jj workspace forget`, then separately handle files |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "There is a `.jj` directory, so this must already be isolated" | Every Jujutsu workspace has one. Check `jj workspace root`, `jj workspace list`, and the task's ownership context. |
| "The default `workspace add` base is close enough" | With no revisions, Jujutsu uses the current working-copy change's parents. Select the intended base explicitly. |
| "The workspace name can just be reused" | Names are repository-wide. Check for a registered workspace before creation. |
| "A bookmark is the Jujutsu version of my checked-out branch" | A bookmark is a shared named pointer, and there is no active bookmark. Create one only when the workflow needs it. |
| "`.tmp` does not need an ignore check" | Jujutsu automatically tracks new files. Verify the root ignore rules exclude `.tmp/` before adding a workspace below it. |
| "Forgetting the workspace cleans up its directory" | `jj workspace forget` only removes repository tracking. On-disk deletion is separate and requires path verification. |
| "The workspace is fresh, so baseline verification can wait" | A dirty baseline makes later failures ambiguous. Verify now; proceeding past failures is the human's call. |
