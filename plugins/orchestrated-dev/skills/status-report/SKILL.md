---
name: status-report
description: Piece-by-piece status update of the task in progress — PRs and their review/CI state, tickets, running agents and what each is doing, what is next — always closing with an explicit "What I need from you" section. Use when the user asks how things are going in any form ("status", "update", "where are we", "how's it going", "minuto y resultado"), or /status-report.
---

# Status report

The user asks for an update in many ways ("status?", "where are we?", "minuto y resultado").
It is never a literal question about time: it means the state of the task in progress.

## How

1. **Refresh the real state first.** Do not answer from what you saw earlier in the session —
   the user moves tickets and merges PRs in parallel. Query the PRs (`gh pr view <n> --json
   state,reviewDecision,statusCheckRollup,mergeable`), the tickets, and the agents/monitors.
2. Answer with a compact table or list, **one row per piece**: PR (number, state, CI, reviews,
   mergeable or not, what blocks it), ticket and status, agent running and what it is doing.
3. **Next:** what happens next, in order.
4. **What I need from you:** unanswered questions, pending decisions, confirmations (pre-PR
   checks, merges), secrets or access, manual actions (test something, approve, merge), or
   anything blocked on the user. If there is nothing, say so explicitly ("nothing on your side").

Rules:

- No narrating the process, no history of how you got here.
- If a monitor or agent had stalled and you re-armed it, say so in one line.
- If any tool the method relies on was unavailable, put it first with a ⚠️.
- If there are several things needed from the user, list them all, but expect to resolve them
  one per turn.
