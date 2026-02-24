Important project instructions for AI agents
============================================

> **Note**: These instructions have been split into modular files in `.claude/rules/` for automatic loading in Claude Code:
> - `git-workflow.md` - Git workflow and PR requirements
> - `testing-requirements.md` - Testing standards and Capybara rules
> - `beads-tracking.md` - Issue tracking with bd/beads
> - `project-technologies.md` - HAML, RSpec, I18n requirements
>
> This file is kept for reference and other AI tools (GitHub Copilot, etc.)

## ⚠️ CRITICAL: Git Workflow - READ THIS FIRST ⚠️

### THE MOST IMPORTANT RULE

**NEVER, EVER push directly to ANY existing branch that you did not create in the current session.**

This means:
- ❌ **NEVER** `git push` when on master, main, dragula, or any pre-existing branch
- ❌ **NEVER** commit directly to master/main even if you can bypass protection rules
- ❌ **NEVER** assume that being able to push means you should push
- ✅ **ALWAYS** create a new feature/fix branch BEFORE making any commits
- ✅ **ALWAYS** submit changes via Pull Request using `gh pr create`
- ✅ **ALWAYS** make any CSS changes to the application.scss or other scss files. Treat the BY_*.css files as read-only!

**If you find yourself about to run `git push` on master/main, STOP! You're doing it wrong.**

### Why This Rule Exists

Even if the repository allows direct pushes to master (bypassing protection rules), you must NOT do it because:
1. All code changes must be reviewed via Pull Requests
2. CI checks must run before merging
3. Direct pushes circumvent the team's workflow
4. It creates merge conflicts and workflow confusion

### If You Made a Mistake

If you accidentally pushed to master/main:
1. Immediately revert: `git revert HEAD`
2. Push the revert: `git push`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Cherry-pick your work: `git cherry-pick <commit-hash>`
5. Push the branch: `git push -u origin feature/your-feature`
6. Create a PR: `gh pr create --title "..." --body "..."`

### Technologies and Preferred Tools

* we use HAML for views, not ERB
* we use RSpec for testing, not minitest
* we use Capybara for integration tests of real usage scenarios
* we use Rails I18n for all user-visible messages and UI labels. If you add a new message, make sure to create appropriatee entries in both config/locales/he.yml and config/locales/en.yml
* remember the site is in Hebrew, and the view should be oriented right-to-left (if you use the Bootsrap grid, it is *already* right-to-left by default, so that the first column would be shown on the RIGHT)

### Project architecture

* READ AI_ARCHITECTURE_PRIMER.md for a primer on how the project is organized, its main models, controllers, and workflows. DO NOT SKIP THIS.
* READ RAILS_GOTCHAS.md for documented Rails issues and their solutions. This file captures non-obvious problems that cost hours of debugging time. Always check this file when encountering unexplained Rails behavior.

### ⚠️ CRITICAL: Testing Requirements ⚠️

**NO FEATURE OR BUG FIX IS COMPLETE WITHOUT PROPER TESTING**

Before considering ANY work complete, you MUST:

1. **Run the existing test suite** to ensure no regressions:
   ```bash
   bundle exec rspec
   ```
   - Allow up to 15 minutes for the suite. It includes browser tests and Elasticsearch tests, which take longer.
   - All existing tests MUST pass
   - Fix any failing tests before submitting your work
   - If tests fail due to your changes, investigate and fix the root cause

2. **Write new tests** for your changes:
   - **For bug fixes**: Write a test that would have caught the bug (regression test)
   - **For new features**: Write tests covering the feature's functionality
   - **For UI changes**: Use Capybara system specs with JavaScript enabled (`js: true`)
   - **For API changes**: Write request specs testing the API endpoints
   - Exception: If the problem was in the tests themselves, fixing the tests is enough

3. **Verify your new tests pass**:
   ```bash
   bundle exec rspec path/to/your_new_spec.rb
   ```

4. **Run the full suite again** to ensure your new tests don't break anything:
   ```bash
   bundle exec rspec
   ```

**If you submit a PR without tests or with failing tests, it will be rejected.**

### Test Types and When to Use Them

- **Model specs** (`spec/models/`): Test model logic, validations, associations
- **Controller specs** (`spec/controllers/`): Test controller actions, params handling
- **Request specs** (`spec/requests/`): Test HTTP requests/responses, API endpoints
- **System specs** (`spec/system/`, requires `js: true`): Test full user interactions with JavaScript using Capybara
- **Service specs** (`spec/services/`): Test service objects and business logic

### Example: Testing a UI Bug Fix

When fixing a UI bug like scrollspy highlighting:
```ruby
# spec/system/manifestation_scrollspy_spec.rb
require 'rails_helper'

RSpec.describe 'Feature name', type: :system, js: true do
  it 'properly highlights chapters on page load' do
    # Test the bug is fixed
  end

  it 'updates highlighting during scroll' do
    # Test dynamic behavior
  end
end
```

### CRITICAL: Capybara Waiting in Tests

**NEVER use `sleep` in Capybara system tests.** Capybara has built-in intelligent waiting.

**DO NOT:**
```ruby
click_button 'Save'
sleep 0.5  # ❌ WRONG - flaky and slow
expect(page).to have_content('Saved')
```

**DO:**
```ruby
click_button 'Save'
expect(page).to have_content('Saved')  # ✅ Capybara waits automatically

# For AJAX updates, use element expectations:
expect(page).to have_css('.progress-bar[aria-valuenow="50"]')  # Waits for change
expect(page.find('#status')).to have_text('Complete')  # Waits for text

# For custom conditions, use have_xpath/have_css with text/count matchers
expect(page).to have_css('.item', count: 5)  # Waits for exactly 5 items
```

Capybara automatically waits (default 2 seconds, configurable) for:
- `find`, `have_content`, `have_css`, `have_xpath`, `have_text`
- All matchers and finders

**Remember**: A feature without tests is an incomplete feature.

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

3. **Make your changes, lint them, and commit to YOUR branch:**
   ```bash
   # FIRST: Run linters on ALL files you changed
   bundle exec rubocop <changed_ruby_files>  # Fix ALL RuboCop issues
   bundle exec haml-lint <changed_haml_files>  # Fix ALL HAML-Lint issues

   # ONLY proceed to commit after fixing ALL lint issues
   git add <files>
   git commit -m "Your commit message"
   ```
   - **CRITICAL**: You MUST run linters and fix ALL issues before committing
   - Focus on fixing issues in files YOU modified, not pre-existing issues
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
   ```
   - Close the bead AFTER creating the PR, not after merge
   - Include the PR number in the close reason

**The outcome of working on ANY issue should ALWAYS be a GitHub pull request (PR), never a direct push to an existing branch.**

Once a PR has been produced for an issue (a bead), you may close the bead as complete. The PR will be reviewed and possibly merged by a human.

### Pre-Commit Checklist (for AI agents)

Before running ANY git command, verify:
- [ ] Have I run linters on ALL files I changed?
  - [ ] `bundle exec rubocop <changed_ruby_files>` - Fixed ALL issues
  - [ ] `bundle exec haml-lint <changed_haml_files>` - Fixed ALL issues
- [ ] Am I on a branch I created in this session? (`git branch --show-current`)
- [ ] If not, have I created a new feature/fix branch?
- [ ] Am I about to push to my own branch, not master/main?
- [ ] Will I create a PR after pushing?
- [ ] Has the user approved the feature/fix?
**If any answer is NO, do NOT proceed with git push!**

Addressing PR code review comments:

**CRITICAL**: When asked to address PR code review comments, use this two-step process:

1. **Get review metadata**: Run `gh pr view <number> --json reviews,comments` to see all reviews
2. **Fetch full review content**: If reviews exist with actual content (not just line comments from bots), use WebFetch on the review URL to get the full substantive review. The URL format is:
   ```
   https://github.com/projectbenyehuda/bybe/pull/<number>#pullrequestreview-<review-id>
   ```

**Why this matters**:
- `gh api repos/.../pulls/<number>/comments` only returns individual line comments (lint issues, isolated feedback)
- It does NOT return the full review body text or comprehensive review content
- Bot reviews (github-actions, copilot-pull-request-reviewer) often provide detailed analysis in the review body, not just line comments
- WebFetch on the review URL provides the complete review including summary, analysis, and all recommendations

**Don't rely solely on the comments API** - it will miss substantive reviews!

For more details, see README.md in the project home directory.

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs with git:

- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

<!-- END BEADS INTEGRATION -->

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
