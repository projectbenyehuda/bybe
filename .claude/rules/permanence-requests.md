# How to Handle Permanence Requests

## CRITICAL: When Users Request Permanent Learning

When the user uses ANY of these phrases, **IMMEDIATELY create a rules file** in `.claude/rules/` without waiting to be asked:

### Explicit Triggers (always create rules file):
- "Add this to .claude/rules/"
- "Create a new Claude rule file for this"
- "Write this to a rules file"
- "Update CLAUDE.md with this rule"
- "Make this a **permanent part of the Claude rules**"
- "I want this **permanently memorized**"
- "Add this to the **project instructions**"
- "This should be in the **rules for future sessions**"
- "**permanent**" + "**Claude rules**" + "**from now on**"

### Intent-based Triggers (create rules file):
- Any phrase containing "permanent" + "rules"
- Any phrase containing "memorize" + "future"
- Any phrase containing "Claude rules" + "going forward"
- Any phrase about "learning" that should persist

### What NOT to Do:
- ❌ Say "I'll remember this" without creating a file
- ❌ Acknowledge the learning without making it persistent
- ❌ Wait for the user to ask "where is this stored?"
- ❌ Explain how memory works without FIRST creating the file

## The Correct Response Pattern:

1. **FIRST**: Create the rules file immediately
2. **SECOND**: Commit and push it
3. **THIRD**: Explain what you did

Example:
```
User: "Make this a permanent rule"
Assistant: [Creates .claude/rules/new-rule.md]
          [Commits it]
          "Done! I've created .claude/rules/new-rule.md to make this permanent."
```

## Meta-Rule:

**This rule itself demonstrates the principle**: When explaining how to handle permanence requests, that explanation MUST be written to a rules file, not just stated in conversation.

## Historical Context:

This rule was created after the user had to ask THREE times for permanence:
1. User: "memorize this learning... permanent part of the Claude rules from now on"
2. Assistant said "I'll remember" but didn't create a file
3. User: "where is this knowledge stored?"
4. Assistant created the file
5. User: "Have you recorded THAT in a rule?"
6. Assistant finally created THIS meta-rule

Don't repeat this mistake.
