Read `prompts/analyst-common.md` first; it gives your role, inputs,
context-safety rules, and the return format. This file adds the dimension.

Dimension: Quality evidence

Judge the process against its own claims. This is not a code review; do
not evaluate the code the session produced.

1. Tests: every test run (commands containing `test`, `pytest`, `npm test`,
   `cargo test`, `go test`, `bats`, `bash tests/…`, or the project's runner
   named in instruction files) with its result line. Report runs that
   failed and what the assistant did next.
2. Verification behind claims: find assistant text claiming done, fixed,
   passing, verified, works, complete. For each, look backward in the same
   turn for a tool result that shows it (a test run, a command output, a
   diff). Report claims with no supporting result in that turn.
3. Changes: every `jj commit` or `jj describe` with its description. Based on
   https://go.dev/wiki/CommitMessage and on past commit messages that you can
   see in `jj log`, compose commit messages adherent to the present standards
   only when judging whether a recorded description matches the work —
   repository-local syntax from project instructions and `jj log` ALWAYS wins
   when it differs from Go guidance. Compare each description to the tool
   calls in the preceding turn(s). Report changes whose description claims
   work that no tool call performed, and work performed that was never
   recorded when the agreed plan said it would be.
4. Review feedback: where a reviewer (human or subagent) raised points,
   find the response. Report points acknowledged but not acted on, and
   points dismissed without a stated reason.
5. Acceptance criteria: if the case file's problem statement or the
   agreed plan states criteria, report each as met / not met /
   not checked with the evidence line.
