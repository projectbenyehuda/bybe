# Running the Full Test Suite: Ask First

## The rule

**The full RSpec suite (`bundle exec rspec` with no arguments) takes OVER 40 MINUTES.**

Do **NOT** run the full suite on your own initiative. Run it **only** when the
user explicitly approves or asks for it.

## What to do instead

For ordinary feature/bugfix work, run only the specs that are relevant:

```bash
bundle exec rspec spec/models/foo_spec.rb spec/requests/lexicon/bar_spec.rb
bundle exec rspec spec/system/lexicon/           # a targeted directory
```

Report exactly which specs you ran, and state plainly that the full suite was
not run and needs the user's approval.

## If the user does approve a full run

- Budget **at least 45–60 minutes** (`timeout 3600`), and run it in the
  background writing to a log file rather than piping to `tail` (a pipe buffers
  everything until the process exits, so you can't monitor progress).
- A `timeout 1500`-style cap will kill the run mid-way with exit code 143 and
  produce no results.

## Interaction with the testing-requirements rule

`.claude/rules/testing-requirements.md` says to run `bundle exec rspec` before
considering work complete. That instruction stands for *what* must eventually be
verified, but the **timing is the user's call**: write the tests, run the
targeted specs, and wait for approval before spending 40+ minutes on the full
suite.

## Historical context

Added 2026-08-01 after a full-suite run was killed at the 25-minute mark and a
second attempt was interrupted; the user clarified the suite takes over 40
minutes and should only be run with their approval.
