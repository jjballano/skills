# Stacked PRs

When work is split into PRs that build on each other (each branch on top of the previous one),
setting the bases is not enough: register them as a **native GitHub stack** so the reviewer
gets the stack navigation instead of a pile of loose PRs.

## Creating the stack

With the `gh stack` extension, from branches already committed in order (bottom → top):

```bash
gh stack init --base main <branch1> <branch2> ...   # adopts the branches, chains the bases
gh stack submit --auto --open                        # pushes and creates the PRs
```

- `--auto` is required in a non-interactive session (without it an editor opens).
- `--open` creates them ready for review instead of draft.
- `--auto` writes generated titles and bodies: overwrite each with
  `gh pr edit <n> --title ... --body-file ...` and **check the titles afterwards** (an edit
  does not always stick the first time).

For PRs that already exist: `gh stack link <pr1> <pr2> ...` (bottom → top), or the API:
`POST /repos/{owner}/{repo}/stacks` with `{"pull_requests": [n1, n2]}` (integers, not
strings; send it with `gh api --input`). To extend a stack: `gh stack link <stack> <new-pr>`.

A PR inside a native stack does not let you change its base: unstack it and recreate the stack.

## Cascade rebases

When a parent changes (new commits, or it merged), the children must be rebased in order. Do
it in an explicit `bash -euo pipefail` script — the interactive shell may be zsh, where arrays
start at 1 and `cmd | tail || ...` hides a failed rebase.

```bash
bash -euo pipefail <<'EOF'
# Explicit SHAs, never array indexes.
OLD_PARENT=<old tip of the parent branch>
NEW_PARENT=<new tip of the parent branch, or origin/main if it merged>
CHILD=<child branch>
OLD_CHILD=$(git rev-parse "$CHILD")

git rebase --onto "$NEW_PARENT" "$OLD_PARENT" "$CHILD"
NEW_CHILD=$(git rev-parse "$CHILD")

# Never push to a branch a tip that contains its own child's tip: GitHub would mark
# the PR as merged and delete the branch.
git push --force-with-lease="$CHILD:$OLD_CHILD" origin "$CHILD"
EOF
```

Repeat per level, bottom → top, one push per branch, with the lease pinned to the old SHA.
Before each push, check the new SHA is not equal to or an ancestor of the next branch's tip.

**Why so careful:** pushing a child's tip to the parent's branch makes GitHub consider the
parent PR merged (its head is contained in the base), delete its branch and move the child's
base to main. A merged PR cannot be reopened: the branch has to be restored, the child
recreated as a new PR and the stack rebuilt.

## Merging a stack

- Only with the user's OK, bottom first.
- After each merge, the monitor reports `BASE` on the next PR; check its diff still shows only
  its own changes and that checks re-run green before reporting READY.
