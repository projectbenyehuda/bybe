#!/usr/bin/env python3
"""PreToolUse/Bash hook: refuse `gh pr view` and `gh pr edit`.

Hands back the `gh api` equivalent so the caller can re-issue the command correctly
instead of guessing.

Why: this repo has a classic GitHub Project attached, so `gh pr edit` queries the
deprecated projectCards GraphQL field and fails. Project policy is that ALL PR reads
and writes go through the REST API. See .claude/rules/gh-pr-via-api.md.

Only a real invocation is blocked. Heredoc bodies and quoted strings are stripped
first, so writing *about* these commands -- in a commit message, a PR body, a grep
pattern, a rules file -- is not blocked.
"""

import json
import re
import sys

REASON = """`gh pr view` and `gh pr edit` are blocked in this repo -- go straight to `gh api`.

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
multi-line markdown survives intact."""

HEREDOC_OPEN = re.compile(r"""<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1""")
# A blocked call: `gh` as the first word of a command segment, then `pr`, then view/edit.
BLOCKED = re.compile(r"^\s*gh\s+pr\s+(view|edit)(\s|$)")
SEGMENT_SEPARATORS = re.compile(r"&&|\|\||[;|&()\n]")


def strip_heredocs(command: str) -> str:
    """Drop heredoc bodies, keeping the line that opens them."""
    kept, skip_until = [], None
    for line in command.split("\n"):
        if skip_until is not None:
            if line.strip() == skip_until:
                skip_until = None
            continue
        kept.append(line)
        opener = HEREDOC_OPEN.search(line)
        if opener:
            skip_until = opener.group(2)
    return "\n".join(kept)


def strip_quoted(text: str) -> str:
    """Blank out single-quoted, double-quoted, and backticked spans."""
    out, quote = [], None
    for ch in text:
        if quote:
            if ch == quote:
                quote = None
            out.append(" ")
            continue
        if ch in "'\"`":
            quote = ch
            out.append(" ")
            continue
        out.append(ch)
    return "".join(out)


def main() -> int:
    try:
        command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    except (json.JSONDecodeError, AttributeError):
        return 0

    cleaned = strip_quoted(strip_heredocs(command))
    if not any(BLOCKED.match(seg) for seg in SEGMENT_SEPARATORS.split(cleaned)):
        return 0

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": REASON,
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
