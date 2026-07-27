# Scoped Re-Review Prompt Template

Use this template when dispatching a re-review after a fix round. The
re-reviewer verifies the findings were addressed and checks the fix diff for
new breakage. It is not a fresh review — the full review already happened.

**Purpose:** Verify each finding from the previous review was addressed, and
that the fix itself broke nothing.

```
Subagent (general-purpose):
  description: "Re-review Task N fix round R"
  model: [MODEL — REQUIRED: choose per SKILL.md Model Selection; an omitted
         model silently inherits the session's most expensive one]
  prompt: |
    You are re-reviewing one task's fix round. A previous review produced
    findings; an implementer has attempted to fix them. Your job is to
    verdict each finding and inspect the fix diff — nothing else.

    ## The Task

    Read the task brief: [BRIEF_FILE]

    ## The Findings Under Verification

    [FINDINGS]

    ## The Fix

    Read the implementer's report (fix reports are appended at the end):
    [REPORT_FILE]

    **Fix base:** [FIX_BASE_CHANGE_ID] (the change the previous review saw)
    **Fix head:** [FIX_HEAD_CHANGE_ID]
    **Diff file:** [DIFF_FILE]

    Read the diff file once — it contains the fix revisions, a `jj show`
    summary of the fix head, a stat summary, and the fix diff with surrounding
    context. Do not re-run Jujutsu commands.
    If the diff file is missing, fetch the diff yourself:
    `jj diff --stat --from [FIX_BASE_CHANGE_ID] --to [FIX_HEAD_CHANGE_ID]` and
    `jj diff --git --from [FIX_BASE_CHANGE_ID] --to [FIX_HEAD_CHANGE_ID]`.

    Your review is read-only in this workspace. Do not mutate the working-copy
    revision, descriptions, bookmarks, workspace, or operation log in any way.

    ## Scope

    Your scope is the findings list and the fix diff. Verdict every finding.
    Inspect the fix diff for new problems the fix itself introduced. Do NOT
    re-review code the fix did not touch: if you notice an issue entirely
    outside the fix diff, report it under Out-of-Scope Observations — it
    does not block this task and does not extend the loop. A broad
    whole-stack review happens after all tasks are complete.

    ## Tests

    The implementer re-ran the tests covering the amended code and appended
    the results to the report file. Treat the report as unverified claims:
    confirm the fix report names the covering tests and shows their output,
    and verify the claims against the diff. Do not re-run the suite to
    confirm their report. Run a test only when reading the code raises a
    specific doubt that no existing run answers — and then a focused test,
    never a package-wide suite.

    ## Output Format

    Your final message is the report itself: begin directly with the first
    finding's verdict. Every line is a verdict, a finding with file:line,
    or a check you ran — no preamble, no process narration.

    ### Finding Verdicts

    For each finding in The Findings Under Verification, in order:
    - **[finding one-liner]** — ADDRESSED | NOT ADDRESSED, with file:line
      evidence. "Attempted" is not addressed: the specific defect must no
      longer exist.

    ### New Breakage in the Fix Diff

    Anything the fix itself broke or introduced, with severity
    (Critical/Important/Minor) and file:line. "None" if clean.

    ### Out-of-Scope Observations

    Issues you noticed entirely outside the fix diff. Non-blocking; the
    controller ledgers these for the final review. "None" if none.

    ### Verdict

    **Fix round:** [All findings addressed, no new Critical/Important
    breakage | Findings remain open] — list the open ones.

    If the fix changed a revision description, validate it against local
    repository conventions; local conventions win and no fixed syntax is
    prescribed.
    Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
```

**Placeholders:**
- `[MODEL]` — REQUIRED: reviewer model per SKILL.md Model Selection; scoped
  re-reviews of small fix diffs take a cheap-to-mid tier
- `[BRIEF_FILE]` — the task brief file (same file the implementer worked from)
- `[FINDINGS]` — the Critical/Important findings and spec gaps from the
  previous review, copied verbatim, one per bullet
- `[REPORT_FILE]` — the implementer's report file (fix reports appended)
- `[FIX_BASE_CHANGE_ID]` — stable change ID the previous review saw
- `[FIX_HEAD_CHANGE_ID]` — stable change ID of the completed fix revision
- `[DIFF_FILE]` — the path `scripts/review-package PLAN_FILE FIX_BASE_CHANGE_ID FIX_HEAD_CHANGE_ID` printed

**Re-reviewer returns:** per-finding verdicts (ADDRESSED / NOT ADDRESSED),
new breakage in the fix diff, out-of-scope observations, and a round verdict.
