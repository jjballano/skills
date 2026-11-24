# skills

My Claude skills: how I hand work to Claude and how I want it to run that work.

The repo is a Claude Code plugin *marketplace*, so it installs with one command and can update
itself. For now it holds one plugin:

| Plugin                                         | Skills                                                                                                                         |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| [`orchestrated-dev`](plugins/orchestrated-dev) | `task-workflow` (how a task is run once handed over), `pr-shepherd` (watch the PR until it can be merged), `status-report` (piece-by-piece status update) |

## Install

```
/plugin marketplace add jjballano/skills
/plugin install orchestrated-dev@jjballano-skills
```

To keep it up to date: `/plugin` → *Marketplaces* → `jjballano-skills` → *Enable auto-update*.

Skills trigger on their own from their description, or by hand: `/orchestrated-dev:task-workflow`,
`/orchestrated-dev:pr-shepherd`, `/orchestrated-dev:status-report`.

## What each skill does

- **task-workflow**: the main thread orchestrates and stays free; the work is split into
  background subagents on the smallest model that does each piece well; their questions go to
  the orchestrator, not to the user; the orchestrator validates every result; only what changed
  is verified; minimal diffs; every PR ships with its watcher.
- **pr-shepherd**: a small-model agent runs a monitor that only emits events (new comment or
  review, failed check, conflict, base change, READY, merged), re-arms it when it expires, gets
  whatever is needed fixed, and cleans up the worktree after the merge. Ships
  `scripts/watch-prs.sh` and the recipe for stacked PRs and cascade rebases.
- **status-report**: piece-by-piece status refreshed live, what comes next, and always a
  "what I need from you" section.

## Adding or changing a skill

1. A skill lives in `plugins/<plugin>/skills/<skill>/SKILL.md`, in English, with its supporting
   files inside its own folder (`references/`, `scripts/`, `assets/`). No paths to a specific
   machine or to other repos: it must be self-contained.
2. Bump the `version` in `plugins/<plugin>/.claude-plugin/plugin.json` on every change, or
   auto-update will not pick it up.
3. Check locally:

   ```bash
   python3 scripts/validate_skills.py
   claude plugin validate . --strict
   claude --plugin-dir plugins/orchestrated-dev     # session with the plugin loaded
   ```

Frontmatter uses only the keys claude.ai also accepts (`name`, `description`, `license`,
`compatibility`, `metadata`, `allowed-tools`), so the skills can be uploaded there too.

## License

[MIT](LICENSE)
