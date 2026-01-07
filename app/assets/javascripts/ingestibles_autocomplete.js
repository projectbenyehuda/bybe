// Ingestibles autocomplete enhancements
// Add loading indicators for autocomplete fields

$(document).ready(function() {
  // Add loading indicators for ingestibles autocomplete fields
  $('.ingestible-autocomplete-author, .ingestible-autocomplete-volume').each(function() {
    var $input = $(this);

    // Add loading class when search starts
    $input.on('autocompletesearch', function() {
      $(this).addClass('autocomplete-loading');
    });

    // Remove loading class when results arrive or search fails
    $input.on('autocompleteresponse autocompleteclose', function() {
      $(this).removeClass('autocomplete-loading');
    });
  });
});
