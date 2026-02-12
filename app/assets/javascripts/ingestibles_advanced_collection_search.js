// Advanced collection search widget for Ingestibles#edit form

$(document).ready(function() {
  var advancedSearchVisible = false;

  // Toggle advanced search visibility
  $('#toggle_advanced_search').on('click', function(e) {
    e.preventDefault();
    advancedSearchVisible = !advancedSearchVisible;

    if (advancedSearchVisible) {
      $('#advanced_collection_search').slideDown();
    } else {
      $('#advanced_collection_search').slideUp();
    }
  });

  // Handle search button click
  $('#advanced_search_button').on('click', function(e) {
    e.preventDefault();
    performAdvancedSearch();
  });

  // Handle Enter key in search fields
  $('#advanced_search_title, #advanced_search_authority').on('keypress', function(e) {
    if (e.which === 13) {
      e.preventDefault();
      performAdvancedSearch();
    }
  });

  // Handle result selection
  $(document).on('click', '.advanced-search-result', function(e) {
    e.preventDefault();
    var collectionId = $(this).data('collection-id');
    var collectionTitle = $(this).data('collection-title');

    // Set the prospective_volume_id and title
    $('#prospective_volume_id').val(collectionId);
    $('#ingestible_prospective_volume_title').val(collectionTitle);

    // Update volume title if element exists
    if ($('#volume_title').length > 0) {
      $('#volume_title').text(collectionTitle);
    }

    $('#ingestible_no_volume').prop('checked', false);
    $('#need_to_save').show();

    // Hide advanced search
    $('#advanced_collection_search').slideUp();
    advancedSearchVisible = false;
  });

  function performAdvancedSearch() {
    var searchParams = {
      title: $('#advanced_search_title').val(),
      authority_id: $('#advanced_search_authority_id').val(),
      types: []
    };

    // Collect selected collection types
    $('.collection-type-checkbox:checked').each(function() {
      searchParams.types.push($(this).val());
    });

    // Show loading indicator
    $('#advanced_search_results').html('<div class="loading">Loading...</div>');

    // Perform AJAX search
    $.ajax({
      url: $('#advanced_search_form').data('search-url'),
      method: 'GET',
      data: searchParams,
      success: function(data) {
        displaySearchResults(data);
      },
      error: function() {
        $('#advanced_search_results').html('<div class="error">Search failed. Please try again.</div>');
      }
    });
  }

  function displaySearchResults(results) {
    var $resultsDiv = $('#advanced_search_results');

    if (results.length === 0) {
      $resultsDiv.html('<div class="no-results">' + $resultsDiv.data('no-results-text') + '</div>');
      return;
    }

    var html = '<div class="results-list">';
    results.forEach(function(collection) {
      html += '<div class="advanced-search-result" ' +
              'data-collection-id="' + collection.id + '" ' +
              'data-collection-title="' + collection.title + '" ' +
              'style="cursor: pointer; padding: 8px; border-bottom: 1px solid #ddd; hover: background-color: #f0f0f0;">' +
              '<strong>' + escapeHtml(collection.title) + '</strong><br>' +
              '<small style="color: #666;">' + escapeHtml(collection.title_and_authors) + '</small><br>' +
              '<small style="color: #999;">(' + escapeHtml(collection.type_label) + ')</small>' +
              '</div>';
    });
    html += '</div>';

    $resultsDiv.html(html);
  }

  function escapeHtml(text) {
    var map = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, function(m) { return map[m]; });
  }

  // Setup autocomplete for authority search in advanced widget
  $('#advanced_search_authority').autocomplete({
    source: function(request, response) {
      $.ajax({
        url: $(this.element).data('autocomplete-url'),
        dataType: 'json',
        data: {
          term: request.term
        },
        success: function(data) {
          response(data);
        }
      });
    },
    minLength: 2,
    select: function(event, ui) {
      $('#advanced_search_authority_id').val(ui.item.id);
      // Auto-search when authority is selected
      performAdvancedSearch();
    }
  });
});
