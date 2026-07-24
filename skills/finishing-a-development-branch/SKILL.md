---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests -> identify changes and workspace -> verify descriptions -> present options -> execute choice -> clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop. The menu comes after a green suite:

```text
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Identify Changes and Workspace

Identify the completed change and workspace explicitly. A bookmark at an ancestor does not define the working-copy change:

```bash
jj status
jj log -r '@ | @- | bookmarks()'
jj bookmark list -r '@ | @-'
jj workspace list
WORKSPACE_PATH=$(jj workspace root)
```

Record these values before later commands can rewrite revisions or change directory:

| Value | How to determine it |
|-------|---------------------|
| `<feature-tip>` | The stable change ID for `@` when it contains the completed work, or for `@-` when `@` is a new empty change above it |
| `<feature-bookmark>` | A local bookmark at `<feature-tip>`, if one exists; otherwise leave unset until pushing requires one |
| `<workspace-name>` | Match the working-copy change ID in `jj log -r @` to `jj workspace list` |
| `<workspace-path>` | The exact output of `jj workspace root` |

If the selection is ambiguous, ask which change is the completed feature tip before offering integration or discard operations.

## Step 3: Determine Base and Verify Descriptions

The base is whatever the work was based on, usually named in the plan, conversation, or a tracked remote bookmark. Inspect likely bases without assuming one from a conventional name:

```bash
jj bookmark list --all-remotes main master
jj log -r 'heads((::<feature-tip> & bookmarks()) ~ <feature-tip>)'
```

If the base is not already known, ask: "This work was based on `<base-bookmark>` - is that correct?" Confirm before integrating; choosing the wrong base is expensive to undo.

Inspect every change that would be integrated or pushed:

```bash
jj log -r '<base-bookmark>..<feature-tip>'
jj log --no-graph -r '<base-bookmark>..<feature-tip>' -T 'description ++ "\n"'
```

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Compose descriptions from the actual diff and repository history. Repository-local description syntax and established history take precedence. Apply compatible Go guidance to description quality, clarity, and structure without replacing the repository's syntax. Do not impose a fixed description format, type, scope, prefix, issue-reference form, trailer policy, or template.

Every non-empty change must have an accurate, repository-appropriate description. Edit a deficient one with `jj describe <revision>`, then inspect the stack again. Before any fetch or rewrite, retain each candidate as an immutable commit ID for repeated `-r` arguments, and retain `<feature-tip>` as its stable change ID:

```bash
jj log --no-graph -r '<base-bookmark>..<feature-tip>' -T 'commit_id ++ "\n"'
```

Do not continue until all descriptions are suitable for durable history.

## Step 4: Present Options

Present exactly these three options:

```text
Implementation complete. What would you like to do?

1. Integrate into <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written. Discard happens only when your human partner explicitly asks to throw the work away; do not offer it in the menu. Wait for their answer because the integration decision is theirs.

## Step 5: Execute Choice

### Option 1: Integrate Locally

Fetch the configured remote, rebase exactly the retained feature revisions onto the updated base, and test the integrated feature tip before moving the base bookmark. Repeated `-r` arguments preserve dependencies among the selected revisions, and the retained change ID follows the rewritten tip.

```bash
jj git fetch --remote <remote>
jj rebase -r <retained-commit-id-1> -r <retained-commit-id-2> ... -o <base-bookmark>
jj edit <feature-tip>

# Verify tests on the integrated result.
<test command>
```

If the rebase conflicts or tests fail, stop, preserve the workspace and bookmarks, and investigate. The base bookmark has not moved and nothing has been pushed.

Once the integrated result is green, advance the base bookmark without pushing it:

```bash
jj bookmark move <base-bookmark> --to <feature-tip>
```

Then inspect local and remote bookmark state with `jj bookmark list --all-remotes <feature-bookmark>`. If the feature bookmark exists only for this work and was never pushed, forget it without scheduling a remote deletion:

```bash
jj bookmark forget <feature-bookmark>
```

Use `jj bookmark delete <feature-bookmark>` only when your human partner explicitly wants the corresponding tracked remote bookmark deleted on a later push. Continue to Step 6 only after integration and tests succeed.

### Option 2: Push and Create PR

Ensure a named bookmark points to the feature tip. Create it if absent; otherwise move it explicitly because Jujutsu bookmarks do not automatically advance with new descendant changes:

```bash
jj bookmark create <feature-bookmark> -r <feature-tip>
# Or, when it already exists:
jj bookmark move <feature-bookmark> --to <feature-tip>

jj git push --bookmark <feature-bookmark> --remote <remote>
```

Then create the pull or merge request against `<base-bookmark>` with the forge's tooling, or use the creation URL printed by the push. Build its title and body from the verified changes and follow the repository's request template and conventions. Report the resulting URL.

Keep the workspace; your human partner iterates on review feedback there.

### Option 3: Keep As-Is

Report: "Keeping change `<feature-tip>`<and bookmark `<feature-bookmark>` when present>. Workspace preserved at `<workspace-path>`."

Do not clean up the workspace or create a bookmark solely for this option.

### If Your Human Partner Asks to Discard the Work

This path exists only in response to an explicit request to throw the work away. First show the exact changes:

```bash
jj log -r '<base-bookmark>..<feature-tip>'
```

Then confirm with runtime values:

```text
This will abandon:
- Bookmark: <feature-bookmark-or-none>
- Changes: <change-list>
- Workspace: <workspace-path-and-ownership-action>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives, abandon only the displayed feature revset:

```bash
jj abandon '<base-bookmark>..<feature-tip>'
```

Abandoning is recoverable through Jujutsu's operation log and removes local bookmarks pointing to the abandoned changes. If a corresponding tracked remote bookmark exists, do not push its deletion unless your human partner explicitly requests that remote effect. Then continue to Step 6.

## Step 6: Clean Up an Owned Workspace

Run this step only after successful local integration or confirmed discard. Push and keep-as-is always preserve the workspace.

Jujutsu workspace registration and filesystem cleanup are separate. Before either action, retain the exact workspace name and path and select a surviving workspace for repository commands after cleanup:

```bash
WORKSPACE_PATH=$(jj workspace root)
jj workspace list
```

Apply path-provenance rules:

| Workspace state | Action |
|-----------------|--------|
| Durable/default workspace | Do not forget or remove it |
| Workspace strictly beneath `<durable-root>/.workspaces/` or `<durable-root>/workspaces/` | Owned; cleanup is permitted |
| Any other path | Externally managed; do not forget or remove it |

Never infer ownership from the workspace name. Obtain `<durable-root>` with `jj workspace root --name <durable-workspace>`, resolve both paths physically, and require the candidate to be a strict child of one of the two managed directories. An equal path, parent path, symlink escape, or unresolved traversal is not owned.

For an owned workspace, leave its directory before forgetting it. Run the command from a surviving workspace so the repository remains addressable:

```bash
SURVIVING_ROOT=$(jj workspace root --name <surviving-workspace>)
cd "$SURVIVING_ROOT"
jj workspace forget <workspace-name>
```

Only after `jj workspace forget` succeeds, remove the forgotten workspace directory with the platform's approved workspace-removal mechanism. If none exists, leave the files in place and report the path; `jj workspace forget` deliberately does not delete files.

## Repository-Local Temporary Paths

If any completion step needs temporary files, keep them inside the current repository workspace:

```bash
if REPO_ROOT=$(jj workspace root 2>/dev/null); then
  TEMP_ROOT="$REPO_ROOT/.tmp"
else
  TEMP_ROOT="$PWD/.tmp"
fi
mkdir -p "$TEMP_ROOT"
```

Create task-specific children beneath `$TEMP_ROOT`, clean them when finished, and never use an operating-system temporary path, an environment-provided temporary directory, or a random temporary-file utility.

## Quick Reference

| Option | Integrate | Push | Keep workspace | Bookmark cleanup |
|--------|-----------|------|----------------|------------------|
| 1. Integrate locally | yes | no | only if unowned | forget local feature bookmark when appropriate |
| 2. Create PR | no | yes | yes | no |
| 3. Keep as-is | no | no | yes | no |
| Discard (explicit request only) | abandon selected changes | no | only if unowned | automatic for bookmarks on abandoned changes |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it integrated" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature, so I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner explicitly asks for it. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes abandonment. |
| "The request is up, so the workspace is clutter now" | Review feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale, so I'll clean it too" | Clean up only an owned workspace with strict managed-path provenance. Everything else belongs to its host. |
| "The integrated-result failure is probably flaky" | A failing integrated result stops everything. The workspace and bookmarks stay in place while you investigate. |
| "The base is obviously main" | Confirm what the work was based on. Integrating onto the wrong base is expensive to undo. |
| "The push was rejected, so I'll force it" | Jujutsu push safety checks indicate changed remote or bookmark state. Fetch and investigate; do not bypass them without explicit approval. |
| "The bookmark names the feature, so it must be current" | Bookmarks do not follow descendant changes automatically. Inspect and move the bookmark explicitly. |
