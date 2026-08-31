---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Detect existing isolation first, prefer the harness's native workspace mechanism, and use `jj workspace` directly only when the harness has no native mechanism.

Done means the work is in an isolated workspace with project setup complete and a verified baseline, or the user has explicitly chosen to work in place.

## Detect Existing Isolation

Before creating anything, inspect the session context and Jujutsu workspace state:

```bash
jj root
jj workspace list
jj status
```

Treat the workspace as already isolated when the harness says it created or entered an isolated workspace, or when the current root is the task-specific workspace identified in the session. Jujutsu repositories always have at least one workspace, so the mere presence of `.jj` or a `default` workspace does not prove task isolation.

If isolation is already established, report the workspace root and current working-copy revision, then continue with project setup. Do not create a nested workspace.

If isolation is not established, honor any existing user preference. Otherwise ask:

> Would you like me to set up an isolated workspace? It protects the current working-copy change from this task.

If the user declines, work in place and continue with project setup.

## Create An Isolated Workspace

### Prefer Native Harness Support

Use a native workspace tool, command, or session option when the harness provides one. Native mechanisms own placement, session routing, and cleanup; bypassing them can create workspace state the harness cannot manage.

Continue manually only when no native mechanism is available.

### Manual Jujutsu Workspace

Before running a workspace command, consult that command's installed help. Infer supported options and syntax at runtime rather than relying on a fixed version-specific form.

```bash
jj workspace add --help
```

Choose a unique workspace name derived from the task. Manual workspace creation requires a Jujutsu repository; if `jj workspace root` fails, stop and report that requirement. Use a location explicitly supplied by the user or harness; otherwise use `$(jj workspace root)/.tmp/rocketclaw/workspaces/<workspace-name>`. The workflow-owned namespace self-ignores without replacing user-maintained ignore rules.

Create the workspace without a revision argument when the task should start as a new change beside the current working-copy change. Jujutsu then gives the new workspace a fresh working-copy change with the same parent(s), leaving current in-progress contents isolated. Supply a revision only when the user or plan identifies a different base.

```bash
workspace_root=$(jj workspace root) || { echo "manual workspace creation requires a Jujutsu repository" >&2; exit 2; }
temp_namespace="$workspace_root/.tmp/rocketclaw"
mkdir -p "$temp_namespace/workspaces"
if [ -e "$temp_namespace/.gitignore" ]; then
  [ "$(wc -l < "$temp_namespace/.gitignore" | tr -d ' ')" = 1 ] &&
    grep -qxF '*' "$temp_namespace/.gitignore" || { echo "unsafe temporary namespace" >&2; exit 2; }
else
  printf '*\n' > "$temp_namespace/.gitignore"
fi
WORKSPACE_PATH="$temp_namespace/workspaces/$WORKSPACE_NAME"
jj workspace add --name "$WORKSPACE_NAME" "$WORKSPACE_PATH"
cd "$WORKSPACE_PATH"
jj status
```

Defer bookmark creation until publication so it points to the completed tip;
bookmarks do not automatically follow later `jj new` operations. The finishing
workflow owns bookmark creation and push.

If workspace creation is blocked by sandbox permissions, report the blocked command and error. Ask whether to use a harness-approved location or work in place; do not silently weaken isolation.

Record the workspace name, registered root, source workspace root, and whether cleanup belongs to the native harness or this manual workflow. The finishing workflow must use this ownership record rather than infer ownership from the path.

## Project Setup

Detect the project's setup instructions and run the appropriate dependency or build command. Prefer repository documentation and configured package-manager metadata over these common indicators:

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi
if [ -f go.mod ]; then go mod download; fi
```

## Verify Baseline

Run the project-appropriate test command before implementation.

If tests fail, report the command and failures and ask whether to investigate or proceed with the known failing baseline. If tests pass, report the workspace as ready.

```text
Workspace ready at <full-path>
Working-copy revision: <change-id>
Baseline: <command and result>
Ready to implement <feature-name>
```

## Cleanup

Let the native harness mechanism clean up a workspace it created. For a manually created workspace, clean up only after the finishing workflow confirms that no needed work exists solely in its working-copy revision and that any required bookmark points to the intended revision.

Run the installed help before cleanup. From another registered workspace, verify that the recorded name resolves to the recorded root, forget that workspace, and only then remove that exact directory from disk. `jj workspace forget` does not delete files.

```bash
jj workspace root --name "$WORKSPACE_NAME"
jj workspace forget --help
jj workspace forget "$WORKSPACE_NAME"
```

Never remove a path that differs from the recorded workspace root or contains the current working directory.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Session already identifies an isolated workspace | Reuse it |
| Native workspace mechanism available | Use it |
| No native mechanism | Use `jj workspace add` after reading installed help |
| No location preference | Use `$(jj workspace root)/.tmp/rocketclaw/workspaces` |
| Task needs a named publication reference | Let the finishing workflow create it on the completed tip |
| Permission error | Report it and ask about an approved location or working in place |
| Baseline fails | Report failures and ask whether to investigate or proceed |
| Native mechanism created workspace | Leave cleanup to that mechanism |
| Manual workspace is finished | Verify retention, forget it, then remove its recorded root |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "This looks isolated already" | Session context plus `jj root`, `jj workspace list`, and `jj status` establish the actual state. |
| "A manual command is faster than finding the native tool" | The native mechanism owns session routing and cleanup. |
| "The workspace can use OS-global temporary storage" | Use the repository-local `.tmp` namespace so storage remains scoped to the workspace. |
| "Every task needs a bookmark immediately" | Workspaces isolate working-copy revisions; defer a publication bookmark until the completed tip exists. |
| "A fresh workspace does not need baseline tests" | A failing baseline makes later failures ambiguous. |
| "Forgetting the workspace also deletes it" | Jujutsu forgets the registration only; disk removal is a separate, guarded action. |
