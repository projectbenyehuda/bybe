# Rails Gotchas and Solutions

This document captures non-obvious Rails issues encountered in this project and their solutions. The goal is to prevent hours of debugging when these issues recur.

---

## Remote DELETE Links Don't Work with `link_to`

**Date Discovered:** 2026-01-06
**Time Spent Debugging:** ~3 hours
**Affected Rails Version:** Rails 8.0.2.1

### Symptoms

When using `link_to` with `remote: true` and `method: :delete`:
- Clicking the link navigates to a full page GET request instead of sending an AJAX DELETE
- Browser shows: `No route matches [GET] "/resource/123"` or 404 error
- The link HTML is correctly generated with `data-remote="true"` and `data-method="delete"` attributes
- Rails UJS is loaded and the `Rails` object exists in the console
- The issue occurs **even on fresh page load** (not just dynamically added content)

### Example of Broken Code

```haml
= link_to '×', external_link_path(link), remote: true, method: :delete, class: 'link-x', title: t(:cancel)
```

This generates correct HTML but doesn't work:
```html
<a class="link-x" title="ביטול" data-remote="true" rel="nofollow" data-method="delete" href="/external_links/7802">×</a>
```

### Root Cause

Rails UJS (rails-ujs) is not reliably intercepting click events on `<a>` tags with `data-method` attributes. The exact reason is unclear, but it may be related to:
- Event delegation issues in Rails UJS 8.x
- Interaction with other JavaScript on the page
- Timing issues with Rails UJS initialization

When manually calling `Rails.handleMethod()` on the link, it throws:
```
TypeError: can't access property "dispatchEvent", obj is null
```

### Solution

**Use `button_to` instead of `link_to` for remote DELETE requests.**

```haml
= button_to '×', external_link_path(link), method: :delete, remote: true, form: { style: 'display: inline;' }, class: 'link-x', title: t(:cancel)
```

The `button_to` helper creates a form with a button, which Rails UJS handles more reliably.

### Making the Button Look Like a Link

Add CSS to remove button styling and make it look like a link:

```css
/* Remove default button styling and make it look like a link */
.link-x, button.link-x {
  background: none;
  border: none;
  padding: 0;
  margin: 0;
  cursor: pointer;
  display: inline;
  outline: none;

  /* Your link styles here */
  font-family: inherit;
  font-size: inherit;
  color: #907989;
}

.link-x:hover, button.link-x:hover {
  color: #660248;
}
```

### Controller Considerations

When the issue manifests as a 406 error, ensure your controller responds to both JS and HTML formats:

```ruby
def destroy
  # ... destruction logic ...

  respond_to do |format|
    format.js { render js: "/* your JS response */" }
    format.html { redirect_back fallback_location: root_path, notice: "Deleted" }
  end
end
```

### Testing

To verify the fix works:
1. Fresh page load (no dynamic content)
2. Click the button
3. Check browser Network tab - should see a POST request to `/resource/123` with `_method=delete`
4. Response should be `Content-Type: text/javascript`
5. The DOM element should be removed via AJAX

### Related Issues

- This issue is similar to problems with dynamically loaded content, but occurs even with server-rendered HTML
- The working `tag-x` links in `_taggings.html.haml` likely work because they use a different pattern or context

### Prevention

**Rule of thumb:** For remote DELETE (or PUT/PATCH) requests in Rails 8+, prefer `button_to` over `link_to`.

If you must use `link_to`, test thoroughly in:
- Fresh page loads
- After dynamic content updates
- With browser DevTools Network tab open to verify the request method

---

## `inverse_of` Pre-Populates `collection_items` with Stale Cache

**Date Discovered:** 2026-07-01
**Time Spent Debugging:** ~2 hours
**Affected Rails Version:** Rails 8.1.3

### Symptoms

When you load a Collection's `collection_items` after the collection was loaded via `parent_collection_items.map(&:collection)` (or any `has_many ... inverse_of: :item` loaded association chain), `collection_items` appears pre-loaded but contains fewer items than the database actually has:

```ruby
series.parent_collection_items.first.collection.collection_items.loaded?  # => true  (!!)
series.parent_collection_items.first.collection.collection_items.count    # => 2  (wrong, DB has 3)
series.parent_collection_items.first.collection.collection_items.reset.count  # => 3  (correct)
```

### What Triggers It

The exact chain that causes the stale cache:

1. A Collection (e.g. `volume`) has `has_many :collection_items, inverse_of: :collection`
2. `volume.collection_items.create!(item: sub_collection)` is called — at this moment, Rails caches `volume.collection_items` in memory (say, with 2 items)
3. Later, more items are added to `volume.collection_items` (cache grows to 3 items), but the CollectionItem created in step 2 still carries an internal reference to the volume as it was at that moment
4. `sub_collection.parent_collection_items` is loaded (via `has_many :parent_collection_items, as: :item, inverse_of: :item`)
5. `.first.collection` is called on the loaded CollectionItem — Rails's `inverse_of` mechanism loads a *new* Ruby object for the volume, but pre-populates its `collection_items` from the in-memory state at step 2 (only 2 items), not from the DB

### Root Cause

Rails's `inverse_of` association pre-populates the `has_many` side when loading via the `belongs_to` side. When the `CollectionItem` is loaded as part of a `has_many ... as: :item, inverse_of: :item` association, the resulting Ruby object carries a reference back to the original in-memory collection object. When `.collection` is subsequently called on that CollectionItem, Rails creates a new Collection object but pre-populates its `collection_items` association from whatever was already in memory — which may be a stale snapshot from when the CollectionItem was originally created through `collection.collection_items.create!`.

This is invisible to normal queries (`loaded?` returns `true`) and silently returns incomplete data.

### Which Patterns Are Safe vs. Unsafe

```ruby
# UNSAFE — triggers stale pre-population:
parent_collection = ci.collection  # when ci loaded via has_many ... inverse_of: :item
parent_collection.collection_items  # may return stale/incomplete list

# SAFE — bypasses the association cache entirely:
CollectionItem.where(collection: parent_collection).order(:seqno)

# SAFE — forces a fresh DB query on the existing object:
parent_collection.collection_items.reset

# SAFE — loading a collection directly never has this issue:
Collection.find(id).collection_items
CollectionItem.find(id).collection  # when loaded standalone, not via a has_many
```

### Where This Exists in This Codebase

**`CrossCollectionNavigation` (fixed):** The original `flatten_manifestations` used `collection.collection_items`; it was fixed to use `CollectionItem.where(collection: collection)` directly (see PR #1406).

**`propagate_count_update_to_parents` → `recalculate_manifestations_count!` (theoretical risk):**

```ruby
def propagate_count_update_to_parents
  stack = parent_collections.to_a  # parent_collections uses parent_collection_items.map(&:collection)
  ...
  collections_to_update.each do |collection|
    collection.recalculate_manifestations_count!  # accesses collection.collection_items — may be stale
  end
end
```

Each `collection` here was obtained via `parent_collection_items.first.collection`, so its `collection_items` could be stale. In practice this only produces wrong counts if a parent collection's own `collection_items` was modified in the same request *before* the callback fires; in normal usage the parent's items are unchanged at that point, so the stale cache happens to be correct. However, if you ever perform multiple CollectionItem operations on the same parent in one request, verify that `recalculate_manifestations_count!` is producing the right result.

**`Collection#parent_collections` (safe):** The result is used only to check `pc.volume?`, traverse further up the tree, or call `pc.authorities` / `pc.invalidate_cached_credits!` — none of which iterate `collection_items` on the returned objects.

### Prevention

Any time you navigate upward via `parent_collections` (or `parent_collection_items.map(&:collection)`) and then need to iterate `collection_items` on the resulting parent, use one of the safe patterns above. Add a comment explaining why.

---

## `attribute_changed?` Is Always False After a Successful Save

**Date Discovered:** 2026-08-27
**Time Spent Debugging:** the bug itself shipped silently and went unnoticed for an unknown period; it was found only by investigating a user-reported symptom (see below), not by anyone debugging the controller
**Affected Rails Version:** Rails 8.1.3 (true since Rails 5.2)

### Symptoms

A conditional that reads perfectly well never fires, and there is no error, no log line, and no failing test:

```ruby
if @author.update(authority_params)   # ← saves here
  ...
  if @author.status_changed? && @author.status == 'published'   # ← ALWAYS false
    @author.publish!                  # ← dead code, never runs
  end
end
```

The observable damage is downstream and arbitrarily far away. In this case, publishing an
authority from the edit form silently did none of what `publish!` does: no `published_at`
stamp, none of the pending works published, and no `newest_authors` / `homepage_authors`
cache invalidation.

The symptom that eventually surfaced was a **sorting** complaint: `/authors` sorted by upload
date (newest first) topped out at a stale date and never showed recent authors. 41% of
published authorities (1,155 of 2,789) had ended up with `published_at = NULL`, and because
Elasticsearch omits a null field and sorts **missing values last** on a `desc` sort, those
authorities were not mis-ordered — they were *invisible* at the top of the list. Nothing about
that symptom points at a controller conditional.

### Root Cause

`ActiveModel::Dirty` tracks changes to an **unsaved** record. A successful save clears them and
moves them to the `saved_change_to_*` family. So after `save` / `update` / `update!` returns:

| Method | Before save | After a successful save |
| --- | --- | --- |
| `status_changed?` | `true` | **`false`** |
| `status_was` | old value | **current value** |
| `changes` | populated | **`{}`** |
| `saved_change_to_status?` | `false` | `true` |
| `status_previously_changed?` | `false` | `true` |
| `saved_change_to_status` | `nil` | `[old, new]` |

Verified on this codebase:

```ruby
a.update(status: :published)
a.status_changed?            # => false
a.saved_change_to_status?    # => true
```

The trap is that the `*_changed?` form is the one everybody reaches for, it is valid Ruby, it is
valid on the model, and in a `before_save` callback it is exactly right. It is wrong **only**
after the write has already happened — which is precisely where controllers tend to put
"and now do the follow-up work" logic.

### Solution

After a save, use the past-tense API:

```ruby
if @author.saved_change_to_status? && @author.published?
  @author.publish!
end
```

Better still, move the logic into the model where the present-tense API is correct, so no
caller can forget:

```ruby
before_save :stamp_published_at, if: -> { status_changed? && published? }
```

Both were applied here (PR #1642): the controller guard was corrected, *and* the stamping moved
into an `Authority` `before_save` callback so that every publishing path — ingestion, direct
status edit, `published!`, seeds — gets it.

### Which Form Belongs Where

```ruby
# BEFORE the write — present tense is correct:
before_validation { ... if status_changed? }
before_save :do_thing, if: :status_changed?

# AFTER the write — past tense is required:
after_save    :do_thing, if: :saved_change_to_status?
after_commit  :do_thing, if: :saved_change_to_status?
controller:   if @record.saved_change_to_status?

# Inside an after_* callback, `status_changed?` is ALSO false. Same trap.
```

### Testing

A spec that only asserts the *record* ends up correct will pass against the bug, because the
record's own attributes are set by the `update` itself. To catch this you must assert on the
**side effects** that live behind the conditional:

```ruby
it 'publishes the pending works' do
  request
  expect(pending_work.reload).to be_published    # fails against the buggy guard
end

it 'busts the newest-authors caches' do
  allow(Rails.cache).to receive(:delete)
  request
  expect(Rails.cache).to have_received(:delete).with('newest_authors')
end
```

Always confirm a regression spec actually fails against the original code before you trust it.
Here, a third example asserting `published_at` was stamped passed *either way*, because the new
model callback covered it — only the two side-effect examples above proved the controller fix.

Note that `config.cache_store = :null_store` in the test environment makes a
`Rails.cache.write` → `read` round-trip pass vacuously; assert on the `delete` message instead.

### Prevention

- Grep for candidates periodically:
  `grep -rn "_changed?" app/controllers/ | grep -v "saved_change_to\|previously_changed"`.
  This surfaces call sites to *review*, not bugs to fix on sight — the deciding question is
  whether the record has already been saved on that path. As of 2026-08-27 the only hits are
  `lexicon/person_works_controller.rb:113` and `lexicon/citations_controller.rb:110`, and both
  are **correct**: they check `attribute_changed?(:seqno)` on an in-memory assignment *before*
  saving, to skip a pointless write. Don't "fix" those.
- In a code review, treat `if record.foo_changed?` **inside** a successful-save branch as a
  defect on sight. That is the unambiguous case.
- Prefer putting post-save consequences in model callbacks over controllers.
- Watch for a mixed idiom in one method as a tell: the `authors#update` action used the correct
  `period_previously_changed?` nine lines above the broken `status_changed?`.

---

## Template for Future Gotchas

When adding new entries, include:
1. **Date discovered** and **time spent**
2. **Symptoms** - what the user/developer sees
3. **Root cause** - why it happens
4. **Solution** - how to fix it
5. **Testing** - how to verify the fix
6. **Prevention** - how to avoid it in the future
