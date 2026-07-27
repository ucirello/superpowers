---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace and working-copy change exist
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. A workspace is a separate working copy backed by the same Jujutsu repository, with its own working-copy change and sparse patterns. Repository operations, changes, and bookmarks remain shared.

**Core principle:** Detect existing isolation first. Then use `jj workspace` natively. Keep workspace identity, change identity, and bookmark identity separate.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated Jujutsu workspace."

## Step 0: Detect the Repository and Existing Isolation

**Before creating anything, inspect Jujutsu's workspace registry and the current workspace root.**

```bash
if root=$(jj workspace root 2>/dev/null); then
    printf 'Current workspace: %s\n' "$root"
    jj workspace list -T 'name ++ "\t" ++ root ++ "\n"'
else
    printf '%s\n' 'No Jujutsu repository found.'
fi
```

`jj workspace root` is authoritative for the current root. `jj workspace list` is authoritative for registered workspace names, roots, and working-copy changes. Do not infer workspace state from branches, backend internals, or directory names.

### Already Isolated

If the user, harness, or session instructions identify the current workspace as task-isolated, verify that its root appears in `jj workspace list`, report it, and skip to Step 2. Do not create a workspace inside an already isolated workspace merely because multiple workspaces are supported.

Report the Jujutsu state, not a branch name:

```text
Already in isolated Jujutsu workspace <name> at <path> on change <change-id>.
Bookmarks at this change: <names or none>.
```

Use `jj log -r @` and `jj bookmark list -r @` to obtain the working-copy change and any bookmarks. A workspace is not "on" a bookmark: Jujutsu has no active or checked-out bookmark.

### Not Yet Isolated

Has the user already indicated a workspace preference in the request, session instructions, or RocketClaw configuration under `.rocketclaw/`? If so, honor it without asking.

Otherwise ask for consent before creating a workspace:

> "Would you like me to set up an isolated Jujutsu workspace? It gives this task its own working copy and change while sharing repository history."

If the user declines, work in place and skip to Step 2.

### No Jujutsu Repository

Do not silently substitute another workspace implementation and do not silently convert a repository. Report that native workspaces require a Jujutsu repository and ask whether to initialize or clone one when that is appropriate. `jj git init`, `jj git clone`, and colocation are interoperability decisions, not workspace-creation fallbacks.

If initialization is declined or inappropriate, work in place. For temporary files, use local `.tmp`; never use global temporary storage.

## Step 1: Create an Isolated Workspace

### 1a. Choose the Workspace Name and Location

Follow this priority order. An explicit user preference always wins:

1. Use a workspace name or location declared in the request, session instructions, or `.rocketclaw/` configuration.
2. Otherwise derive a short, filesystem-safe task name that does not collide with `jj workspace list`.
3. Default the parent directory to exactly `$(jj workspace root)/.tmp/workspaces` and the destination to `$(jj workspace root)/.tmp/workspaces/$WORKSPACE_NAME`.

```bash
root=$(jj workspace root)
location="$root/.tmp/workspaces"
path="$location/$WORKSPACE_NAME"
```

Do not use `/tmp`, `$TMPDIR`, a home-directory workspace pool, or any other global temporary location. If there is no Jujutsu repository, the only fallback is `.tmp` relative to the current directory.

### 1b. Verify `.tmp` Is Ignored

Jujutsu automatically tracks new files unless they match ignore rules. Because the new workspace is nested under the current workspace root, `.tmp/` **must** be ignored before creating it.

Use the repository's existing ignore syntax and placement. Jujutsu supports `.gitignore`; there is no `.jjignore`.

Inspect the repository's ignore files and confirm with `jj status`. Do not invoke another VCS merely to perform this check.

If `.tmp/` is not ignored, add it using the repository's established ignore-file conventions, then record that focused change before creating the nested workspace. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository syntax and conventions win; do not impose a fixed message format.

**Why critical:** Almost every `jj` command snapshots the working copy. An unignored nested workspace can be captured as repository content.

### 1c. Choose the Starting Change

By default, use `jj workspace add` without `-r`. Jujutsu then gives the new workspace a fresh working-copy change with the same parents as the current working-copy change. This isolates the new task from any content already present in the current `@` while starting from the same base.

If the user or implementation plan specifies a base revision, pass it explicitly with `-r <REVSET>`. The new working-copy change will be created on that revision. Multiple `-r` values intentionally create a merge working-copy change; never introduce multiple parents accidentally.

Do not create a bookmark just to create the workspace. Workspace names identify working copies, change IDs identify evolving changes, and bookmarks identify shared publication points.

### 1d. Create and Enter the Workspace

```bash
mkdir -p "$location"
jj workspace add --name "$WORKSPACE_NAME" "$path"
cd "$path"
jj workspace root
jj workspace list
jj status
```

For an explicit base:

```bash
jj workspace add --name "$WORKSPACE_NAME" -r "$BASE_REVISION" "$path"
```

Verify all of the following before continuing:

- `jj workspace root` equals the intended destination.
- `jj workspace list` contains the intended workspace name and root.
- `jj status` shows the expected fresh working-copy change and parent revision.
- `jj bookmark list -r @` is understood as shared bookmark state, not an active branch.

**Sandbox fallback:** If creation fails because the sandbox denies filesystem access, report the denied destination and work in the current workspace only after the user agrees. Do not fall back to another workspace implementation.

**Name/path conflict:** If the workspace name is registered but its path is gone, confirm it is stale before using `jj workspace forget <name>`. If the path exists, do not overwrite or reuse it without inspecting ownership and asking when intent is ambiguous.

## Step 2: Project Setup

Auto-detect and run the project-appropriate setup in the new workspace:

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

Respect repository instructions and established tooling. Do not assume these examples override the project.

## Step 3: Verify a Clean Baseline

Run the project-appropriate tests to ensure the workspace starts clean:

```bash
# Select the command from repository instructions and project conventions.
npm test / cargo test / pytest / go test ./...
```

Run `jj status` afterward. Setup or test output under ignored paths is acceptable; unexpected tracked changes are not a clean baseline.

**If tests fail:** Report the command and failures, distinguish pre-existing baseline failures from workspace-setup problems, and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```text
Jujutsu workspace ready: <name> at <full-path>
Working-copy change: <change-id>, based on <parent-revision>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Working in the Workspace

### Changes and Descriptions

Jujutsu snapshots working-copy content into `@`; there is no staging-area prerequisite. Use `jj status`, `jj diff`, `jj log`, and `jj evolog` to understand the current change and its evolution.

Before composing any `jj describe` or `jj commit` description: Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository syntax and conventions win; do not prescribe a prefix, capitalization rule, line length, or body layout that the repository does not use.

Use `jj new` when the work should become multiple reviewable changes. Do not collapse change identity, commit identity, and workspace identity into one concept.

### Bookmarks and GitHub Interoperability

Bookmarks are shared named pointers and do not move merely because a workspace edits a descendant. Inspect them with `jj bookmark list`.

Create or move a task bookmark only when publication, repository convention, or the user requires one:

```bash
jj bookmark create "$BOOKMARK_NAME" -r @
# If it already exists and intentionally needs to advance:
jj bookmark move "$BOOKMARK_NAME" --to @
```

Never use `jj bookmark set` or `move` without first checking whether the bookmark exists, whether it is conflicted, and whether moving it is intended. A conflicted bookmark must be resolved deliberately.

For configured remotes, prefer `jj git fetch` and `jj git push --bookmark "$BOOKMARK_NAME"`. In colocated repositories, `gh` operations are acceptable where Jujutsu has no equivalent. Prefer Jujutsu for mutations; mixing mutating VCS commands can create confusing bookmark or divergent-change states.

## Finishing and Cleanup

Before forgetting a workspace:

1. Run `jj status` and inspect `jj log -r @` so no wanted change is mistaken for disposable workspace state.
2. Ensure wanted changes remain reachable by descendants, a bookmark, or another explicit revision reference according to the repository workflow.
3. Publish with `jj git push --bookmark "$BOOKMARK_NAME" --remote "$REMOTE"` or use `gh` only when the task requires remote GitHub interaction.
4. Leave the workspace in place if the user still needs it for review, testing, or follow-up work.

When cleanup is requested, forget the workspace from another registered workspace, then remove its files separately:

```bash
jj workspace forget "$WORKSPACE_NAME"
rm -rf "$WORKSPACE_PATH"
```

`jj workspace forget` only stops tracking the workspace's working-copy change; it does not delete files. File deletion before or after forgetting is valid, but never delete an unverified path. If a workspace becomes stale because its working-copy change was rewritten elsewhere, use `jj workspace update-stale` in that workspace rather than recreating it or discarding files.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Current session is already task-isolated | Verify with `jj workspace root/list`; skip creation |
| No Jujutsu repository | Ask about initialization; otherwise work in place with local `.tmp` |
| Need a second working copy | Use `jj workspace add`, never another workspace implementation |
| No base specified | Omit `-r`; create a sibling working-copy change |
| Base explicitly specified | Use `jj workspace add -r <REVSET>` |
| Need temporary storage | Use `$(jj workspace root)/.tmp` |
| No Jujutsu repository for temporary storage | Use local `.tmp` |
| `.tmp/` is not ignored | Add the repository-appropriate ignore rule and record it first |
| Need a branch-like publication name | Create or move a Jujutsu bookmark deliberately |
| Need to inspect workspaces | `jj workspace list` |
| Need a workspace path | `jj workspace root --name <name>` |
| Workspace path was deleted | Verify, then `jj workspace forget <name>` |
| Workspace is stale | `jj workspace update-stale` in that workspace |
| Permission error on create | Report it and ask before working in place |
| Baseline tests fail | Report failures and ask whether to proceed |
| No recognized project manifest | Skip dependency setup |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The directory looks separate, so it must be a workspace" | Run `jj workspace root` and `jj workspace list`. The repository registry, not appearance, establishes workspace identity. |
| "Another worktree implementation is close enough" | Native Jujutsu workspaces provide separate working-copy changes while sharing operations and history. |
| "I should create a bookmark with every workspace" | Workspaces and bookmarks are independent. Create a bookmark only for naming or publication. |
| "The new workspace should start on `@`" | The default sibling behavior excludes the current workspace's pending change. Use `-r @` only when inheriting that change is intentional. |
| "Jujutsu will ignore the nested workspace metadata" | New files are automatically tracked by default. Verify `.tmp/` is ignored before creating anything beneath it. |
| "Forgetting the workspace cleans up the directory" | `jj workspace forget` changes repository bookkeeping only; files are deleted separately. |
| "Deleting the directory first loses all work" | Changes live in the shared repository, but anonymous changes may become hard to find. Inspect and preserve wanted revisions before cleanup. |
| "A stale workspace should be replaced" | Use `jj workspace update-stale`; it exists to reconcile the working copy safely. |
| "The workspace is fresh, so baseline tests can wait" | A dirty baseline makes later failures ambiguous. Run the tests now; proceeding past failures is the user's call. |
