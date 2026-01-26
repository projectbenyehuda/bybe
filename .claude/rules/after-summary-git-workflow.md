# CRITICAL: Git Workflow After Conversation Summaries

## The Problem

When continuing from a summarized conversation, the `gitStatus` section shows the state at the **START** of the previous session, **NOT** the current state. This can lead to using the wrong base branch for PRs.

## The Solution: MANDATORY First Step After Any Summary

**BEFORE doing ANY git operations after a summary (creating branches, committing, creating PRs):**

```bash
git branch --show-current
```

**Record this branch name. This is your base branch for PRs.**

## Why This Rule Exists

- Summaries show historical gitStatus from session start
- Work may have been done on different branches during the session
- The "Main branch" in summaries often refers to the repository's default (master), NOT your working branch
- Many projects use long-lived feature branches (like `lexicon`, `dragula`, etc.) as integration branches

## The Checklist (Use This EVERY Time After a Summary)

When continuing after a summary:

1. ✅ Run `git branch --show-current` FIRST
2. ✅ Write down/remember that branch name - it's your base branch
3. ✅ Create your feature branch (if needed)
4. ✅ When creating PR, use `--base <that-branch-you-wrote-down>`
5. ✅ **NEVER** assume `--base master` without checking

## Example of Correct Workflow

```bash
# 1. FIRST THING after summary - check where you are
$ git branch --show-current
lexicon

# 2. Record: base branch is "lexicon"

# 3. Create feature branch
$ git checkout -b feature/my-new-feature

# 4. Do work, commit, push...

# 5. Create PR with RECORDED base branch
$ gh pr create --base lexicon --title "..." --body "..."
                      ^^^^^^^ NOT master!
```

## Historical Context

This rule was created after PR #943 was incorrectly created with `--base master` instead of `--base lexicon`, nearly causing a merge to the wrong branch. The mistake happened despite existing git-workflow.md rules because the summary's gitStatus was not current and was misinterpreted.

## Integration with Existing Rules

This rule **supplements** git-workflow.md by being **specifically** about the summary continuation case. The existing rules say "check your branch first" - this rule says "ESPECIALLY after summaries, because the summary info is stale."
