---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop — the menu comes after a green suite:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

```bash
<<<<<<< conflict 1 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
-GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
WS_ROOT=$(jj workspace root)
# Current workspace name (empty-ish if listing fails)
WS_NAME=$(jj workspace list -T 'if(self.working_copy(), self.name() ++ "\n", "")' 2>/dev/null | head -1)
# Bookmarks on the working-copy commit (empty = no bookmark on @)
BOOKMARKS=$(jj log -r @ -T 'local_bookmarks.map(|b| b.name()).join(" ")' --no-graph)
>>>>>>> conflict 1 of 22 ends
# Capture now, while still inside the workspace — Step 5 changes directory
<<<<<<< conflict 2 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
# before cleanup (Step 6) needs these values
WORKSPACE_PATH=$(jj workspace root)
# jj workspace list lines look like: "name: /absolute/path"
# default workspace is named "default"; secondary workspaces have other names
WORKSPACE_NAME=$(jj workspace list | awk -F': ' -v p="$WORKSPACE_PATH" '$2 == p { print $1; exit }')
MAIN_ROOT=$(jj workspace list | awk -F': ' '/^default:/{ print $2; exit }')
# Empty CURRENT_BOOKMARKS ⇒ working-copy commit with no bookmark on @
CURRENT_BOOKMARKS=$(jj log -r @ --template 'local_bookmarks' --no-graph 2>/dev/null)
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
 # before cleanup (Step 6) needs this value
-WORKTREE_PATH=$(git rev-parse --show-toplevel)
+WORKSPACE_PATH="$WS_ROOT"
>>>>>>> conflict 2 of 22 ends
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
<<<<<<< conflict 3 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 3 options | No worktree to clean up |
-| `GIT_DIR != GIT_COMMON`, named branch | Standard 3 options | Provenance-based (see Step 6) |
-| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 2 options (no merge) | Externally managed — leave in place |
+| `WORKSPACE_NAME` is `default` (or only workspace) | Standard 3 options | No workspace to clean up |
+| Secondary workspace, bookmark(s) on `@` | Standard 3 options | Provenance-based (see Step 6) |
+| Secondary workspace, no bookmark on `@` | Reduced 2 options (no merge) | Externally managed — leave in place |
 
-## Step 3: Determine Base Branch
+## Step 3: Determine Base Bookmark
 
-The base branch is whatever this work forked from — usually named in the
-plan, the conversation, or the branch's upstream. If it is not already
-known, ask: "This branch split from <your best guess> - is that correct?"
-Confirm before merging: merging into the wrong base is expensive to undo.
+The base bookmark is whatever this work forked from — usually named in the
+plan, the conversation, or the bookmark's upstream tracking. If it is not
+already known, ask: "This bookmark split from <your best guess> - is that
+correct?" Confirm before merging: merging into the wrong base is expensive
+to undo.
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
| Default workspace at repo root (normal) | Standard 3 options | No workspace to clean up |
| Path under `.worktrees/` or `worktrees/` (or `workspaces/`), named bookmark on `@` | Standard 3 options | Provenance-based (see Step 6) |
| Isolated or non-default workspace, no bookmark on `@` | Reduced 2 options (no merge) | Externally managed — leave in place |

Path-based isolation: if `WS_ROOT` contains `/.worktrees/`, `/worktrees/`, or `/workspaces/`, treat as an isolated workspace. Otherwise treat as the default (normal) workspace at the repo root.

## Step 3: Determine Base Bookmark

The base bookmark is whatever this work forked from — usually named in the
plan, the conversation, or the bookmark's upstream. If it is not already
known, ask: "This bookmark split from <your best guess> - is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.
>>>>>>> conflict 3 of 22 ends

## Step 4: Present Options

<<<<<<< conflict 4 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
**Default workspace and named-bookmark secondary workspace — present exactly these 3 options:**
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-**Normal repo and named-branch worktree — present exactly these 3 options:**
+**Normal repo and named-bookmark workspace — present exactly these 3 options:**
>>>>>>> conflict 4 of 22 ends

```
Implementation complete. What would you like to do?

1. Merge back to <base-bookmark> locally
2. Push and create a Pull Request
3. Keep the bookmark as-is (I'll handle it later)

Which option?
```

<<<<<<< conflict 5 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
**Working-copy commit with no bookmark on `@` (externally managed workspace) — present exactly these 2 options:**
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-**Detached HEAD — present exactly these 2 options:**
+**No bookmark on `@` (externally managed workspace) — present exactly these 2 options:**
>>>>>>> conflict 5 of 22 ends

```
<<<<<<< conflict 6 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
Implementation complete. You're on a working-copy commit with no bookmark on @ (externally managed workspace).
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-Implementation complete. You're on a detached HEAD (externally managed workspace).
+Implementation complete. You're on a working-copy commit with no bookmark (externally managed workspace).
>>>>>>> conflict 6 of 22 ends

1. Push as new bookmark and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Merge Locally

```bash
<<<<<<< conflict 7 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-# Get main repo root for CWD safety
-MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
+# Get default workspace root for CWD safety (captured in Step 2 as MAIN_ROOT)
 cd "$MAIN_ROOT"
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
# Get default workspace root for CWD safety
# Prefer the workspace whose path is the repo root (not under .worktrees/worktrees/workspaces)
DEFAULT_WS_ROOT=$(jj workspace list -T 'self.name() ++ "\t" ++ self.path() ++ "\n"' 2>/dev/null | awk -F'\t' '$2 !~ /\/\.worktrees\// && $2 !~ /\/worktrees\// && $2 !~ /\/workspaces\// { print $2; exit }')
# Fallback: parent of .worktrees/worktrees/workspaces if current path is isolated
if [ -z "$DEFAULT_WS_ROOT" ]; then
  DEFAULT_WS_ROOT=$(echo "$WORKSPACE_PATH" | sed -E 's#/(\.worktrees|worktrees|workspaces)/.*##')
fi
cd "$DEFAULT_WS_ROOT"
>>>>>>> conflict 7 of 22 ends

<<<<<<< conflict 8 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
# Fetch, then merge — verify success before removing anything
jj git fetch
# Create a merge commit with both parents (base + feature):
jj new <base-bookmark> <feature-bookmark>
# Advance the base bookmark to the merge result:
jj bookmark move <base-bookmark> --to @
# Alternative integrate-then-advance flow:
# jj rebase -b <feature-bookmark> -d <base-bookmark>
# jj bookmark set <base-bookmark> -r <feature-bookmark> --allow-backwards  # careful
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
 # Merge first — verify success before removing anything
-git checkout <base-branch>
-git pull
-git merge <feature-branch>
+# Fetch latest base, then create a merge change with both parents
+jj git fetch
+jj new <base-bookmark> <feature-bookmark>
>>>>>>> conflict 8 of 22 ends

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the workspace and bookmark in
place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the merged result is green: clean up the workspace (Step 6), then
delete the feature bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

### Option 2: Push and Create PR

```bash
<<<<<<< conflict 9 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
jj git push --bookmark <feature-bookmark> --remote origin
# From a working-copy commit with no bookmark on @, create and push a new bookmark:
# jj bookmark create <new-bookmark> -r @
# jj git push --bookmark <new-bookmark> --remote origin
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-git push -u origin <feature-branch>
-# From a detached HEAD, name the new branch on the remote:
-# git push origin HEAD:refs/heads/<new-branch>
+jj git push --bookmark <feature-bookmark>
+# From a working-copy commit with no bookmark, name the new bookmark then push:
+# jj bookmark set <new-bookmark> -r @
+# jj git push --bookmark <new-bookmark>
>>>>>>> conflict 9 of 22 ends
```

<<<<<<< conflict 10 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
Then create the pull/merge request against <base-bookmark> with the forge's
tooling — its CLI if one is available (e.g. `gh pr create`), or the creation
URL most forges print when you push — following the repo's PR template and
conventions if present, and report the URL to your human partner.
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-Then create the pull/merge request against <base-branch> with the forge's
+Then create the pull/merge request against <base-bookmark> with the forge's
 tooling — its CLI if one is available, or the creation URL most forges
 print when you push — following the repo's PR template and conventions if
 present, and report the URL to your human partner.
>>>>>>> conflict 10 of 22 ends

Keep the workspace — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping bookmark <name>. Workspace preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
<<<<<<< conflict 11 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-- Branch <name>
+- Bookmark <name>
 - All commits: <commit-list>
-- Worktree at <path>
+- Workspace at <path>
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
- Bookmark <name>
- All changes: <change-list>
- Workspace at <path>
>>>>>>> conflict 11 of 22 ends

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
<<<<<<< conflict 12 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
 cd "$MAIN_ROOT"
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
DEFAULT_WS_ROOT=$(jj workspace list -T 'self.name() ++ "\t" ++ self.path() ++ "\n"' 2>/dev/null | awk -F'\t' '$2 !~ /\/\.worktrees\// && $2 !~ /\/worktrees\// && $2 !~ /\/workspaces\// { print $2; exit }')
if [ -z "$DEFAULT_WS_ROOT" ]; then
  DEFAULT_WS_ROOT=$(echo "$WORKSPACE_PATH" | sed -E 's#/(\.worktrees|worktrees|workspaces)/.*##')
fi
cd "$DEFAULT_WS_ROOT"
>>>>>>> conflict 12 of 22 ends
```

Then clean up the workspace (Step 6) and delete the bookmark:

```bash
jj bookmark delete <feature-bookmark>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
<<<<<<< conflict 13 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
preserve the workspace. Both callers have already changed directory to the
default workspace root — workspace removal must run from outside the
workspace being removed — and use the `WORKSPACE_PATH` / `WORKSPACE_NAME` /
`MAIN_ROOT` values captured in Step 2, from before that directory change.
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-preserve the worktree. Both callers have already changed directory to the
-main repo root — worktree removal must run from outside the worktree —
-and use the `GIT_DIR`/`GIT_COMMON`/`WORKTREE_PATH` values captured in
-Step 2, from before that directory change.
+preserve the workspace. Both callers have already changed directory to the
+default workspace root — workspace removal must run from outside the
+workspace being removed — and use the `WS_ROOT`/`WS_NAME`/`WORKSPACE_PATH`
+values captured in Step 2, from before that directory change.
>>>>>>> conflict 13 of 22 ends

<<<<<<< conflict 14 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.
+**If `WORKSPACE_NAME` is `default` (or there is no secondary workspace):**
+Normal checkout, no workspace to clean up. Done.
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
**If default workspace at repo root (not under `.worktrees/` / `worktrees/` / `workspaces/`):** Normal repo, no workspace to clean up. Done.
>>>>>>> conflict 14 of 22 ends

<<<<<<< conflict 15 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** Superpowers
-created this worktree — we own cleanup:
+**If `WORKSPACE_PATH` is under `.worktrees/` or `worktrees/`:** RocketClaw
+created this workspace — we own cleanup:
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
**If `WORKSPACE_PATH` is under `.worktrees/` or `worktrees/` or `workspaces/`:** RocketClaw
created this workspace — we own cleanup:
>>>>>>> conflict 15 of 22 ends

```bash
<<<<<<< conflict 16 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-git worktree remove "$WORKTREE_PATH"
-git worktree prune  # Self-healing: clean up any stale registrations
+jj workspace forget "$WORKSPACE_NAME"
+rm -rf "$WORKSPACE_PATH"
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
jj workspace forget <workspace-name>
rm -rf "$WORKSPACE_PATH"  # if the directory still exists after forget
>>>>>>> conflict 16 of 22 ends
```

<<<<<<< conflict 17 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-**If removal is refused** (`contains modified or untracked files`): the
-worktree holds files that exist nowhere else — uncommitted plans, notes,
-or scratch work. Never `--force` on your own initiative. Show your human
-partner what is at stake and ask:
+**Before `rm -rf`:** inspect the workspace working copy. If it holds files
+that exist nowhere else — undescribed changes, notes, or scratch work —
+never delete on your own initiative. Show your human partner what is at
+stake and ask:
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
JJ has no prune step after forget; `jj workspace forget` drops the registration.

**If removal is refused** or the workspace still has unsettled local state: the
workspace holds files that exist nowhere else — undescribed plans, notes,
or scratch work. Never force-delete on your own initiative. Show your human
partner what is at stake and ask:
>>>>>>> conflict 17 of 22 ends

```bash
<<<<<<< conflict 18 of 22
+++++++ ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
# From outside the workspace being removed, or with -R if supported by your jj:
jj -R "$WORKSPACE_PATH" st
# Fallback if -R is unavailable: inspect while still inside before cd'ing out
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
-git -C "$WORKTREE_PATH" status --porcelain -uall
+jj -R "$WORKSPACE_PATH" status
+# Or from inside that workspace before leaving it:
+# jj st
>>>>>>> conflict 18 of 22 ends
```

```
<<<<<<< conflict 19 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-Worktree removal refused — these files were never committed:
+Workspace cleanup blocked — these changes were never fully integrated:
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
Workspace cleanup paused — these files may not be in any described change:
>>>>>>> conflict 19 of 22 ends

<status output>

1. Describe/commit them on <bookmark> before cleanup
2. Move them into <default workspace root>
3. Delete them (unrecoverable)

Which?
```

<<<<<<< conflict 20 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-Carry out the choice, then remove the worktree.
+Carry out the choice, then forget the workspace and remove the directory.
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
When option 1 is chosen (describe/commit before cleanup):

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax from project instructions and `git log` ALWAYS wins over Go guidance when they differ. Do not use fixed Conventional Commit templates. Use `jj describe -m "<message composed from the standards above>"` or `jj commit -m "<message composed from the standards above>"` as appropriate.

Carry out the choice, then remove the workspace.
>>>>>>> conflict 20 of 22 ends

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Bookmark |
|--------|-------|------|----------------|------------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
<<<<<<< conflict 21 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-| Discard (explicit request only) | - | - | - | yes (force) |
+| Discard (explicit request only) | - | - | - | yes |
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
| Discard (explicit request only) | - | - | - | yes (delete) |
>>>>>>> conflict 21 of 22 ends

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
<<<<<<< conflict 22 of 22
%%%%%%% diff from: lqlluxol b36e0829 "Release v6.3.0: Devin CLI and Hermes Agent support, brainstorming three-path router, SDD/Codex efficiency fixes (#2125)"
\\\\\\\        to: ptokpnzt 547bc7e6 "skills: merge release-based Jujutsu semantic port into main"
-| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
-| "This other worktree looks stale — I'll clean it too" | Clean up only worktrees under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
-| "Removal refused — `--force` is just finishing the cleanup" | The refusal means files exist only in that worktree. `--force` destroys them permanently. Show your human partner and ask. |
-| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
-| "The base branch is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
+| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
+| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
+| "Cleanup blocked — `rm -rf` is just finishing the cleanup" | A dirty `jj st` means files or changes exist only in that workspace. Blind `rm -rf` destroys them permanently. Show your human partner and ask. |
+| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
+| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
+++++++ wyvxmxxv f827924b "skills: port VCS workflows from Git to Jujutsu and rebrand namespaces to RocketClaw"
| "The PR is up, so the workspace is clutter now" | PR feedback gets fixed in that workspace. It stays until the work lands. |
| "This other workspace looks stale — I'll clean it too" | Clean up only workspaces under `.worktrees/`, `worktrees/`, or `workspaces/`. Everything else belongs to the host. |
| "Removal refused — force-delete is just finishing the cleanup" | The refusal means files exist only in that workspace. Force-delete destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Bookmark and workspace stay put while you investigate. |
| "The base bookmark is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
>>>>>>> conflict 22 of 22 ends
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
