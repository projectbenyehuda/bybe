Important project instructions for AI agents
============================================

Technologies and preferred tools:
* we use HAML for views, not ERB
* we use RSpec for testing, not minitest
* we use Capybara for integration tests of real usage scenarios
* add tests for every feature you implement or bug you fix, unless the problem was in the tests themselves, in which case fixing the tests is enough

## Git Workflow - CRITICAL FOR AI AGENTS

**NEVER push directly to ANY existing branch** (including master, main, dragula, or any other branch you did not create in the current session).

**ALWAYS follow this workflow:**

1. **Create a new feature/bug branch** from your current branch:
   ```bash
   git checkout -b fix/issue-description  # for bugs
   git checkout -b feature/feature-name   # for features
   ```

2. **Make your changes, commit them, and push YOUR branch:**
   ```bash
   git add <files>
   bd sync  # sync beads changes
   git commit -m "Your commit message"
   bd sync  # sync beads changes again
   git push -u origin <your-branch-name>
   ```

3. **Create a Pull Request (PR)** using GitHub CLI:
   ```bash
   gh pr create --base <original-branch> --title "Title" --body "Description"
   ```
   Example: If you were on `dragula` branch, create PR with `--base dragula`

4. **Close the bead** after PR is created:
   ```bash
   bd close <bead-id>
   bd sync
   ```

**The outcome of working on ANY issue should ALWAYS be a GitHub pull request (PR), never a direct push to an existing branch.**

Once a PR has been produced for an issue (a bead), you may close the bead as complete. The PR will be reviewed and possibly merged by a human.

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

For more details, see README.md.

