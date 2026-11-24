# Subagent brief template

The subagent knows only what the brief says. Fill every section; delete none. Keep the
"Rules" block verbatim — it is how the method reaches every agent.

```markdown
## Goal
<one or two sentences: what done looks like>

## Context
- Ticket / request: <key or summary, acceptance criteria by id>
- Repo, branch to start from, worktree: <...>
- Files and docs worth reading first: <paths>
- Decisions already taken (do not reopen): <...>
- Already ruled out: <...>

## Scope
- In: <...>
- Out (do not touch): <...>

## Rules
- Questions go to the orchestrator, never to the user. Blocking doubt: stop and ask.
  Non-blocking doubt: take the reasonable option, tell the orchestrator right away, keep going.
- Verify only what you touched: the tests you wrote or changed, the test files of the touched
  modules, and one or two more only if clearly affected. Lint/format/types on touched files
  only. Never full suites or repo-wide checks; CI covers the rest.
- Add tests for new logic. Never weaken auth/security code to make a test pass.
- Minimal diff: no renames, reordering or cleanups outside the task.
- Comments describe current behaviour; no "moved from X".
- <If it opens a PR:> follow the repo's commit/PR conventions; do not request a human reviewer
  unless the orchestrator says so. Then stay with the PR until it is mergeable (see the
  pr-shepherd skill): review comments (including general comments, reviews and code threads
  from the repo owner — those first), red CI, conflicts, pending checks. Report READY only with
  all checks green AND an approval. Keep waiting without short polling until it is merged,
  then finish.

## Report
- What changed (files), what was verified and how (real command output), what is left.
- Any assumption you made on a non-blocking doubt.
- Start the report with a ⚠️ line if any tool you were told to use was unavailable.
```
