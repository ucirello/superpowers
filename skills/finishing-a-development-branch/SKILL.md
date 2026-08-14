---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Change

## Overview

**Core principle:** Verify the change, identify its JJ revisions, present the choices, execute exactly one choice, and preserve recoverability.

**Announce at start:** "I'm using superpowers:finishing-a-development-branch to complete this work."

This workflow is for a Jujutsu repository. JJ bookmarks, revisions, and
workspaces are the source of truth.

## Step 1: Verify the Completed Change

Run the project's full test suite using the command already established for the
repository. Do not guess additional lint or test commands by inspecting the
repository at this stage.

**If tests fail**, report the failures and stop. Do not present the integration
menu for a change that is not green.

**If tests pass**, run:

```bash
jj status
jj log -r 'trunk()..@' --no-pager
```

Stop if the working copy has conflicts. A JJ conflict is recorded in a
revision; it is not safe to push or integrate merely because a command exited
successfully.

## Step 2: Identify Base, Tip, and Bookmark

Determine the base from the plan, conversation, or repository convention. Use
`trunk()` only when it resolves to the intended base. If the base is uncertain,
ask: "This change is based on <best guess> - is that correct?"

Identify the complete feature stack with a revset before changing anything:

```bash
jj log -r '<base>..<candidate-tip>' --no-pager
```

The candidate tip is `@` when the working-copy change contains completed work.
If `@` is merely an empty working-copy change above the completed stack, the
candidate tip is `@-`. Confirm that the selected range contains all and only the
intended revisions. Stop and ask if the range includes unrelated work, multiple
heads, or revisions that should remain separate.

Record these values for the rest of the workflow:

```text
BASE=<confirmed base bookmark or revset>
TIP=<completed tip revision>
FEATURE=<existing feature bookmark or agreed new bookmark name>
```

Use an existing feature bookmark only if it points into the selected stack.
Do not move an unrelated bookmark. If there is no suitable bookmark, Option 2
will create one; Options 1 and 3 do not require inventing one prematurely.

If temporary files are needed, put them under the repository-local `.tmp/`
directory. Never use a workspace outside the repository for this workflow.

## Step 3: Seal the Tip

JJ snapshots the working copy automatically. Before presenting choices, ensure
every non-empty revision in `$BASE..$TIP` has a meaningful description. Do not
push with `--allow-empty-description` to bypass missing descriptions.

When composing a change description or commit message, use this exact instruction:

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and the message syntax established by repository
history always win; inspect history with the runtime's available command. Apply
compatible Go guidance to clarity and structure: use a concise summary that
explains what the change does and add an explanatory body when useful. Do not
impose a fixed prefix, type, scope, subject, or body. PR titles and bodies follow
repository-local PR instructions and templates instead.

If `TIP` is `@`, finish editing it by starting a new empty working-copy change:

```bash
jj new "$TIP"
```

Then update `TIP` to the completed parent (`@-`). This does not lose working-copy
files; it makes the completed revision
distinct from the new working-copy revision.

## Step 4: Present Options

Present exactly these choices:

```text
Implementation complete. What would you like to do?

1. Integrate into <base> locally
2. Push and create a Pull Request
3. Keep the change as-is (I'll handle it later)

Which option?
```

Wait for the answer. Do not add discard to the menu. Abandoning work is allowed
only after an explicit request and the confirmation in the discard section.

## Step 5: Execute the Choice

### Option 1: Integrate Locally

Fetch before rewriting so the destination reflects the last known remote state:

```bash
jj git remote list
jj git fetch --remote '<base-remote>'
```

If `<base>@origin` exists, use it as the rebase destination; otherwise use the
confirmed local base. If the local and remote base bookmarks conflict, stop and
resolve that ambiguity instead of choosing one silently.

Rebase exactly the reviewed feature stack onto the destination:

```bash
jj rebase --revisions '<destination>..<tip>' --onto '<destination>'
```

`--revisions` preserves dependencies within the selected set without selecting
anonymous descendants beyond the tip. Do not use bare `jj rebase`: its default
branch selection can include revisions that are not part of the reviewed stack.
Inspect the rewritten stack and stop if JJ reports conflicts:

```bash
jj log -r '<destination>..<rewritten-tip>' --no-pager
jj status
```

Run the established test command on the rebased result. If it fails, stop. Keep
the rewritten revisions and identify the operation with `jj op log`. Explain
that `jj op revert '<operation-id>'` can reverse that operation after inspection;
do not revert automatically because later concurrent JJ operations may exist.

Advance the local base bookmark only after the rebase and verification succeed:

```bash
jj bookmark set '<base-bookmark>' --revision '<rewritten-tip>'
```

This is JJ's local fast-forward-style integration. Do not create a synthetic
merge revision. If a feature bookmark exists, delete only the local bookmark
after confirming the base bookmark points to the integrated tip:

```bash
jj bookmark forget '<feature-bookmark>'
```

Forgetting the bookmark does not abandon revisions or schedule a remote deletion.

Finish on a fresh empty change based on the integrated base:

```bash
jj new '<base-bookmark>'
```

### Option 2: Push and Create a Pull Request

Ensure the feature bookmark points to the completed tip before publishing it.
Create it if absent; otherwise move only the
confirmed feature bookmark:

```bash
jj bookmark create '<feature-bookmark>' --revision '<tip>'
# Or, for the already-existing feature bookmark:
jj bookmark set '<feature-bookmark>' --revision '<tip>'
```

If `bookmark set` requires `--allow-backwards`, stop and investigate. Do not
move a bookmark backwards or sideways as part of routine finishing.

Fetch, inspect the outgoing update, and push only this bookmark:

```bash
jj git remote list
jj git fetch --remote '<push-remote>'
jj git push --remote '<push-remote>' --bookmark '<feature-bookmark>' --dry-run
jj git push --remote '<push-remote>' --bookmark '<feature-bookmark>'
```

JJ applies lease-like safety checks against its last fetched remote state. If
the push is rejected, fetch and inspect the remote bookmark. Never bypass the
rejection with a force-push. Do not use bare `jj git push`, `--all`,
`--tracked`, or `--deleted`; those forms may publish unrelated bookmark updates.

Create the PR against the confirmed base using the repository's template and
conventions. `gh pr create --base '<base>' --head '<feature-bookmark>'` is
acceptable. Do not prescribe a fixed title or body format. Report the PR URL.

Keep the feature bookmark, revisions, and workspace for PR feedback.

### Option 3: Keep As-Is

Do not move or create bookmarks. Report the completed tip, any bookmark already
pointing to it, and the repository path. Leave the current empty working-copy
change in place.

### Squashing, When Explicitly Requested

Do not squash merely because the change is being finished. Preserve deliberate
revision boundaries. If the user asks to combine revisions, show the selected
source and destination first, then use explicit revisions:

```bash
jj squash --from '<source>' --into '<destination>'
```

Squashing moves the source's changes into the destination and normally abandons
the source when it becomes empty. Never squash into the base or another
immutable revision. For a stack, squash one reviewed source at a time so
descriptions and conflicts can be checked after each operation. Recompute the
tip and move the feature bookmark only after the requested squashes succeed.

### If the User Asks to Discard the Work

This path exists only for an explicit request to throw the completed work away.
Show the exact revset and confirmation prompt:

```text
This will abandon these JJ revisions:

<jj log -r output for the exact feature-only revset>

Bookmarks pointing directly to abandoned revisions may also be deleted.
Tracked files unique to these revisions will disappear from the working copy.
Untracked files will not be deleted.

Type 'discard' to confirm.
```

Wait for the exact word `discard`. Recompute the revset immediately before the
operation and stop if it differs from what was shown. Then abandon only the
feature revisions, not the base and not unrelated descendants:

```bash
jj abandon '<exact-feature-revset>'
```

Do not use `--retain-bookmarks` unless the user explicitly wants affected
bookmarks moved to the abandoned revisions' parents. Do not delete `.tmp/` or
other untracked files as part of `jj abandon`; show them separately and ask
before deleting anything from the filesystem.

`jj abandon` rebases descendants onto the abandoned revisions' parents and, if
`@` is abandoned, creates a new empty working-copy change. Inspect `jj status`
and `jj log` afterward and report the result. If the wrong revisions were
abandoned, report the operation ID and offer `jj op revert '<operation-id>'`;
do not silently revert it.

## Quick Reference

| Choice | Rebase | Bookmark action | Push | Preserve revisions |
|--------|--------|-----------------|------|--------------------|
| 1. Integrate locally | exact feature stack | advance base, delete local feature bookmark | no | yes |
| 2. Create PR | only if separately requested | create/set feature bookmark | named bookmark only | yes |
| 3. Keep as-is | no | none | no | yes |
| Discard after confirmation | descendants rebase automatically | affected bookmarks may be deleted | no | no |

## Safety Rules

- A JJ bookmark is a movable label, not a checked-out workspace.
- `jj new` starts a fresh change; it does not publish or integrate its parent.
- `jj rebase --revisions` rebases only the reviewed set and preserves dependencies within it.
- `jj squash` moves changes and may abandon the emptied source; always name both ends.
- `jj abandon` is recoverable through the operation log, but still requires explicit confirmation.
- `jj git push --bookmark NAME` publishes that bookmark's target, not anonymous descendants beyond it.
- A rejected push means remote state needs inspection; never substitute a force-push.
- Use JJ bookmark, revision, and workspace operations throughout this workflow.
