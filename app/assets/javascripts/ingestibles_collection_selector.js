// Collection selector and sub-collection functionality for Ingestibles#edit form

$(document).ready(function() {
  // Override the autocomplete source to include collection_type filter
  $('#cterm').on('railsAutocomplete.source', function(event, data) {
    var collectionType = $('#collection_type_filter').val();
    if (collectionType && collectionType !== 'all') {
      data.extraParams = { collection_type: collectionType };
    }
  });

  // Reload autocomplete when collection type filter changes
  $('#collection_type_filter').on('change', function() {
    // Clear the current selection
    $('#cterm').val('');
    $('#prospective_volume_id').val('');
    $('#ingestible_prospective_volume_title').val('');

    // Hide sub-collections
    $('#sub_collection_selector').hide();
    $('#sub_collection_id').empty();
  });

  // Load sub-collections when a collection is selected
  function loadSubCollections(collectionId) {
    if (!collectionId) {
      $('#sub_collection_selector').hide();
      $('#sub_collection_id').empty();
      return;
    }

    // Show loading state
    $('#sub_collection_id').empty().append($('<option>', {
      value: '',
      text: 'Loading...'
    }));
    $('#sub_collection_selector').show();

    // Fetch sub-collections via AJAX
    $.ajax({
      url: '/ingestibles/collection_descendants/' + collectionId,
      method: 'GET',
      success: function(descendants) {
        populateSubCollections(descendants);
      },
      error: function() {
        $('#sub_collection_id').empty().append($('<option>', {
          value: '',
          text: 'Error loading sub-collections'
        }));
      }
    });
  }

  function populateSubCollections(descendants) {
    var $select = $('#sub_collection_id');
    $select.empty();

    // Add blank option
    $select.append($('<option>', {
      value: '',
      text: $select.data('blank-text') || 'Select sub-collection'
    }));

    if (descendants.length === 0) {
      $('#sub_collection_selector').hide();
      return;
    }

    // Populate with sub-collections
    descendants.forEach(function(collection) {
      $select.append($('<option>', {
        value: collection.id,
        text: collection.title_and_authors + ' (' + collection.type_label + ')',
        'data-title': collection.title
      }));
    });

    $('#sub_collection_selector').show();
  }

  // Handle sub-collection selection
  $('#sub_collection_id').on('change', function() {
    var subCollectionId = $(this).val();
    if (subCollectionId) {
      var subCollectionTitle = $(this).find('option:selected').data('title');

      // Update the prospective_volume_id to the sub-collection
      $('#prospective_volume_id').val(subCollectionId);

      // Update the autocomplete field
      $('#cterm').val(subCollectionTitle);

      // Update volume title if element exists
      if ($('#volume_title').length > 0) {
        $('#volume_title').text(subCollectionTitle);
      }

      $('#need_to_save').show();
    }
  });

  // Listen for collection selection events from other parts of the form
  $(document).on('collection:selected', function(e, collectionId) {
    if (collectionId) {
      loadSubCollections(collectionId);
    } else {
      $('#sub_collection_selector').hide();
      $('#sub_collection_id').empty();
    }
  });

  // Make loadSubCollections globally accessible for inline JS
  window.loadSubCollections = loadSubCollections;
});
