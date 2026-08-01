---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. A workspace is a working copy backed by the same repository, with its own working-copy commit and sparse patterns.

**Core principle:** Detect existing isolation first, then create a namespaced workspace with `jj workspace add`. Do not substitute branches for Jujutsu workspaces.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated Jujutsu workspace."

## Step 0: Inspect Current Workspace

**Before creating anything, confirm that this is a Jujutsu repository and inspect its workspaces.**

```bash
CURRENT_ROOT=$(jj workspace root)
jj workspace list
```

`jj workspace root` prints the current workspace root. `jj workspace list` shows every workspace registered with the repository. Do not infer isolation from the presence of `.jj`: every Jujutsu workspace has a `.jj` directory.

If the current workspace was created for this task by the harness, the user, or an earlier invocation of this skill, reuse it and skip to Step 2. Confirm its root with `jj workspace root` and report:

> Already in isolated Jujutsu workspace at `<path>`.

If a workspace with the intended task name already appears in `jj workspace list`, do not create a duplicate. Resolve its path with:

```bash
jj workspace root --name "$WORKSPACE_NAME"
```

Ask whether to reuse it. A registered workspace may contain another session's work.

Otherwise, check whether the user has already declared a preference for isolated workspaces. If not, ask for consent:

> Would you like me to set up an isolated Jujutsu workspace? It protects the current working copy from changes made for this task.

Honor an existing declared preference without asking. If the user declines, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

### Choose The Base

Run `jj status` and identify the revision from which the new work should start. `jj workspace add -r <revision>` creates a new working-copy commit with that revision as its parent. Use `@` only when the current working-copy commit, including its snapshotted content, is the intended base. If it contains unrelated work, ask the user which revision or bookmark to use.

Do not treat a bookmark as an active branch. Jujutsu has no active or checked-out bookmark; bookmarks are optional named pointers to revisions.

### Namespace And Attribution

Choose a short task identifier and prefix the workspace name with the namespace supplied by the user, harness, or session instructions. Workspace names are repository-wide, so the namespace must distinguish this actor or session from concurrent work. Use only a filesystem-safe name, and verify with `jj workspace list` that it is not already registered. Do not invent personal attribution or add generated-by/co-author attribution unless the user or repository requires it.

Use the same namespaced identifier for the temporary workspace directory. Do not prescribe a fixed namespace or bookmark syntax; follow the environment's naming rules.

### Choose The Destination

Use a unique destination under the current workspace's `.tmp` directory. Reserve a unique parent directory with a `mkdir` loop, then leave the destination itself absent for `jj workspace add`:

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

Because Jujutsu automatically tracks new files, **MUST verify the workspace root's ignore rules exclude `.tmp/` before adding the workspace there.** Jujutsu honors `.gitignore`; if `.tmp/` is not ignored, add the project-root rule first and let Jujutsu snapshot that change. When describing that ignore-rule change:

Inspect the actual change with `jj status` and `jj diff`, locate and read
applicable repository instructions with `jj file list` and `jj file show -r @
<instruction-path>`, and inspect recent descriptions with `jj log`. Local
conventions take precedence over compatible Go guidance. Derive syntax,
vocabulary, structure, and detail from those sources and the actual diff; do
not impose a fixed format.

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use `jj describe` with the composed description. Do not use a canned message or fixed message syntax.

If `jj workspace root` failed, there is no Jujutsu repository in which `jj workspace add` can operate. The loop still provides a unique local `.tmp` directory for temporary work, but report the missing repository and ask before working in place; do not pretend that directory is a Jujutsu workspace.

### Add The Workspace

```bash
jj workspace add --name "$WORKSPACE_NAME" --revision "$BASE_REVISION" "$DESTINATION"
cd "$DESTINATION"
jj workspace root
jj workspace list
```

The destination basename is only the default workspace name; pass `--name` explicitly so the repository-wide name keeps its namespace.

If creation fails because the name is registered, inspect `jj workspace list` and `jj workspace root --name "$WORKSPACE_NAME"`; never silently choose another identity. If creation fails because the sandbox denies the destination, report the denial and ask for an allowed location or permission to work in place.

### Describe The Change

The new workspace has its own working-copy change. Give it a description before implementation, without imposing a message format:

Locate and read applicable repository instructions with `jj file list` and
`jj file show -r @ <instruction-path>`, inspect recent descriptions with `jj
log`, and inspect the working-copy change with `jj status` and `jj diff`. Local
conventions take precedence over compatible Go guidance. Derive syntax,
vocabulary, structure, and detail from those sources and the intended work; do
not impose a fixed format.

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use `jj describe` so the composed description is applied to the current change. Do not insert a canned description, attribution footer, or fixed prefix.

### Bookmarks

Do not create a bookmark merely to emulate a branch. Create one only when the user's publishing or integration workflow needs a stable name. Namespace it according to the same repository rules, check it with `jj bookmark list`, and point it at the intended revision with `jj bookmark create --revision <revision> <name>`. Jujutsu does not automatically advance bookmarks as new changes are created; before pushing, deliberately move an existing bookmark with `jj bookmark move --to <revision> <name>` and verify its target with `jj bookmark list`.

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

## Cleanup

When the isolated workspace is no longer needed, first confirm its registered name and root:

```bash
jj workspace list
jj workspace root --name "$WORKSPACE_NAME"
```

Then, from another workspace in the same repository, stop tracking it:

```bash
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` does not delete files. Delete the directory separately only after verifying that the resolved root is the intended temporary workspace, all needed changes are retained, and no process is using it. Never recursively delete an unverified path. If the workspace was not created under the temporary parent recorded in Step 1, leave deletion to the user or owning harness.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already isolated for this task | Reuse current workspace |
| Intended name is registered | Resolve with `jj workspace root --name`; ask before reuse |
| No declared isolation preference | Ask for consent |
| Jujutsu repository available | Reserve a unique parent under `$(jj workspace root)/.tmp` |
| No Jujutsu repository | Use a unique local `.tmp`; report and ask before working in place |
| Current `@` is the intended base | Add with `--revision @` |
| Current `@` contains unrelated work | Ask for another revision or bookmark |
| Stable publishing name required | Create or deliberately move a namespaced bookmark |
| Permission error on create | Ask for an allowed path or permission to work in place |
| Tests fail during baseline | Report failures and ask |
| Workspace finished | `jj workspace forget`, then separately handle files |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "There is a `.jj` directory, so this must already be isolated" | Every Jujutsu workspace has one. Check `jj workspace root`, `jj workspace list`, and the task's ownership context. |
| "The default `workspace add` base is close enough" | With no revisions, Jujutsu uses the current working-copy commit's parents. Select the intended base explicitly. |
| "The workspace name can just be the feature name" | Names are repository-wide. Namespace the name so concurrent actors do not collide. |
| "A bookmark is the Jujutsu version of my checked-out branch" | A bookmark is a named pointer, and there is no active bookmark. Create one only when the workflow needs it. |
| "`.tmp` does not need an ignore check" | Jujutsu automatically tracks new files. Verify the project-root ignore rules exclude `.tmp/` before adding a workspace below it. |
| "Forgetting the workspace cleans up its directory" | `jj workspace forget` only removes repository tracking. On-disk deletion is separate and requires path verification. |
| "The workspace is fresh, so baseline tests can wait" | A dirty baseline makes later failures ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
