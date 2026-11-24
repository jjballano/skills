#!/usr/bin/env bash
# Watch one or more pull requests and print a line ONLY when something needs attention.
# Meant to run under a monitor (Claude Code's Monitor tool, or a background shell) so each
# printed line becomes an event for the watcher agent.
#
# Usage: watch-prs.sh [-R owner/repo] [-i seconds] [--once] PR [PR...]
#   -R       repository (default: the current directory's repo, as gh resolves it)
#   -i       seconds between polls (default 120)
#   --once   poll once and exit
#
# The first poll takes existing comments, reviews and threads as a baseline (not reported) but
# does report current failures, conflicts and READY.
#
# Events (one per line, tab-separated: EVENT  PR  detail):
#   COMMENT        new general (conversation) comment          detail: author
#   REVIEW         new review                                   detail: author state
#   THREAD         new inline code comment                      detail: author path
#   CHECK_FAIL     a check failed or was cancelled on the head  detail: check name @sha
#   CONFLICT       the PR cannot be merged cleanly
#   BASE           base branch changed                          detail: old -> new
#   DRAFT|UNDRAFT  draft status changed
#   READY          all checks passed AND review decision is APPROVED
#   MERGED|CLOSED  terminal state; the PR stops being watched
#   ERROR          gh failed for this PR (network, auth); retried next poll
#
# Requires: gh (authenticated) and jq. Read-only: it never writes to GitHub.
set -euo pipefail

repo_args=()
interval=120
once=0
prs=()
while (($#)); do
  case "$1" in
    -R) repo_args=(-R "$2"); shift 2 ;;
    -i) interval="$2"; shift 2 ;;
    --once) once=1; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) prs+=("$1"); shift ;;
  esac
done
((${#prs[@]})) || { echo "usage: watch-prs.sh [-R owner/repo] [-i seconds] [--once] PR [PR...]" >&2; exit 2; }

if ((${#repo_args[@]})); then
  repo="${repo_args[1]}"
else
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

state_dir="$(mktemp -d "${TMPDIR:-/tmp}/watch-prs.XXXXXX")"
trap 'rm -rf "$state_dir"' EXIT

emit() { printf '%s\t#%s\t%s\n' "$1" "$2" "${3:-}"; }

# Prints the lines of $2 that are not in file $1, then stores $2 in $1.
new_lines() {
  local file="$1" current="$2"
  if [[ -f "$file" ]]; then
    comm -13 <(sort "$file") <(printf '%s\n' "$current" | sed '/^$/d' | sort)
  fi
  printf '%s\n' "$current" | sed '/^$/d' >"$file"
}

poll_pr() {
  local pr="$1" dir="$state_dir/$1" json
  mkdir -p "$dir"
  # GitHub's GraphQL API fails now and then on PRs with many checks or comments: retry once.
  local fields=state,isDraft,mergeable,baseRefName,headRefOid,reviewDecision,statusCheckRollup,comments,reviews
  if ! json="$(gh pr view "$pr" -R "$repo" --json "$fields" 2>"$dir/err")"; then
    sleep 5
    if ! json="$(gh pr view "$pr" -R "$repo" --json "$fields" 2>"$dir/err")"; then
      emit ERROR "$pr" "$(head -n 1 "$dir/err")"
      return 0
    fi
  fi

  local state draft mergeable base head decision
  state="$(jq -r .state <<<"$json")"
  draft="$(jq -r .isDraft <<<"$json")"
  mergeable="$(jq -r .mergeable <<<"$json")"
  base="$(jq -r .baseRefName <<<"$json")"
  head="$(jq -r .headRefOid <<<"$json")"
  decision="$(jq -r '.reviewDecision // ""' <<<"$json")"

  if [[ "$state" == MERGED || "$state" == CLOSED ]]; then
    emit "$state" "$pr"
    touch "$dir/done"
    return 0
  fi

  # Comments, reviews and inline threads: report only ids not seen before.
  local line
  while IFS=$'\t' read -r _ author; do
    if [[ -n "${author:-}" ]]; then emit COMMENT "$pr" "$author"; fi
  done < <(new_lines "$dir/comments" "$(jq -r '.comments[] | [.id, .author.login] | @tsv' <<<"$json")")

  while IFS=$'\t' read -r _ author rstate; do
    if [[ -n "${author:-}" ]]; then emit REVIEW "$pr" "$author $rstate"; fi
  done < <(new_lines "$dir/reviews" "$(jq -r '.reviews[] | [.id, .author.login, .state] | @tsv' <<<"$json")")

  local threads
  if threads="$(gh api --paginate "repos/$repo/pulls/$pr/comments" --jq '.[] | [.id, .user.login, .path] | @tsv' 2>/dev/null)"; then
    while IFS=$'\t' read -r _ author path; do
      if [[ -n "${author:-}" ]]; then emit THREAD "$pr" "$author $path"; fi
    done < <(new_lines "$dir/threads" "$threads")
  fi

  # Failed or cancelled checks on the current head, once per (check, sha). Unlike comments,
  # failures already present on the first poll are reported too.
  [[ -f "$dir/fails" ]] || : >"$dir/fails"
  local fails
  fails="$(jq -r --arg sha "${head:0:7}" '
    .statusCheckRollup[]
    | select((.conclusion // .state // "") | test("FAILURE|CANCELLED|TIMED_OUT|ERROR|ACTION_REQUIRED|STARTUP_FAILURE"))
    | "\(.name // .context) @\($sha)"' <<<"$json")"
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then emit CHECK_FAIL "$pr" "$line"; fi
  done < <(new_lines "$dir/fails" "$fails")

  # Single-value transitions.
  local prev
  prev="$(cat "$dir/base" 2>/dev/null || true)"
  if [[ -n "$prev" && "$prev" != "$base" ]]; then emit BASE "$pr" "$prev -> $base"; fi
  echo "$base" >"$dir/base"

  prev="$(cat "$dir/draft" 2>/dev/null || true)"
  if [[ -n "$prev" && "$prev" != "$draft" ]]; then
    if [[ "$draft" == true ]]; then emit DRAFT "$pr"; else emit UNDRAFT "$pr"; fi
  fi
  echo "$draft" >"$dir/draft"

  prev="$(cat "$dir/conflict" 2>/dev/null || true)"
  if [[ "$mergeable" == CONFLICTING ]]; then
    if [[ "$prev" != yes ]]; then emit CONFLICT "$pr"; fi
    echo yes >"$dir/conflict"
  else
    echo no >"$dir/conflict"
  fi

  # READY = every check finished OK AND approved. Reported once per head sha.
  local checks_ok
  checks_ok="$(jq -r '
    [.statusCheckRollup[] | (.conclusion // .state // "")] as $c
    | ($c | length) > 0 and all($c[]; test("^(SUCCESS|NEUTRAL|SKIPPED)$"))' <<<"$json")"
  prev="$(cat "$dir/ready" 2>/dev/null || true)"
  if [[ "$checks_ok" == true && "$decision" == APPROVED && "$draft" == false ]]; then
    if [[ "$prev" != "$head" ]]; then emit READY "$pr" "${head:0:7}"; fi
    echo "$head" >"$dir/ready"
  else
    : >"$dir/ready"
  fi
}

while :; do
  remaining=0
  for pr in "${prs[@]}"; do
    [[ -f "$state_dir/$pr/done" ]] && continue
    poll_pr "$pr"
    [[ -f "$state_dir/$pr/done" ]] || remaining=$((remaining + 1))
  done
  ((once)) && exit 0
  ((remaining)) || exit 0
  sleep "$interval"
done
