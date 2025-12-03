# Scrollspy Offset Fix - Issue by-1zz

## Problem Description
The scrollspy feature in the Manifestation#read view was not working accurately:
1. **On Page Load**: The LAST chapter was often highlighted instead of the first/current chapter
2. **While Scrolling**: The chapter highlight was offset from the expected position

## Root Causes Identified

### 1. Static Offset Calculation
**Location**: `app/views/layouts/application.html.erb:252`

The scrollspy was initialized once on page load with:
```javascript
$('body').scrollspy({ target: "#chapternav", offset: $('#header').height() });
```

The problem: The header height changes dynamically when the user scrolls (the "scrolled" class is applied via CSS, which changes the header's visual appearance and height). However, the scrollspy offset remained fixed at the initial page load value.

### 2. Conflicting Manual Scroll Handler
**Location**: `app/views/manifestation/_work_top.haml:148-153`

There was a manual scroll event handler:
```javascript
$(window).scroll(function() {
  var scroll = $(window).scrollTop();
  if(scroll <= 200) {
    $('.nav-link').first().addClass('active');
  }
});
```

This conflicted with Bootstrap's scrollspy automatic behavior, causing inconsistent highlighting.

### 3. Pre-activated First Chapter
**Location**: `app/views/manifestation/_work_top.haml:118`

The first chapter link was marked with class 'active' by default:
```haml
'class' => 'nav-link ... '+(first ? ' active' : '')
```

This could conflict with scrollspy's own activation logic, especially on page load.

## The Solution

### 1. Dynamic Offset Recalculation
**File**: `app/views/layouts/application.html.erb:255-265`

Added a scroll event listener that detects when the header height changes and reinitializes scrollspy:

```javascript
var lastHeaderHeight = $('#header').height();
$(window).on('scroll', function() {
  var currentHeaderHeight = $('#header').height();
  if (currentHeaderHeight !== lastHeaderHeight) {
    lastHeaderHeight = currentHeaderHeight;
    $('body').scrollspy('dispose');
    $('body').scrollspy({ target: "#chapternav", offset: currentHeaderHeight });
  }
});
```

This ensures the scrollspy offset is always accurate, even when the header height changes.

### 2. Removed Conflicting Manual Handler
**File**: `app/views/manifestation/_work_top.haml:147-153`

Removed the manual scroll handler that was forcing the first chapter to be active. Now scrollspy handles all chapter activation automatically based on actual scroll position.

### 3. Removed Default Active Class
**File**: `app/views/manifestation/_work_top.haml:115-118`

Removed the logic that marked the first chapter as active by default. The 'active' class is now entirely managed by Bootstrap's scrollspy based on the current scroll position and the correct offset.

## Expected Behavior After Fix

1. **On Page Load**: The chapter corresponding to the top of the visible content will be highlighted correctly
2. **While Scrolling**: The highlighted chapter will accurately track the user's position in the document
3. **After Header Transition**: When the header shrinks (scrolled class applied), the scrollspy will automatically adjust its offset calculation

## Files Modified

1. `app/views/layouts/application.html.erb` - Dynamic scrollspy offset recalculation
2. `app/views/manifestation/_work_top.haml` - Removed conflicting handlers and default active state
