#!/bin/bash
# Claude Code SessionStart hook for bybe project
# Outputs beads workflow + critical git branch/PR workflow

# Output standard beads workflow
bd prime

# Append critical git workflow reminders
cat << 'EOF'

# ⚠️⚠️⚠️ CRITICAL GIT WORKFLOW - READ BEFORE ANY GIT OPERATIONS ⚠️⚠️⚠️

## 🚨 UPDATED SESSION CLOSE PROTOCOL 🚨

**CRITICAL**: Before saying "done" or "complete", follow this COMPLETE checklist:

```
[ ] 0. Check current branch: git branch --show-current
       - If on master/main/lexicon_new or ANY pre-existing branch → CREATE FEATURE BRANCH!
       - ONLY proceed if you're on a branch YOU created in THIS session

[ ] 1. CREATE FEATURE BRANCH (if not already on one):
       git checkout -b feature/by-XXX-description  (for features)
       git checkout -b fix/by-XXX-description      (for bug fixes)

[ ] 2. git status              (check what changed)
[ ] 3. git add <files>         (stage code changes)
[ ] 4. bd sync                 (commit beads changes)
[ ] 5. git commit -m "..."     (commit code with proper message)
[ ] 6. bd sync                 (commit any new beads changes)
[ ] 7. git push -u origin <your-feature-branch>  (push YOUR branch, not master!)
[ ] 8. gh pr create --title "..." --body "..."   (create Pull Request)
[ ] 9. bd close <id> --reason "Created PR #XXX"  (close bead AFTER PR created)
[ ] 10. bd sync                (final sync)
```

## ⛔ THE MOST IMPORTANT RULE ⛔

**NEVER, EVER push directly to ANY branch that existed before this session.**

This means:
- ❌ **NEVER** `git push` when on master, main, lexicon_new, dragula, or ANY pre-existing branch
- ❌ **NEVER** commit to these branches even if you can
- ❌ **NEVER** assume you should push just because you can
- ✅ **ALWAYS** create a new feature/fix branch FIRST
- ✅ **ALWAYS** submit changes via Pull Request using `gh pr create`

**If you're about to run `git push` on an existing branch: STOP! Create a feature branch first!**

## Why This Rule Exists

Direct pushes bypass:
1. Code review via Pull Requests
2. CI checks before merging
3. The team's established workflow
4. Protection against merge conflicts

## Quick Check Before ANY Git Operation

Ask yourself:
1. Am I on a branch I created in THIS session? → Run: `git branch --show-current`
2. If NO → Have I created a feature/fix branch yet?
3. Am I about to push to my OWN branch, not master/main?
4. Will I create a PR after pushing?

**If any answer is NO, do NOT proceed!**

## Complete Example Workflow

```bash
# 1. Check current branch
git branch --show-current
# Output: lexicon_new (this is a pre-existing branch!)

# 2. Create feature branch
git checkout -b feature/by-6b7-collapse-buttons

# 3. Make changes, then commit
git add app/views/authors/toc.html.haml
bd sync
git commit -m "Implement collapse/expand buttons"
bd sync

# 4. Push YOUR branch
git push -u origin feature/by-6b7-collapse-buttons

# 5. Create PR
gh pr create --title "Implement collapse/expand all buttons" --body "..."

# 6. Close bead
bd close by-6b7 --reason "Created PR #123"
bd sync
```

## See AGENTS.md for Full Details

The complete workflow is documented in `/home/asaf/dev/bybe/AGENTS.md`
Read it if you need clarification on:
- Testing requirements
- Branch naming conventions
- PR creation guidelines
- Error recovery procedures

EOF
