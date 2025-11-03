// Manifestation Batch Tools - AJAX functionality and batch operations

$(document).ready(function() {
  if ($('#manifestations-table').length === 0) {
    return; // Only run on manifestation_batch_tools page
  }

  // Get CSRF token for AJAX requests
  function getCsrfToken() {
    return $('meta[name="csrf-token"]').attr('content');
  }

  // Show/hide batch actions based on checkbox selection
  function updateBatchActionsVisibility() {
    var checkedCount = $('.manifestation-checkbox:checked').length;
    if (checkedCount > 0) {
      $('#batch-actions-container').show();
    } else {
      $('#batch-actions-container').hide();
    }
  }

  // Select all / unselect all functionality
  $('#select-all').on('change', function() {
    var isChecked = $(this).prop('checked');
    $('.manifestation-checkbox').prop('checked', isChecked);
    updateBatchActionsVisibility();
  });

  // Individual checkbox change - using event delegation
  $(document).on('change', '.manifestation-checkbox', function() {
    var totalCheckboxes = $('.manifestation-checkbox').length;
    var checkedCheckboxes = $('.manifestation-checkbox:checked').length;
    $('#select-all').prop('checked', totalCheckboxes === checkedCheckboxes);
    updateBatchActionsVisibility();
  });

  // Handle visual feedback for row
  function showSuccess(rowId) {
    var $row = $('#manifestation-row-' + rowId);
    $row.css('background-color', '#d4edda'); // light green
    setTimeout(function() {
      $row.fadeOut(3000, function() {
        $(this).remove();
        // If no more visible rows, hide batch actions
        if ($('#manifestations-table tbody tr:visible').length === 0) {
          $('#batch-actions-container').hide();
        }
      });
    }, 500);
  }

  function showError(rowId, message) {
    var $row = $('#manifestation-row-' + rowId);
    $row.css('background-color', '#f8d7da'); // light red
    alert('Error: ' + message);
  }

  // AJAX function to perform action on a single manifestation
  function performAction(manifestationId, action, url, method) {
    $.ajax({
      url: url,
      method: method,
      dataType: 'json',
      headers: {
        'X-CSRF-Token': getCsrfToken()
      },
      data: { id: manifestationId },
      success: function(response) {
        if (response.success) {
          showSuccess(manifestationId);
        } else {
          showError(manifestationId, response.message || 'Unknown error');
        }
      },
      error: function(xhr, status, error) {
        var message = 'Request failed: ' + error;
        if (xhr.responseJSON && xhr.responseJSON.message) {
          message = xhr.responseJSON.message;
        }
        showError(manifestationId, message);
      }
    });
  }

  // Single delete button click - using event delegation
  $(document).on('click', '.delete-manifestation', function(e) {
    e.preventDefault();
    var $btn = $(this);
    var manifestationId = $btn.data('manifestation-id');
    var confirmMessage = $btn.data('confirm');
    if (confirm(confirmMessage)) {
      performAction(
        manifestationId,
        'delete',
        '/admin/destroy_manifestation',
        'DELETE'
      );
    }
  });

  // Single unpublish button click - using event delegation
  $(document).on('click', '.unpublish-manifestation', function(e) {
    e.preventDefault();
    var manifestationId = $(this).data('manifestation-id');
    performAction(
      manifestationId,
      'unpublish',
      '/admin/unpublish_manifestation',
      'POST'
    );
  });

  // Batch delete
  $('#batch-destroy').on('click', function(e) {
    e.preventDefault();
    var $container = $('#batch-actions-container');
    var selectedIds = [];
    $('.manifestation-checkbox:checked').each(function() {
      selectedIds.push($(this).data('manifestation-id'));
    });

    if (selectedIds.length === 0) {
      alert($container.data('please-select'));
      return;
    }

    var confirmTemplate = $container.data('confirm-batch-delete');
    var confirmMessage = confirmTemplate.replace('%<count>s', selectedIds.length);
    if (confirm(confirmMessage)) {
      selectedIds.forEach(function(id) {
        performAction(
          id,
          'delete',
          '/admin/destroy_manifestation',
          'DELETE'
        );
      });
    }
  });

  // Batch unpublish
  $('#batch-unpublish').on('click', function(e) {
    e.preventDefault();
    var $container = $('#batch-actions-container');
    var selectedIds = [];
    $('.manifestation-checkbox:checked').each(function() {
      selectedIds.push($(this).data('manifestation-id'));
    });

    if (selectedIds.length === 0) {
      alert($container.data('please-select'));
      return;
    }

    var confirmTemplate = $container.data('confirm-batch-unpublish');
    var confirmMessage = confirmTemplate.replace('%<count>s', selectedIds.length);
    if (confirm(confirmMessage)) {
      selectedIds.forEach(function(id) {
        performAction(
          id,
          'unpublish',
          '/admin/unpublish_manifestation',
          'POST'
        );
      });
    }
  });
});
