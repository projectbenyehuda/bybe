# All PR Reads and Writes Go Through `gh api`

## The rule

**Never run `gh pr view` or `gh pr edit` on this repo. Go straight to `gh api`.**

Both are blocked at the permission layer (`.claude/settings.json` `permissions.deny`) and by a
PreToolUse hook (`.claude/hooks/block-gh-pr-view-edit.sh`) that refuses the call and prints the
`gh api` equivalent. Attempting them wastes a turn — there is no fallback path where they work.

## Why

- **`gh pr edit` fails outright.** This repo has a classic GitHub Project attached. `gh pr edit`
  queries the deprecated `projectCards` GraphQL field, so GitHub returns a deprecation error and
  the command exits 1.
- **`gh pr view` is policy.** Even where it succeeds, the standing instruction is that every PR
  read goes through the REST API, so there is one predictable, `--jq`-filterable path.

Still fine to use: `gh pr create`, `gh pr list`, `gh pr comment`, `gh pr close`, `gh pr checks`,
`gh pr diff`. Only `view` and `edit` are blocked.

## The recipes

```bash
# Read
gh api repos/projectbenyehuda/bybe/pulls/<n>                       # PR metadata
gh api repos/projectbenyehuda/bybe/pulls/<n>/reviews               # review BODIES
gh api repos/projectbenyehuda/bybe/pulls/<n>/comments              # line comments
gh api repos/projectbenyehuda/bybe/issues/<n>/comments             # conversation comments
gh api repos/projectbenyehuda/bybe/pulls/<n>/files                 # files changed

# Write
gh api repos/projectbenyehuda/bybe/pulls/<n> -X PATCH -f title='New title'
gh api repos/projectbenyehuda/bybe/pulls/<n> -X PATCH -F body=@/tmp/body.md
```

Narrow responses with `--jq` rather than piping whole payloads through `head`:

```bash
gh api repos/projectbenyehuda/bybe/pulls/<n>/reviews --jq '.[] | {author: .user.login, state, body}'
```

**Use `-F body=@file`, not `-f body="$(cat ...)"`** — the `@file` form preserves multi-line
markdown intact. Verified working 2026-08-22 on PRs #1581 and #1589.

## Fetching a code review: you need BOTH endpoints

`/pulls/<n>/comments` returns only per-line comments. The substantive review text — a bot's summary
and recommendations — lives in the review **body** on `/pulls/<n>/reviews`. Fetch both, or you will
miss the actual review. See the "Addressing PR code review comments" section of CLAUDE.md.

## Historical context

Added 2026-08-22. The user had already asked more than once to always use `gh api`, but the block
kept getting bypassed because `CLAUDE.md` itself prescribed `gh pr view <number> --json
reviews,comments` in its review-handling section, and `.claude/settings.local.json` explicitly
allowlisted `Bash(gh pr view:*)` and `Bash(gh pr edit:*)`. Instructions alone were not enough —
the allowlist entries were removed, deny rules and a blocking hook were added, and the CLAUDE.md
recipe was rewritten to `gh api`.
