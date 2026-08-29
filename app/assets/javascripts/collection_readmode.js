// Collection reading mode (Collection#readmode): scroll progress indicator, ESC to leave, and
// navigation between the collection's items via the control panel's selector.
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

  var selector = $('#collitem');
  if (selector.length === 0) {
    return; // single-item collection: no item navigation
  }

  function scrollToItem(index) {
    var anchor = $('a[name=collitem_text_' + index + ']');
    if (anchor.length === 0) {
      return;
    }
    $('html, body').animate({ scrollTop: anchor.offset().top - 20 }, 0);
  }

  // the last item whose anchor is at or above the current scroll position
  function currentOption() {
    var current = selector.find('option').first();
    selector.find('option').each(function() {
      var anchor = $('a[name=collitem_text_' + $(this).val() + ']');
      if (anchor.length > 0 && anchor.offset().top <= $(window).scrollTop() + 25) {
        current = $(this);
      }
    });
    return current;
  }

  function goToSibling(sibling, emptyMessage) {
    if (sibling.length === 0) {
      alert(emptyMessage);
      return;
    }
    selector.val(sibling.val());
    scrollToItem(sibling.val());
  }

  selector.change(function() {
    scrollToItem($(this).val());
  });
  $('#next_collitem').click(function() {
    goToSibling(currentOption().next(), readmode.data('no-next-item'));
  });
  $('#prev_collitem').click(function() {
    goToSibling(currentOption().prev(), readmode.data('no-prev-item'));
  });
});
