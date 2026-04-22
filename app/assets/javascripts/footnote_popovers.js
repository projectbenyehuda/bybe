// Footnote popover behavior:
// - Prevent anchor navigation when clicking a footnote reference (let the popover show via focus)
// - Close the open popover when the in-popover [x] link is clicked
$(function() {
  $(document).on('click', 'a.footnote[data-toggle="popover"]', function(e) {
    e.preventDefault();
  });

  $(document).on('click', '.fn-popover-close', function(e) {
    e.preventDefault();
    $('a.footnote[data-toggle="popover"]').popover('hide');
  });
});
