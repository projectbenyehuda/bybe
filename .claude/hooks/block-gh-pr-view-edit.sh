#!/usr/bin/env bash
# PreToolUse/Bash hook: refuse `gh pr view` and `gh pr edit`, and hand back the `gh api`
# equivalent so the caller can re-issue the command correctly instead of guessing.
#
# Why: this repo has a classic GitHub Project attached, so `gh pr edit` queries the deprecated
# projectCards GraphQL field and fails. Project policy is that ALL PR reads and writes go
# through the REST API. See .claude/rules/gh-pr-via-api.md.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null)

# Match `gh pr view|edit` at the start of the command or after a shell separator, so that
# `git log --grep='gh pr view'` and similar incidental mentions are not blocked.
if ! printf '%s' "$cmd" |
  grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*gh[[:space:]]+pr[[:space:]]+(view|edit)([[:space:]]|$)'; then
  exit 0
fi

read -r -d '' reason <<'EOF' || true
`gh pr view` and `gh pr edit` are blocked in this repo -- go straight to `gh api`.

`gh pr edit` fails outright here (classic GitHub Project attached -> deprecated projectCards
GraphQL field), and the standing policy is that every PR read/write uses the REST API.

  PR metadata:    gh api repos/projectbenyehuda/bybe/pulls/<n>
  Review bodies:  gh api repos/projectbenyehuda/bybe/pulls/<n>/reviews
  Line comments:  gh api repos/projectbenyehuda/bybe/pulls/<n>/comments
  Issue comments: gh api repos/projectbenyehuda/bybe/issues/<n>/comments
  Files changed:  gh api repos/projectbenyehuda/bybe/pulls/<n>/files
  Edit title:     gh api repos/projectbenyehuda/bybe/pulls/<n> -X PATCH -f title='New title'
  Edit body:      gh api repos/projectbenyehuda/bybe/pulls/<n> -X PATCH -F body=@/tmp/body.md

Add --jq '...' to narrow the response. Use -F body=@file (not -f body="$(cat ...)") so
multi-line markdown survives intact.
EOF

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
