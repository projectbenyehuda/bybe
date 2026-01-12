$(document).ready(function() {
  // Only run on whatsnew page
  if ($('.whatsnew-nav').length === 0) {
    return;
  }

  // Sort toggle
  $('#sort_alpha').click(function() {
    window.location.href = '/whatsnew?sort=alpha';
  });

  $('#sort_recent').click(function() {
    window.location.href = '/whatsnew?sort=recent';
  });

  // Scrollspy for navigation highlighting
  $('body').scrollspy({ target: '.whatsnew-nav' });

  // Smooth scrolling for nav links
  $('.whatsnew-nav a[href^="#"]').click(function(e) {
    e.preventDefault();
    var target = $(this).attr('href');
    $('html, body').animate({
      scrollTop: $(target).offset().top - 100
    }, 500);
  });
});
