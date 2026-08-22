#!/usr/bin/env python3
"""Regression tests for the block-gh-pr-view-edit PreToolUse hook.

Run from the project root:  python3 .claude/hooks/block-gh-pr-view-edit_test.py

The heredoc case is the reason this file exists: the first version of the hook matched
`gh pr view` anywhere after a shell separator, so a markdown table row inside a heredoc
(`| `gh pr view 1589` | denied |`) blocked an unrelated `gh pr create`.
"""

import json
import subprocess
import sys

HOOK = ".claude/hooks/block-gh-pr-view-edit.sh"

HEREDOC = """cat > /tmp/body.md <<'EOF'
| `gh pr view 1589 --json reviews` | denied |
gh pr view 1589
- deny rules for Bash(gh pr view:*) and Bash(gh pr edit:*)
EOF
gh pr create --base master --body-file /tmp/body.md"""

CASES = [
    ("gh pr view 1589 --json state", "deny"),
    ("gh pr edit 1589 --body x", "deny"),
    ("git push && gh pr edit 1589 --body x", "deny"),
    ("git push; gh pr view 1589", "deny"),
    ("  gh   pr   view  1589", "deny"),
    ("gh api repos/projectbenyehuda/bybe/pulls/1589", "allow"),
    ("gh pr create --base master", "allow"),
    ("gh pr list", "allow"),
    ("gh pr diff 1589", "allow"),
    ("git log --grep='gh pr view'", "allow"),
    ("grep -rn 'gh pr edit' CLAUDE.md", "allow"),
    ('git commit -m "stop using gh pr view here"', "allow"),
    (HEREDOC, "allow"),
]


def main() -> int:
    failures = 0
    for command, expected in CASES:
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
        result = subprocess.run([HOOK], input=payload, capture_output=True, text=True)
        actual = "deny" if result.stdout.strip() else "allow"
        if actual != expected:
            failures += 1
            print(f"FAIL want={expected} got={actual}: {command!r}")

    print(f"{len(CASES) - failures}/{len(CASES)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
