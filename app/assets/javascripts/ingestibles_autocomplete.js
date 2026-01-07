// Ingestibles autocomplete enhancements
// Add loading indicators for autocomplete fields

$(document).ready(function() {
  // Add loading indicators for ingestibles autocomplete fields
  $('.ingestible-autocomplete-author, .ingestible-autocomplete-volume').each(function() {
    var $input = $(this);
    var loadingBadgeId = $input.attr('id') + '_loading_badge';

    // Add loading badge when search starts
    $input.on('autocompletesearch', function() {
      // Remove any existing badge first
      $('#' + loadingBadgeId).remove();

      // Create and insert loading badge after the input field
      var $badge = $('<span>', {
        id: loadingBadgeId,
        class: 'autocomplete-loading-badge',
        text: $(this).data('loading-text') || 'Loading...'
      });

      $(this).after($badge);
      $(this).addClass('autocomplete-loading');
    });

    // Remove loading badge when results arrive or search fails
    $input.on('autocompleteresponse autocompleteclose', function() {
      $('#' + loadingBadgeId).fadeOut(200, function() {
        $(this).remove();
      });
      $(this).removeClass('autocomplete-loading');
    });
  });
});
