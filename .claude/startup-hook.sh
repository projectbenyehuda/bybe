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

EOF

# ═══════════════════════════════════════════════════════════════════════════
# 📋 MANDATORY: AGENTS.MD PROJECT REQUIREMENTS
# ═══════════════════════════════════════════════════════════════════════════
#
# ⚠️⚠️⚠️ YOU MUST READ THIS BEFORE STARTING ANY WORK ⚠️⚠️⚠️
#
# The following is the COMPLETE contents of AGENTS.md which contains
# MANDATORY requirements for this project. You are REQUIRED to read and
# follow ALL rules in this document.
#
# DO NOT skip reading this. DO NOT assume you know the rules.
# ALWAYS consult this file for project-specific requirements.
# ═══════════════════════════════════════════════════════════════════════════

cat "$(dirname "$0")/../../AGENTS.md"

cat << 'EOF2'

═══════════════════════════════════════════════════════════════════════════
END OF AGENTS.MD
═══════════════════════════════════════════════════════════════════════════

⚠️⚠️⚠️ CRITICAL REMINDERS FROM AGENTS.MD ⚠️⚠️⚠️

1. **NEVER use `sleep` in Capybara tests** - Use Capybara's automatic waiting
2. **ALWAYS create feature/fix branches** - NEVER push to existing branches
3. **ALWAYS write tests** for bug fixes and new features
4. **ALWAYS use HAML** for views, not ERB
5. **ALWAYS use I18n** for user-visible text (both he.yml and en.yml)
6. **ALWAYS include WebDriver check** in system specs with js: true

Before starting ANY work, confirm you have read and understood AGENTS.md above.

EOF2
