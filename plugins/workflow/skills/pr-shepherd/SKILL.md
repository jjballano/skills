---
name: pr-shepherd
description: Stay with an open pull request (or a stack or batch of them) until it is merged — a small-model watcher runs a monitor that prints only events (new comment or review, failed check, conflict, base change, READY, merged), escalates what needs a decision, gets it fixed, re-arms itself when it expires, and cleans up after the merge. Use right after opening any PR, for "watch the PR", "stay on it until it's mergeable", "keep an eye on the stack", or /pr-shepherd.
compatibility: Claude Code with the GitHub CLI (gh) authenticated and jq installed. The monitor works best with a background monitor/shell tool.
---

# PR shepherd

Every PR opened as part of a task gets a shepherd from the moment it is opened until it is
merged or closed — without the user having to ask. Watching is a **small-model** job (Haiku
unless it is not enough): the watcher runs the monitor and escalates to the orchestrator only
when something needs a decision. The orchestrator decides who acts and with which model.

## Definitions

- **READY to merge** = every check passed (none failing, cancelled or pending) **and** the
  requested reviewers approved (`reviewDecision = APPROVED`). Green checks with no approval is
  not ready. A bot's "commented" review, resolved threads or a clean merge state do not count.
- **Merge** only with an explicit OK from the user (in chat, or an "OK"/"LGTM" comment or
  approval of theirs on the PR). Never enable auto-merge on your own.

## The monitor

Use the bundled read-only script [scripts/watch-prs.sh](scripts/watch-prs.sh). It prints one
tab-separated line per event and nothing else, so each line can wake the watcher:

```bash
scripts/watch-prs.sh [-R owner/repo] [-i 120] PR [PR...]
```

Events: `COMMENT`, `REVIEW`, `THREAD` (inline code comment), `CHECK_FAIL` (per check and head
sha), `CONFLICT`, `BASE`, `DRAFT`/`UNDRAFT`, `READY`, `MERGED`/`CLOSED`, `ERROR`. The first
poll takes existing comments as a baseline but reports current failures, conflicts and READY.
`--once` polls once and exits (handy to check the state by hand).

Run it under a monitor tool (or a background shell that notifies on output). No short polling
loops in the agent itself: 2 minutes between polls is plenty.

**Monitors and wake-ups expire.** Re-arm them before or right after they expire, without
asking. If you find a watcher whose monitor expired without re-arming, re-arm it on the spot
and just mention it in the next update.

## What each event triggers

| Event                                | Action                                                                                                       |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `COMMENT` / `REVIEW` / `THREAD`      | Read it. Apply the fix or answer it on the PR, one push per round. Comments from the repo owner go first.    |
| `CHECK_FAIL`                         | Read the failing log, fix the cause (not the test, unless the test is wrong), push.                          |
| `CONFLICT`                           | Rebase on the base branch, resolve, push with `--force-with-lease`.                                          |
| `BASE`                               | Expected after a parent PR in a stack merges; check the diff still shows only this PR's changes.             |
| `READY`                              | Tell the orchestrator/user it is ready. Keep watching: it can stop being ready.                             |
| `MERGED`                             | Clean up (below) and finish.                                                                                 |
| `CLOSED`                             | Report it and finish.                                                                                        |
| `ERROR`                              | Usually a network blip; it retries. Escalate only if it repeats for many polls.                              |

**Review comments live in three places** — general conversation comments, review bodies, and
inline code threads. Read all three; missing a general comment because only threads were
checked is the classic failure. Comments from the repo owner are top priority and are answered
on the PR itself.

If the repo has its own skill or script for handling automated reviewers (for example an AI
code reviewer bot), use it for those comments.

## Stacks and batches

For several PRs at once, run **one central monitor** owned by the orchestrator's watcher,
passing all the PR numbers. Subagents implement their piece and finish; they do not each keep a
monitor (theirs expire or only report "no changes"). Stacked series, cascade rebases and
merging a stack: [references/stacked-prs.md](references/stacked-prs.md).

## Stalled agents

Re-activate stalled agents without waiting for the user to notice or asking. Signals: a turn
that ended on a connection error, timeout or "overloaded" with the agent idle; a prompt you
sent that is still unsubmitted; an expired monitor. Tell the agent its last turn was cut with
that error and to resume exactly where it left off, then check it is active again.

## After the merge

- Make sure the worktree/branch that produced the PR has a clean status and nothing unpushed,
  stop its agent, and remove the worktree — without asking. If several PRs share a worktree
  (a stack made by one agent), remove it only when all of them are merged.
- Move the ticket on according to the team's flow (if the user has said where merged work
  goes, follow that).
