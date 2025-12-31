Important project instructions for AI agents
============================================

## ⚠️ CRITICAL: Git Workflow - READ THIS FIRST ⚠️

### THE MOST IMPORTANT RULE

**NEVER, EVER push directly to ANY existing branch that you did not create in the current session.**

This means:
- ❌ **NEVER** `git push` when on master, main, dragula, or any pre-existing branch
- ❌ **NEVER** commit directly to master/main even if you can bypass protection rules
- ❌ **NEVER** assume that being able to push means you should push
- ✅ **ALWAYS** create a new feature/fix branch BEFORE making any commits
- ✅ **ALWAYS** submit changes via Pull Request using `gh pr create`

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

### Project architecture

* READ AI_ARCHITECTURE_PRIMER.md for a primer on how the project is organized, its main models, controllers, and workflows. DO NOT SKIP THIS.

### ⚠️ CRITICAL: Testing Requirements ⚠️

**NO FEATURE OR BUG FIX IS COMPLETE WITHOUT PROPER TESTING**

Before considering ANY work complete, you MUST:

1. **Run the existing test suite** to ensure no regressions:
   ```bash
   bundle exec rspec
   ```
   - Allow up to 12 minutes for the suite. It includes browser tests and Elasticsearch tests, which take longer.
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

### Pre-Commit Checklist (for AI agents)

Before running ANY git command, verify:
- [ ] Am I on a branch I created in this session? (`git branch --show-current`)
- [ ] If not, have I created a new feature/fix branch?
- [ ] Am I about to push to my own branch, not master/main?
- [ ] Have I run `bd sync` before and after committing?
- [ ] Will I create a PR after pushing?

**If any answer is NO, do NOT proceed with git push!**

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
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
bd create "Subtask" --parent <epic-id> --json  # Hierarchical subtask (gets ID like epic-id.1)
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
3. **Create feature branch**: `git checkout -b fix/issue-name` or `feature/issue-name` (NEVER work directly on existing branches!)
4. **Work on it**: Implement, test, document
5. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
6. **Commit changes**: See "Git Workflow" section above for complete commit/push/PR process
7. **Create PR**: Always submit work via Pull Request, never push directly
8. **Complete**: `bd close <id>` after PR is created (not after merge)
9. **Sync beads**: Run `bd sync` after closing bead

**CRITICAL**: Always follow the Git Workflow section above. Never push to existing branches!

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### GitHub Copilot Integration

If using GitHub Copilot, also create `.github/copilot-instructions.md` for automatic instruction loading.
Run `bd onboard` to get the content, or see step 2 of the onboard instructions.

### MCP Server (Recommended)

If using Claude or MCP-compatible clients, install the beads MCP server:

```bash
pip install beads-mcp
```

Add to MCP config (e.g., `~/.config/claude/config.json`):
```json
{
  "beads": {
    "command": "beads-mcp",
    "args": []
  }
}
```

Then use `mcp__beads__*` functions instead of CLI commands.

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

**Example .gitignore entry (optional):**
```
# AI planning documents (ephemeral)
history/
```

**Benefits:**
- ✅ Clean repository root
- ✅ Clear separation between ephemeral and permanent documentation
- ✅ Easy to exclude from version control if desired
- ✅ Preserves planning history for archeological research
- ✅ Reduces noise when browsing the project

### CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

### Important Rules

**Git Workflow:**
- ✅ ALWAYS create a new feature/bug branch before starting work
- ✅ ALWAYS submit work via Pull Requests
- ✅ Run `bd sync` before and after commits to keep beads in sync
- ❌ NEVER push directly to ANY existing branch (master, main, dragula, etc.)
- ❌ NEVER skip creating a PR - all work must be reviewed

**Task Tracking:**
- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents


Important reminders:
   • NEVER push to existing branches - ALWAYS create feature/bug branch and PR
   • Use bd for ALL task tracking - NO markdown TODO lists
   • Always use --json flag for programmatic bd commands
   • Link discovered work with discovered-from dependencies
   • Check bd ready before asking "what should I work on?"
   • Run bd sync before and after commits

Addressing PR code review comments:

when asked to address PR code reviews, DO NOT issue 'gh pr view' commands (those have been deprecated since 2024). Instead, use the GitHub CLI API, e.g. gh api repos/projectbenyehuda/bybe/pulls/860/comments

For more details, see README.md in the project home directory.
