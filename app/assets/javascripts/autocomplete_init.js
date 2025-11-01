// Configure default options for autocomplete-rails gem
// Set Hebrew "no matches" message as default
$(document).ready(function() {
  if (typeof $.railsAutocomplete !== 'undefined') {
    $.railsAutocomplete.options.noMatchesLabel = 'אין פריט כזה עדיין';
  }
});
