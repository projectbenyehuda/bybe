// Collection reading mode (Collection#readmode): scroll progress indicator and ESC to leave.
// Navigation between the collection's items lives in readmode_nav.js, shared with the work page.
$(document).ready(function() {
  var readmode = $('#collection-readmode');
  if (readmode.length === 0) {
    return;
  }

  $(window).on('scroll', function() {
    var winScroll = document.body.scrollTop || document.documentElement.scrollTop;
    var height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    var scrolled = height > 0 ? (winScroll / height) * 100 : 0;
    if (scrolled > 100) {
      scrolled = 100;
    }
    $('.progress-bar').css('width', scrolled + '%');
    $('.progress-number').html(Math.ceil(scrolled) + '%');
    $('.progress-handle').css('right', Math.floor(scrolled) + '%');
  });

  $(document).on('keyup', function(evt) {
    if (evt.keyCode === 27) {
      window.location.href = readmode.data('collection-url');
    }
  });
});
