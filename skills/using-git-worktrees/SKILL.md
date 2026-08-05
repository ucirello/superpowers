---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. A workspace is an additional working copy attached to the same repository, with its own working-copy commit and sparse patterns.

**Core principle:** Detect existing isolation first. Then create a `jj` workspace only when needed. Never replace Jujutsu workspace state with Git worktrees.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated Jujutsu workspace."

## Command And Instruction Precedence

Repository-local instructions and configuration take precedence over the generic examples in this skill. Inspect them before choosing a base revision, workspace name, setup command, test command, bookmark, remote, or message style.

The commands below use current `jj` syntax. If the installed compatible `jj` version, `jj <command> --help`, or repository aliases require equivalent syntax, use that syntax instead of forcing these examples. Do not replace `jj` repository operations with Git commands.

Whenever composing a change or commit message, repository-local instructions and the message syntax visible in `git log` always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped plain-text body explaining what changed and why when needed. Do not impose a fixed prefix, type, scope, template, or example.

## Step 0: Detect Existing Isolation

**Before creating anything, check the current workspace and all workspaces attached to the repository.**

```bash
jj workspace root
jj workspace list
jj status
```

If the harness or user already placed you in a task-specific workspace, skip to Step 2. Do not create a workspace inside another task-specific workspace merely because multiple workspaces are supported.

Report:

> "Already in isolated Jujutsu workspace at `<path>` (`<workspace-name>@`)."

If the current workspace is the user's ordinary working copy, check whether the user has already declared a preference. If not, ask for consent:

> "Would you like me to set up an isolated Jujutsu workspace? It protects your current working copy from changes."

Honor an existing declared preference without asking. If the user declines, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

### Directory Selection

Follow this priority order. Explicit user and repository-local instructions always win.

1. Use a declared workspace location if one exists.
2. Otherwise use a repository-local temporary parent rooted at `$(jj workspace root)/.tmp/rocketclaw/workspaces`.
3. If resolving the workspace root is unavailable but the current directory is known to be the repository workspace, fall back to the local relative path `.tmp/rocketclaw/workspaces`. Do not fall back to a global temporary directory.

```bash
if root=$(jj workspace root 2>/dev/null); then
  workspace_parent="$root/.tmp/rocketclaw/workspaces"
else
  workspace_parent=".tmp/rocketclaw/workspaces"
fi
path="$workspace_parent/$WORKSPACE_NAME"
```

Use a short, unique `$WORKSPACE_NAME`. Before creation, use `jj workspace list` to ensure the name is not already registered and verify that `$path` is absent or an empty destination directory.

### Safety Verification

Jujutsu uses `.gitignore`; there is no `.jjignore`. Before creating a project-local workspace, inspect the applicable `.gitignore` files and verify that `.tmp/rocketclaw/` is ignored.

If it is not ignored, add `/.tmp/rocketclaw/` to the repository's `.gitignore`. Record that change using the repository's normal Jujutsu workflow before creating the nested workspace. After confirming the working-copy change contains only the intended ignore update, compose the description with `jj describe` and start a new change with `jj new`. Repository-local instructions and the message syntax visible in `git log` always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped plain-text body explaining what changed and why when needed. Do not impose a fixed prefix, type, scope, template, or example.

**Why critical:** New files are automatically tracked by Jujutsu unless ignored. Ignoring the workspace parent prevents workspace contents from entering the enclosing working-copy change.

### Choose The Base Revision

Use the base revision named by the plan, user, or repository instructions. Otherwise inspect the graph and bookmarks rather than assuming `main`:

```bash
jj log
jj bookmark list
```

Fetch first when current remote state is required:

```bash
jj git fetch
```

`jj git fetch` and `jj git push` are the transport commands for Git-backed repositories. Respect repository-local remote configuration; specify `--remote <remote>` only when needed.

### Add The Workspace

```bash
jj workspace add --name "$WORKSPACE_NAME" -r "$BASE_REVISION" "$path"
cd "$path"
jj status
```

`-r` selects the parent revision of the new workspace's fresh working-copy commit. It does not create a Git branch. If no base is specified, `jj workspace add` creates the new working-copy commit with the same parent or parents as the current working-copy commit; use that default only when it is intentional.

Do not add a fixed `-m` argument to workspace creation. If a description is useful, repository-local instructions and the message syntax visible in `git log` always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped plain-text body explaining what changed and why when needed. Do not impose a fixed prefix, type, scope, template, or example.

**Sandbox fallback:** If workspace creation fails because the sandbox denies the destination, report the denial and work in the current workspace only with user approval. Then run setup and baseline tests in place.

## Step 2: Project Setup

Auto-detect and run appropriate setup, subject to repository-local instructions:

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

Keep tool scratch data under `.rocketclaw/` when persistent workspace-local state is needed.

## Step 3: Verify Clean Baseline

Run the repository's appropriate test command:

```bash
# Examples only; repository-local commands take precedence
npm test / cargo test / pytest / go test ./...
```

If tests fail, report the failures and ask whether to proceed or investigate. If tests pass, report ready.

### Report

```text
Jujutsu workspace ready at <full-path>
Baseline tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Publishing And Completion

Use Jujutsu for repository state and Git transport. Create or move the intended bookmark to the revision being published, push it with `jj git push`, then use the provider-appropriate forge tooling or the creation URL emitted by the push. On GitHub, use `gh` for operations such as creating or viewing a pull request. Determine the exact revision, bookmark, remote, and forge workflow from repository-local instructions; do not assume a fixed `@` versus `@-` workflow.

When composing the published change description or commit message, repository-local instructions and the message syntax visible in `git log` always win. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped plain-text body explaining what changed and why when needed. Do not impose a fixed prefix, type, scope, template, or example.

Typical commands, adjusted to the repository's workflow, are:

```bash
jj describe
jj bookmark create <bookmark> -r <revision>
jj git push --bookmark <bookmark>
<provider-appropriate PR/MR command; on GitHub, gh pr create>
```

When the workspace is no longer needed, first ensure its work is described and reachable from the intended bookmark or otherwise recorded. From another workspace, forget it and then remove its directory separately:

```bash
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` does not delete files on disk. Never remove a workspace directory until its work is safely retained and the user or owning workflow permits cleanup.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in a task-specific workspace | Skip creation |
| Need isolation | Use `jj workspace add` |
| Need repository root | Use `jj workspace root` |
| Need attached workspaces | Use `jj workspace list` |
| No declared location | Use `$(jj workspace root)/.tmp/rocketclaw/workspaces` |
| Root lookup unavailable | Use local `.tmp/rocketclaw/workspaces` only when already at the repository workspace |
| Directory not ignored | Add `/.tmp/rocketclaw/` to `.gitignore` and record the change |
| Need remote updates | Use `jj git fetch` / `jj git push` |
| Need GitHub operations | Use `gh` after publishing the bookmark |
| Workspace becomes stale | Run `jj workspace update-stale` in that workspace |
| Finished with workspace | Safely retain work, `jj workspace forget`, then remove files separately |
| Permission error on create | Report and request approval to work in place |
| Baseline tests fail | Report failures and ask |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously isolated; no need to check" | Run `jj workspace root` and `jj workspace list`. Harness-created isolation is easy to overlook. |
| "A Git worktree is close enough" | It is a different mechanism. Use `jj workspace add` so Jujutsu owns the working-copy commit and workspace metadata. |
| "The temporary directory is surely ignored" | Check `.gitignore` handling first. Jujutsu automatically tracks new, unignored files. |
| "I should create a branch with the workspace" | Jujutsu workspaces have working-copy commits, not per-workspace Git branches. Create or move a bookmark when the workflow needs one. |
| "I can delete the directory when done" | First retain the work and run `jj workspace forget`; forgetting and deleting are separate operations. |
| "The workspace is fresh; baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
