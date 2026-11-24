---
name: task-workflow
description: The operating mode for any task the user hands over (a ticket, a feature, a bug, an analysis) — the main thread orchestrates and stays free, the work is split into small self-contained pieces run by background subagents on the smallest model that does them well, every result is validated before it is reported, verification covers only what changed, and every PR is shepherded until mergeable. Use at the start of any implementation or multi-step task, for "implement this", "resolve this ticket", "do it the usual way", or /task-workflow.
---

# Task workflow

How to run a task the user hands over. The main thread is the **orchestrator**: it decides,
splits, answers questions, validates and reports. Subagents do the work. The goal is that the
user can keep asking for other things while this one runs, and that the expensive model's
context is spent on decisions, not on reading logs.

Companion skills in this plugin: `pr-shepherd` (watching PRs until mergeable, stacks) and
`status-report` (the piece-by-piece update).

## 1. Understand before touching anything

1. Read the whole request: description, acceptance criteria, comments. If it is a subtask,
   read its parent first: the business rules usually live there.
2. Read the real state of the code and of its dependencies, not just the ticket.
3. If the project has its own instructions (`AGENTS.md`, `CLAUDE.md`, rules, docs), they win
   over this skill wherever they are more specific.
4. For studies, analyses or definitions (not concrete fixes), first look for earlier work on
   the same topic (docs in the repo, previous artifacts or reports). If something covers it,
   say so and build on it instead of redoing it.

**When to stop and ask:** vague acceptance criteria, an unclear technical decision, "and other
improvements" with nothing specified, or a choice between significant approaches (present the
options with a recommendation). Otherwise, if the task follows a pattern the user has already
approved ("as we usually do"), give a one-line summary of what you are launching and launch —
do not ask for approval of the plan each time.

### Asking the user

- If there are several open questions, list them all at a glance, then ask **one per turn**.
  Skip any the user already answered along the way.
- "Let's go point by point" means: for each point, present all its items at once, each with
  your proposal, and let the user say what to do with them — not item by item, and not
  executing the point without asking.
- A question from the user about a solution already decided is for understanding it, not for
  reopening it: answer short and clear, without proposing alternatives.
- If the user asks for something you already do by default (because it is in this skill or in
  memory), do it and say in one line that it is already part of the method.

## 2. Split and delegate

- Split the work into pieces. **Independent pieces run in parallel**, each in a background
  subagent. Tightly coupled pieces (same file, same design decision) go to one agent, or to
  several coordinated by you.
- A chain of dependent steps, or work that fits in one context, goes to **one** agent: do not
  orchestrate for the sake of it.
- Trivial things (no tools, or one or two calls) you do yourself when launching an agent would
  cost more than doing it.
- After launching, reply in one line saying what was launched and with which model.
- Pick the **smallest model that does the piece well** and pass `model` explicitly on every
  launch (and `effort` when it helps). Table, escalation order and effort guidance:
  [references/model-choice.md](references/model-choice.md).
- Every brief is self-contained: the agent knows only what you write. Use the template in
  [references/subagent-brief.md](references/subagent-brief.md) — it carries the rules every
  agent must follow (questions go to you, verification scope, PR shepherding).
- A series of dependent pieces that each end in a PR runs **in sequence**, each branch on top
  of the previous one, registered as a stacked PR series (see `pr-shepherd`).
- If the task would fit an agent team better (parallel review with independent lenses, rival
  debugging hypotheses, layered work with one owner each), say it in one line and let the user
  decide — it costs several times the tokens. Do not mention it for sequential or small work.

## 3. Questions from subagents come to you

Subagents never ask the user directly. You answer from what you know (conversation, memory,
repo) and only escalate to the user what truly needs their input.

- **Blocking doubt** → the agent stops and asks you.
- **Non-blocking doubt** → the agent takes the reasonable option, tells you at that moment (not
  only in the final report) and keeps going. You review it and tell it to change course if
  needed.

## 4. Validate every result before reporting it

Never relay a subagent's report without checking it. Proportional to risk: the diff and the
real test output in normal work; an independent check for delicate areas (auth, security,
migrations, billing/credits, public API contracts).

If a piece comes back wrong, relaunch it with what failed in the brief — never the same brief.
Escalate in this order:

1. Make it able to verify itself (a test, a build, a script against the endpoint).
2. Same model, one `effort` level higher.
3. Next model up, starting at a lower effort than the small one was using.

## 5. Verify only what changed

- Never full test suites nor repo-wide lint/type/check runs: only the tests written or
  modified, the test files of the touched modules, and one or two more if the change clearly
  affects them. Lint, format and type checks only on the touched files. CI validates the rest;
  the goal is to get the PR up quickly. Cancel full suites already running.
- Add tests for every new piece of logic by default, without asking. Skip only genuinely
  trivial changes (renames, types, comments) and say so.
- Never weaken auth or security middleware to make a test pass: fix the test setup instead.

## 6. Code style the user expects in diffs

- **Minimal diff.** If the task asks to mark or show something, add the flag and consume it;
  do not widen the data set, rename, reorder or deduplicate in passing. The review happens on
  the diff, and cosmetic churn hides what really changed.
- **No opaque indirection.** Typed injected dependencies; compose with plain typed methods, not
  by re-entering another component's transport contract. One navigable hop beats a generic
  layer.
- **Comments describe current behaviour** (why, traps, contracts). Never "moved from X" or a
  ticket number instead of an explanation — history lives in git.
- Docs that describe the changed behaviour are updated in the same PR. Temporary changes are
  marked as such in the code and do not touch docs.
- No time estimates in plans, docs or tickets (sprints, weeks, dates). Express order by
  dependencies and relative difficulty.

## 7. PR and after

- Commit and open the PR following the repo's conventions. Before asking for human review,
  judge whether the change is simple or complex/core (auth, billing, middleware, data
  migrations, API contracts, pieces many consumers depend on). Simple → do not ask. Complex →
  ask the user once whether they want a human reviewer. Never add a reviewer or review label by
  default.
- A ticket moves to "In Review" only when its PR is ready for review, never while it is a draft.
- In the same turn the PR is opened, start its shepherd (see `pr-shepherd`): a small-model
  watcher that stays with the PR until it is merged or closed.
- When a PR is merged, clean up the worktree that produced it (clean status, nothing unpushed),
  without asking.
- Commands to tear down temporary resources are given only when it is time, or marked clearly
  as **"do NOT run yet — only when X"**.

## 8. Reporting

Short and factual. When the user asks how things are going, use `status-report`. Always close
with what you need from them, or say explicitly that nothing is needed.
