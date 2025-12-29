# Git Workflow - READ THIS FIRST

## THE MOST IMPORTANT RULE

**NEVER, EVER push directly to ANY existing branch that you did not create in the current session.**

This means:
- ❌ **NEVER** `git push` when on master, main, dragula, or any pre-existing branch
- ❌ **NEVER** commit directly to master/main even if you can bypass protection rules
- ❌ **NEVER** assume that being able to push means you should push
- ✅ **ALWAYS** create a new feature/fix branch BEFORE making any commits
- ✅ **ALWAYS** submit changes via Pull Request using `gh pr create`

**If you find yourself about to run `git push` on master/main, STOP! You're doing it wrong.**

## Why This Rule Exists

Even if the repository allows direct pushes to master (bypassing protection rules), you must NOT do it because:
1. All code changes must be reviewed via Pull Requests
2. CI checks must run before merging
3. Direct pushes circumvent the team's workflow
4. It creates merge conflicts and workflow confusion

## If You Made a Mistake

If you accidentally pushed to master/main:
1. Immediately revert: `git revert HEAD`
2. Push the revert: `git push`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Cherry-pick your work: `git cherry-pick <commit-hash>`
5. Push the branch: `git push -u origin feature/your-feature`
6. Create a PR: `gh pr create --title "..." --body "..."`

## Complete Git Workflow - Follow Every Time

**ALWAYS follow this workflow for EVERY piece of work:**

1. **FIRST: Check which branch you're on**
   ```bash
   git branch --show-current
   ```
   - If you're on `master`, `main`, or any pre-existing branch, DO NOT commit or push!
   - You MUST create a new branch first (see step 2)

2. **Create a new feature/bug branch** from your current branch:
   ```bash
   git checkout -b fix/issue-description  # for bugs
   git checkout -b feature/feature-name   # for features
   ```
   - Branch naming: `fix/` for bugs, `feature/` for new features
   - Use descriptive names that indicate what the work is about

3. **Make your changes and commit to YOUR branch:**
   ```bash
   git add <files>
   bd sync  # sync beads changes
   git commit -m "Your commit message"
   bd sync  # sync beads changes again
   ```
   - Never run `git commit` while on master/main!
   - Double-check with `git branch --show-current` if unsure

4. **Push YOUR branch to remote:**
   ```bash
   git push -u origin <your-branch-name>
   ```
   - The `-u` flag sets up tracking for the new branch
   - This is your branch, so pushing it is safe

5. **Create a Pull Request (PR)** using GitHub CLI:
   ```bash
   gh pr create --title "Title" --body "Description"
   ```
   - Or specify base branch explicitly: `gh pr create --base master --title "..." --body "..."`
   - Include summary of changes, test plan, and related issue numbers
   - The PR body should explain what changed and why

6. **Close the bead** after PR is created:
   ```bash
   bd close <bead-id> --reason "Created PR #123"
   bd sync
   ```
   - Close the bead AFTER creating the PR, not after merge
   - Include the PR number in the close reason

**The outcome of working on ANY issue should ALWAYS be a GitHub pull request (PR), never a direct push to an existing branch.**

Once a PR has been produced for an issue (a bead), you may close the bead as complete. The PR will be reviewed and possibly merged by a human.

## Pre-Commit Checklist (for AI agents)

Before running ANY git command, verify:
- [ ] Am I on a branch I created in this session? (`git branch --show-current`)
- [ ] If not, have I created a new feature/fix branch?
- [ ] Am I about to push to my own branch, not master/main?
- [ ] Have I run `bd sync` before and after committing?
- [ ] Will I create a PR after pushing?

**If any answer is NO, do NOT proceed with git push!**
