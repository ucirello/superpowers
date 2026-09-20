# GitHub issues

Use `gh` when it is installed and authenticated; it handles auth, rate
limits, and JSON. Fall back to the public API with curl, then to a URL
your partner opens.

Resolve the upstream issues repo from the environment, plugin config, or
your human partner before searching or filing. Do not hardcode a repo
slug.

## Search

```bash
gh search issues --repo <upstream-issues-repo> --limit 10 "<terms>" \
  --json number,state,title --jq '.[] | "\(.number)\t\(.state)\t\(.title)"'
```

Without `gh` (unauthenticated, 10 requests a minute):

```bash
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/search/issues?q=repo:<upstream-issues-repo>+is:issue+<url-encoded terms>&per_page=10" \
  | jq -r '.items[] | "\(.number)\t\(.state)\t\(.title)"'
```

Without curl, hand over the upstream project's issues search URL with the
query terms your partner approved.

## File

Write the filled `templates/issue.md` to the workspace and show the exact
text. After approval:

```bash
gh issue create --repo <upstream-issues-repo> --title "<title>" --body-file <path> \
  --label bug --label automated-issue-report
```

GitHub drops labels silently when the reporter lacks push access, so the
labels land only for collaborators; the template footer still marks the
issue as skill-filed. `gh` cannot attach files: give your partner the
bundle path to attach through the browser after the issue exists.

Without `gh`, hand over a prefilled new-issue link on the upstream
project's issues page using the `diagnosis_report.md` template (when the
repo provides it), which applies both labels for any reporter. Encode the
title and body in the URL query; if the repo has no such template, open a
blank new-issue form with the title only.

GitHub rejects URLs over about 8,000 characters; past that, send the link
with the title only and tell your partner to paste the body from the file.
