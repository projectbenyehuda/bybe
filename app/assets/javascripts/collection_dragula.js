// Dragula initialization for collection management
// This handles drag & drop for both anthology texts and collection items

(function() {
  'use strict';

  // Global Dragula instance for collection items
  window.initializeCollectionDragula = function() {
    // Destroy existing instance if it exists
    if (window.collectionDrakeInstance) {
      window.collectionDrakeInstance.destroy();
      window.collectionDrakeInstance = null;
    }

    var collectionContainers = Array.from(document.querySelectorAll('.collection.connectable'));
    if (collectionContainers.length === 0) {
      return null;
    }

    var drake = dragula(collectionContainers, {
      moves: function(el, container, handle) {
        if (!handle || !handle.classList) return false;
        return handle.classList.contains('drag-handle') || handle.closest('.drag-handle');
      }
    });

    var oldIndex = null;

    drake.on('drag', function(el, source) {
      oldIndex = Array.from(el.parentNode.children).indexOf(el);
      el.setAttribute('data-old-index', oldIndex);
    });

    drake.on('drop', function(el, target, source, sibling) {
      if (!target) return;

      var $container = $(el).closest('.container-fluid');
      var $mask = $container.find('.collection-mask');
      
      if ($mask.length > 0) {
        $mask.show();
      }

      var newIndex = Array.from(target.children).indexOf(el);
      var oldIdx = parseInt(el.getAttribute('data-old-index'), 10);
      
      var itemIdMatch = el.id.match(/_collitem_(\d+)$/);
      var destCollIdMatch = target.id.match(/_coll_(\d+)$/);
      var srcCollIdMatch = source.id.match(/_coll_(\d+)$/);
      
      if (!itemIdMatch || !destCollIdMatch || !srcCollIdMatch) {
        console.error('Invalid element IDs during drag operation. Expected format: nonce_collitem_ID and nonce_coll_ID', 
                      'Element:', el.id, 'Target:', target.id, 'Source:', source.id);
        if ($mask.length > 0) {
          $mask.hide();
        }
        return;
      }
      
      var itemId = itemIdMatch[1];
      var destCollId = destCollIdMatch[1];
      var srcCollId = srcCollIdMatch[1];

      el.removeAttribute('data-old-index');

      var onError = function(xhr) {
        var errorMsg = xhr.status === 400 ? xhr.responseText : 'Status ' + xhr.status;
        var msg = 'Collection operation error: ' + errorMsg;
        alert(msg);
        location.reload();
      };

      if (srcCollId === destCollId) {
        if (newIndex !== oldIdx) {
          $.post('/collection_items/' + itemId + '/drag_item', {
            collection_id: destCollId,
            old_index: oldIdx,
            new_index: newIndex
          }).fail(onError).always(function() { 
            if ($mask.length > 0) {
              $mask.hide();
            }
          });
        } else {
          if ($mask.length > 0) {
            $mask.hide();
          }
        }
      } else {
        $.post('/collection_items/' + itemId + '/transplant_item', {
          src_collection_id: srcCollId,
          dest_collection_id: destCollId,
          old_index: oldIdx,
          new_index: newIndex
        }).fail(onError).always(function() { 
          if ($mask.length > 0) {
            $mask.hide();
          }
        });
      }
    });

    drake.on('cancel', function(el) {
      if (el) {
        var $container = $(el).closest('.container-fluid');
        var $mask = $container.find('.collection-mask');
        if ($mask.length > 0) {
          $mask.hide();
        }
      }
    });

    window.collectionDrakeInstance = drake;
    return drake;
  };

  // Initialize anthology dragula
  window.initializeAnthologyDragula = function(anthId) {
    var containerId = 'anth_texts';
    var container = document.getElementById(containerId);
    if (!container) return null;

    var drake = dragula([container], {
      moves: function(el, container, handle) {
        if (!handle || !handle.classList) return false;
        return handle.classList.contains('drag-handle') || handle.closest('.drag-handle');
      }
    });

    var oldIndex = null;

    drake.on('drag', function(el, source) {
      oldIndex = Array.from(el.parentNode.children).indexOf(el);
    });

    drake.on('drop', function(el, target, source, sibling) {
      if (!target) return;

      var newIndex = Array.from(el.parentNode.children).indexOf(el);
      var element_id = el.id.replace('anth_text_','');

      if (newIndex !== oldIndex) {
        var url = '/anthologies/' + anthId + '/update_seq';
        $.post(url, {
          id: anthId,
          anth_text_id: element_id,
          old_pos: oldIndex,
          new_pos: newIndex
        });
      }
    });

    return drake;
  };

  // Auto-initialize on document ready if elements are present
  $(document).ready(function() {
    // Initialize collection dragula if collection containers exist
    if (document.querySelectorAll('.collection.connectable').length > 0) {
      initializeCollectionDragula();
    }
  });
})();
