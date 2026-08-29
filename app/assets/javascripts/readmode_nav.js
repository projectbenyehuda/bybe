// The reading-mode control panel's item navigator (shared/_readmode_nav), used by both
// Manifestation#readmode and Collection#readmode. It replaces a native <select>, whose options
// cannot wrap, with a list of divs, so long chapter and item titles wrap instead of being clipped.
$(document).ready(function() {
  var nav = $('#rm_nav');
  if (nav.length === 0) {
    return;
  }

  var list = $('#rm_nav_list');
  var trigger = $('#rm_nav_current');
  var label = trigger.find('.rm-nav-current-label');
  var items = nav.find('.rm-nav-item');

  function anchorOf(item) {
    return $('a[name="' + $(item).data('anchor') + '"]');
  }

  function goTo(item) {
    var anchor = anchorOf(item);
    if (anchor.length === 0) {
      return;
    }
    items.removeClass('current');
    $(item).addClass('current');
    label.text($(item).text());
    $('html, body').animate({ scrollTop: anchor.offset().top - 20 }, 0);
  }

  // the last item whose anchor is at or above the current scroll position
  function currentItem() {
    var current = items.first();
    items.each(function() {
      var anchor = anchorOf(this);
      if (anchor.length > 0 && anchor.offset().top <= $(window).scrollTop() + 25) {
        current = $(this);
      }
    });
    return current;
  }

  function step(offset, message) {
    var index = items.index(currentItem()) + offset;
    if (index < 0 || index >= items.length) {
      alert(message);
      return;
    }
    goTo(items.get(index));
  }

  trigger.click(function(e) {
    e.stopPropagation();
    list.toggleClass('open');
  });
  items.click(function() {
    list.removeClass('open');
    goTo(this);
  });
  $(document).click(function() {
    list.removeClass('open');
  });

  $('#next_rm_item').click(function() {
    step(1, nav.data('no-next'));
  });
  $('#prev_rm_item').click(function() {
    step(-1, nav.data('no-prev'));
  });
});
