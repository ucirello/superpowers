---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists via native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Prefer the harness's native isolation tools. Fall back to `jj workspace add` only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to JJ. Never fight the harness.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated Jujutsu workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, confirm that this is a Jujutsu repository and inspect its registered workspaces.**

```bash
if CURRENT_ROOT=$(jj workspace root 2>/dev/null); then
    jj -R "$CURRENT_ROOT" workspace list
    jj -R "$CURRENT_ROOT" status
else
    CURRENT_ROOT=""
fi
```

`jj workspace root` is authoritative for the current workspace. `jj workspace list` shows every workspace registered with the repository. Do not infer task isolation merely from the presence of `.jj`: every Jujutsu workspace has one.

If `CURRENT_ROOT` is empty, report that the current directory is not in a Jujutsu repository and ask before working in place. Any temporary files needed while resolving that situation belong in the current directory's `.tmp`; do not use an OS-global temporary directory.

If the user, harness, or current session says the current workspace was created for this task, reuse it and skip to Step 2. Report:

> Already in isolated Jujutsu workspace at `<path>`.

If a workspace with the intended task name is already registered, do not create a duplicate. Resolve its path with:

```bash
jj workspace root --name "$WORKSPACE_NAME"
```

Ask whether to reuse it. A registered workspace may contain another session's work.

If there is no explicit isolation signal, check whether the user already requested or approved an isolated workspace. If not, ask:

> "Would you like me to set up an isolated Jujutsu workspace? It keeps this task's working-copy change separate from your current one."

Honor an existing declared preference without asking. If the user declines, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

### 1a. Native Workspace Tools (preferred)

The user has approved an isolated workspace. If the harness provides a native isolation tool such as `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag, use it and skip to Step 2.

Native tools handle directory placement, workspace creation, and cleanup while keeping harness state synchronized. Creating a workspace manually when a native tool is available can create state the harness cannot see or manage.

Only proceed to Step 1b when no native isolation tool is available.

### 1b. Select The Base

Run `jj status` and identify the revision from which the new work should start. `jj workspace add --revision <revision>` creates a new working-copy change with that revision as its parent.

Use the revision or bookmark named by the user. Otherwise use `@` only when the current working-copy change, including its snapshotted content and parentage, is the intended base. If it contains unrelated work or the base is ambiguous, ask which revision or bookmark to use.

Bookmarks are shared named pointers, not active branches. A workspace does not require a bookmark.

### 1c. Choose The Name And Destination

Choose a short task identifier and prefix the workspace name with the namespace supplied by the user, harness, or session instructions. Workspace names are repository-wide, so the namespace must distinguish this actor or session from concurrent work. Use only a filesystem-safe name, and verify with `jj workspace list` that neither the name nor destination is already registered. Do not invent personal attribution or add generated-by or co-author attribution unless the user or repository requires it.

Use the same namespaced identifier for the temporary workspace directory. Do not prescribe a fixed namespace or bookmark syntax; follow the environment's naming rules.

Reserve a unique parent under the current Jujutsu workspace's `.tmp` directory, then leave the destination itself absent for `jj workspace add`. If no Jujutsu workspace is available, use a local `.tmp` directory only as the temporary-path fallback:

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

Keep the reserved parent path so cleanup can identify the temporary directory. Never create the destination itself before `jj workspace add`.

If `jj workspace root` failed, there is no Jujutsu repository in which `jj workspace add` can operate. The loop still provides a unique local `.tmp` directory for temporary work, but report the missing repository and ask before working in place; do not pretend that directory is a Jujutsu workspace.

### 1d. Verify File-Tracking Safety

Jujutsu automatically tracks new files unless they match an ignore rule. Because the default destination is inside the current workspace, **MUST verify the workspace root's ignore rules exclude `.tmp/` before adding the workspace there.** Jujutsu honors `.gitignore`; there is no separate JJ ignore file.

Use a unique temporary probe and remove it immediately:

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

`jj file list` snapshots the containing workspace. If it prints the probe path, `.tmp/` is not ignored. Add `.tmp/` to the repository's root `.gitignore`, verify the probe again, and record that ignore change separately before proceeding.

When composing the description for that ignore-rule change, inspect the actual change with `jj status` and `jj diff`, locate and read applicable repository instructions with `jj file list` and `jj file show -r @ <instruction-path>`, and inspect recent descriptions with `jj log`. Runtime repository instructions and repository-prescribed `git log` syntax take precedence over compatible Go guidance. Derive syntax, vocabulary, structure, and detail from those sources and the actual diff; do not impose a fixed format.

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use `jj describe` with the composed description, then `jj new` to start the task's working-copy change after the standalone ignore-rule change. Do not use a canned description or fixed message syntax.

### 1e. Add The Workspace

Create the workspace from the explicitly selected base and address the source repository dynamically:

```bash
jj -R "$JJ_ROOT" workspace add --name "$WORKSPACE_NAME" --revision "$BASE_REVISION" "$DESTINATION"
cd "$DESTINATION"
jj workspace root
jj workspace list
jj status
```

The destination basename is only the default workspace name; pass `--name` explicitly so the repository-wide name keeps its namespace.

If creation fails because the name is registered, inspect `jj workspace list` and `jj workspace root --name "$WORKSPACE_NAME"`; never silently choose another identity. If creation fails because the sandbox denies the destination, report the denial and ask for an allowed location or permission to work in place. Do not fall back to another VCS CLI.

### 1f. Describe The Change

The new workspace has its own working-copy change. Give it a description before implementation without imposing a message format.

Locate and read applicable repository instructions with `jj file list` and `jj file show -r @ <instruction-path>`, inspect recent descriptions with `jj log`, and inspect the working-copy change with `jj status` and `jj diff`. Runtime repository instructions and repository-prescribed `git log` syntax take precedence over compatible Go guidance. Derive syntax, vocabulary, structure, and detail from those sources and the intended work; do not impose a fixed format.

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use `jj describe` so the composed description is applied to the current change. Do not insert a canned description, attribution footer, or fixed prefix.

### Bookmarks

Do not create a bookmark merely to emulate a branch. Create one only when the user's publishing or integration workflow needs a stable name. Namespace it according to the same repository rules, inspect existing names with `jj bookmark list`, and point a new bookmark at the intended revision with `jj bookmark create --revision <revision> <name>`.

Jujutsu does not automatically advance bookmarks as descendant changes are created. Before publishing, deliberately move an existing bookmark with `jj bookmark move --to <revision> <name>` and verify its target with `jj bookmark list`. Never move an existing bookmark without confirming that its current target and the requested target are correct.

## Step 2: Project Setup

Auto-detect and run appropriate setup in the selected workspace:

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

Keep temporary setup artifacts under `$(jj workspace root)/.tmp` when the tool permits choosing their location. If no Jujutsu workspace exists, use the current directory's `.tmp` instead of an OS-global temporary directory.

## Step 3: Verify Clean Baseline

Run tests to ensure the workspace starts clean:

```bash
# Use the project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```text
Jujutsu workspace ready at <full-path>
Workspace name: <namespaced-name>
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

When the isolated workspace is no longer needed, first confirm its registered name and root:

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

`jj workspace forget` does not delete files. Delete the directory separately only after verifying that the resolved root is the intended temporary workspace, all needed changes are retained, and no process is using it. Never recursively delete an unverified path. If the workspace was not created under the temporary parent recorded in Step 1, leave deletion to the user or owning harness.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already isolated for this task | Reuse current workspace |
| Intended name is registered | Resolve with `jj workspace root --name`; ask before reuse |
| Native workspace tool available | Use it |
| No native tool | Use `jj workspace add` |
| No declared isolation preference | Ask for consent |
| Jujutsu repository available | Reserve a unique parent under `$(jj workspace root)/.tmp` |
| No Jujutsu repository | Use a unique local `.tmp`; report and ask before working in place |
| Current `@` is the intended base | Add with `--revision @` |
| Current `@` contains unrelated work | Ask for another revision or bookmark |
| `.tmp/` probe is tracked | Ignore `.tmp/`, describe that change separately, and verify again |
| Stable publishing name required | Create or deliberately move a namespaced bookmark |
| Workspace is stale | Run `jj workspace update-stale` inside it |
| Permission error on create | Ask for an allowed path or permission to work in place |
| Tests fail during baseline | Report failures and ask |
| Workspace finished | `jj workspace forget`, then separately handle files |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "There is a `.jj` directory, so this must already be isolated" | Every Jujutsu workspace has one. Check `jj workspace root`, `jj workspace list`, and the task's ownership context. |
| "The default `workspace add` base is close enough" | With no revisions, Jujutsu uses the current working-copy change's parents. Select the intended base explicitly. |
| "The workspace name can just be the feature name" | Names are repository-wide. Namespace the name so concurrent actors do not collide. |
| "A bookmark is the Jujutsu version of my checked-out branch" | A bookmark is a shared named pointer, and there is no active bookmark. Create one only when the workflow needs it. |
| "`.tmp` does not need an ignore check" | Jujutsu automatically tracks new files. Verify the project-root ignore rules exclude `.tmp/` before adding a workspace below it. |
| "Forgetting the workspace cleans up its directory" | `jj workspace forget` only removes repository tracking. On-disk deletion is separate and requires path verification. |
| "The workspace is fresh, so baseline tests can wait" | A dirty baseline makes later failures ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
