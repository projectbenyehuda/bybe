# Rails AJAX CSRF Token Requirement

## CRITICAL: Always Include CSRF Tokens in AJAX Requests

When writing JavaScript AJAX requests in Rails applications, **ALWAYS** include the CSRF token for non-GET requests (POST, PATCH, PUT, DELETE).

### Required Pattern

**jQuery AJAX:**
```javascript
$.ajax({
    url: someUrl,
    type: 'PATCH', // or POST, PUT, DELETE
    dataType: 'json',
    headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
    },
    data: { ... },
    success: function(data) { ... },
    error: function(xhr) { ... }
});
```

**Fetch API:**
```javascript
fetch(url, {
    method: 'PATCH',
    headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify(data)
});
```

### Why This Matters

- Rails requires CSRF tokens as a security measure to prevent Cross-Site Request Forgery attacks
- Without the token, Rails will reject the request with 422 Unprocessable Entity
- The request appears to succeed on the client side (visual feedback works), but the database is never updated
- This creates confusing bugs where UI updates work but data doesn't persist

### GET Requests

GET requests do NOT require CSRF tokens (they should be idempotent and not modify data).

### Historical Context

This rule was added after a bug in PR #855 where profile image selection showed visual feedback but didn't update the database due to missing CSRF token.
