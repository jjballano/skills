# Choosing the model for a subagent

Rule: **the smallest and fastest model that does the piece well.** Pass `model` explicitly on
every launch, including search/explore agents (they may otherwise inherit a large model).

## Starting point by kind of work

| Piece of work                                                                                   | Model                                        |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Search, read logs or test output, summarise, classify, extract, watch (PRs, CI)                  | **Haiku** (Sonnet if it must understand code) |
| Bug fix or feature against a clear spec, repeated tasks (review, research, writing)             | **Sonnet**                                   |
| Docs, slides, spreadsheets                                                                       | **Sonnet** (Opus with lots of source material) |
| Migrations, performance work, hard debugging, multi-PR features, vision / computer use           | **Opus** — "clear spec" does not mean "easy" |
| Major refactor, architecture, deep research, leading many subagents, long unattended runs        | The most capable model available             |
| In doubt                                                                                         | Opus                                         |

## Criteria

- **Small models only where a mistake is cheap to detect** (a test, a diff, or a glance
  catches it). Code edits that need judgement → Sonnet/Opus. Small models do worse in long
  agentic loops: a long task with many turns is not for Haiku even if it is mechanical.
- **Price per task, not per token.** A bigger model sometimes finishes sooner with fewer tokens.
- **Expensive context is for deciding.** Verbose work (big files, logs, outputs) goes to cheap
  subagents that return the conclusion. That is why the main thread orchestrates.
- **Cheap first when the result checks itself:** launch at a low level and relaunch only the
  failures higher.
- **A simple rule belongs in code**, not in a model.

## Effort

- `medium` is the default and the sweet spot. Below it quality drops noticeably; above `high`,
  one more level costs about as much as a bigger model — try the bigger model first.
- Tasks that call for it from the start (multi-PR features, refactors, migrations): `medium`,
  then `high`. Classification/routing on Haiku: `medium`.

## Escalation when a piece comes back wrong

1. Let the agent verify itself (test, build, script against the endpoint) — usually cheapest.
2. Same model, one effort level higher.
3. Next model up, starting at a lower effort than the small model used.

More effort does not give a model knowledge it lacks.

## Constant checks and waiting

Watching PRs, CI or any monitor is always a small-model job. The watcher escalates to the
orchestrator only when something needs a decision; the orchestrator decides who acts and with
which model.
