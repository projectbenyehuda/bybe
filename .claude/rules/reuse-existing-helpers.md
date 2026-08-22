# Reuse Existing Helpers — Search Before You Write One

## The rule

**Before writing any helper, utility, or convenience method, search the repo for
an existing one that already does the job.** If one exists, use it. If one
almost exists, extend it in place rather than writing a parallel version next to
it.

This applies to specs just as much as to app code. A private `def` at the top of
a spec file is still a utility function, and it is the most common place this
rule gets broken.

## Where the shared helpers already live

| Kind | Location |
| --- | --- |
| Spec login / auth stubbing | `spec/support/test_helpers.rb` (included for `:system`, `:request`, `:controller`) |
| Capybara / WebDriver guards | `spec/support/system_spec_helpers.rb` (e.g. `webdriver_available?`) |
| Elasticsearch/Chewy in specs | `spec/support/es_helpers.rb` (e.g. `import_and_await`) |
| Custom matchers | `spec/support/negated_matchers.rb` |
| Shared example groups | `spec/support/shared_examples/` |
| View helpers | `app/helpers/` |
| Reusable business logic | `app/services/` |

**Logging a user in inside a spec is `login_as(user)` from
`spec/support/test_helpers.rb`.** Do not hand-roll
`allow_any_instance_of(ApplicationController).to receive(:current_user)` in an
individual spec file — that stub lives in exactly one place, with exactly one
RuboCop exemption. For the privileged-editor variants use the existing
`login_as_catalog_editor`, `login_as_batch_editor`, `login_as_moderator`, or
`login_as_lexicon_editor`.

## How to check (30 seconds, do it every time)

```bash
ls spec/support/                             # what shared spec helpers exist?
grep -rn "def <the_thing_you_were_about_to_write>" spec/ app/ lib/
grep -rn "<the distinctive line you were about to copy>" spec/ app/ lib/
```

If the grep for the *line you were about to write* returns hits in more than one
file, that line wants to be a shared helper — put it in `spec/support/` (or
`app/helpers/`, `app/services/`) and call it from both places.

## Warning signs you are reinventing something

- You are about to add a file-local `# rubocop:disable` for a pattern that the
  rest of the codebase also uses → the exemption belongs at the one shared
  definition, not scattered per file.
- You are copying a two-or-three-line incantation out of another spec.
- Your new method's name is a near-synonym of one that already exists
  (`login_as` vs. `sign_in_user`, `stub_current_user`, …).

## Historical context

Added 2026-08-22 after PR #1589: a request spec defined its own local
`login_as` helper plus a per-file `RuboCop:disable RSpec/AnyInstance`, when
`spec/support/test_helpers.rb` was already included for `type: :request` and was
the natural home for it. Copilot's review caught it. The fix was to add a shared
`login_as(user)` there and route the existing `login_as_*_editor` helpers
through it.
