$(document).ready(function() {
  // Only run on whatsnew page
  if ($('.whatsnew-nav').length === 0) {
    return;
  }

  // Sort toggle - add defensive checks for button existence
  var $sortAlpha = $('#sort_alpha');
  var $sortRecent = $('#sort_recent');

  if ($sortAlpha.length) {
    $sortAlpha.click(function() {
      window.location.href = '/whatsnew?sort=alpha';
    });
  }

  if ($sortRecent.length) {
    $sortRecent.click(function() {
      window.location.href = '/whatsnew?sort=recent';
    });
  }

  // Scrollspy for navigation highlighting
  if (typeof $('body').scrollspy === 'function') {
    $('body').scrollspy({ target: '.whatsnew-nav' });
  }

  // Smooth scrolling for nav links
  $('.whatsnew-nav a[href^="#"]').click(function(e) {
    e.preventDefault();
    var target = $(this).attr('href');
    var $targetElement = $(target);

    // Only scroll if target element exists
    if ($targetElement.length) {
      $('html, body').animate({
        scrollTop: $targetElement.offset().top - 100
      }, 500, function() {
        // Update URL hash after scroll completes
        window.history.pushState(null, null, target);
      });
    }
  });
});
