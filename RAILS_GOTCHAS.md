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

## Template for Future Gotchas

When adding new entries, include:
1. **Date discovered** and **time spent**
2. **Symptoms** - what the user/developer sees
3. **Root cause** - why it happens
4. **Solution** - how to fix it
5. **Testing** - how to verify the fix
6. **Prevention** - how to avoid it in the future
