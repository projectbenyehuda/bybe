//= require jquery3
//= require rails-ujs
//= require autocomplete_init
//= require sortable.min
//= require verification
//= require bootstrap-rtl-4.2.1.bundle.min

$(function() {
    // Firefox paint bug: <select> options appear blank when the element was injected into a
    // display:none container. Force a reflow after the modal finishes showing so Gecko repaints.
    $('#generalDlg').on('shown.bs.modal', function() {
        if (navigator.userAgent.indexOf('Firefox') === -1) return;

        $(this).find('select').each(function() {
            var savedValue = this.value;
            var savedDisplay = this.style.display;
            this.style.display = 'none';
            this.getBoundingClientRect(); // triggers synchronous layout → repaint
            this.style.display = savedDisplay;
            this.value = savedValue;
        });
    });

    initModalManipulation();

    $('a[data-toggle="tab"]').on('show.bs.tab', function (e) {
        const tabHeader = $(e.target);
        const tabContentId = tabHeader.data('target');

        if (tabContentId == null) {
            console.warn('bs-target not found for tab header: #' + tabHeader.id);
            return;
        }

        const tabContent = $(tabContentId);
        if (tabContent.data('load-url') != null && !tabContent.data('load-complete')) {
            reloadContent(tabContent);
        }
    });
});

function reloadContent(tabContent) {
    if (!tabContent.length) return;
    const loadUrl = tabContent.data('load-url');
    if (!loadUrl) return;
    tabContent.load(
        loadUrl,
        function( response, status, xhr ) {
            if ( status == 'error' ) {
                let content = '<h2 class="text-danger">Error: ' + xhr.status + " " + xhr.statusText + '</h2>';
                if (xhr.status == '423') {
                  // Message about locked object
                  content += '<h3>' + xhr.responseText + '</h3>';
                }
                tabContent.html(content);
                tabContent.data('load-complete', null);
            } else {
                tabContent.data('load-complete', true);
            }
        }
    );

}

function openModal(path, onSuccess = null) {
    $('#generalDlg').data('onSuccess', onSuccess);

    $.get(path).done(function(htmlContent) {
        setupModalContent(htmlContent);
        $('#generalDlg').modal({show: true, keyboard: true});
    }).fail(function(xhr, status, error) {
        alert('Failed to load modal: ' + status + ' - ' + error);
    });
}

function setupModalContent(content) {
    $('#generalDlgBody').html(content);

    $('#generalDlgBody [data-ajax-url]').each(function() {
        $(this).load($(this).data('ajax-url'));
    });

    // Extracting title from content
	var title = '';
	var h1 = $('#generalDlgBody').find('h1').first();
	if (h1.length > 0) {
		title = h1.text();
		h1.remove();
	}
	$('#generalDlg .modal-title').text(title);

    // Setting form handlers
    const form = $('#generalDlgBody').find('form[data-remote="true"]');
    const onSuccess = $('#generalDlg').data('onSuccess');

    if (form.length == 0) return;

    form.off('ajax:success ajax:error');

    form.on('ajax:success', function(event) {
        const [data, status, xhr] = event.detail;
        closeModal();
        if (onSuccess && typeof onSuccess === 'function') {
            onSuccess(data, status, xhr);
        }
    });

    form.on('ajax:error', function(event) {
        const [_data, _status, xhr] = event.detail;
        if (xhr.status == 422) { // we got a validation error, so re-render form
            setupModalContent(xhr.responseText);
        } else {
            alert('Unexpected error: ' + xhr.status);
        }
    });
}

function closeModal() {
    $('#generalDlg').modal('hide');
    $('#generalDlg').data('onSuccess', null);
};

function initModalManipulation() {
    var $modal = $('#generalDlg');
    if (!$modal.length) return;

    var $dialog = $modal.find('.modal-dialog');
    var $content = $modal.find('.modal-content');

    // Inject resize handle CSS once
    $('head').append(
        '<style id="generalDlg-manip-style">' +
        '#generalDlg .modal-resize-handle{position:absolute;z-index:10;}' +
        '#generalDlg .modal-resize-handle.dlg-n {top:-3px;left:12px;right:12px;height:6px;cursor:n-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-s {bottom:-3px;left:12px;right:12px;height:6px;cursor:s-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-e {right:-3px;top:12px;bottom:12px;width:6px;cursor:e-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-w {left:-3px;top:12px;bottom:12px;width:6px;cursor:w-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-ne{top:-3px;right:-3px;width:14px;height:14px;cursor:ne-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-se{bottom:-3px;right:-3px;width:14px;height:14px;cursor:se-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-sw{bottom:-3px;left:-3px;width:14px;height:14px;cursor:sw-resize;}' +
        '#generalDlg .modal-resize-handle.dlg-nw{top:-3px;left:-3px;width:14px;height:14px;cursor:nw-resize;}' +
        '</style>'
    );

    $.each(['n','ne','e','se','s','sw','w','nw'], function(_, dir) {
        $content.append('<div class="modal-resize-handle dlg-' + dir + '"></div>');
    });

    var MIN_W = 300, MIN_H = 100;

    // Switch dialog to absolute positioning, locked at current viewport position
    function lockAbsolute() {
        if ($dialog.css('position') === 'absolute') return;
        var rect = $dialog[0].getBoundingClientRect();
        $dialog.css({ position: 'absolute', margin: '0', transform: 'none',
                      top: rect.top + 'px', left: rect.left + 'px' });
    }

    // --- Drag (header) ---
    var dragStartX, dragStartY, dragStartLeft, dragStartTop;

    $modal.on('mousedown', '.modal-header', function(e) {
        if ($(e.target).closest('button, a').length) return;

        lockAbsolute();
        dragStartX    = e.clientX;
        dragStartY    = e.clientY;
        dragStartLeft = parseFloat($dialog.css('left')) || 0;
        dragStartTop  = parseFloat($dialog.css('top'))  || 0;

        $(document).on('mousemove.dlgDrag', function(e) {
            $dialog.css({
                left: (dragStartLeft + e.clientX - dragStartX) + 'px',
                top:  (dragStartTop  + e.clientY - dragStartY) + 'px'
            });
        });
        $(document).on('mouseup.dlgDrag', function() {
            $(document).off('mousemove.dlgDrag mouseup.dlgDrag');
        });
        e.preventDefault();
    });

    // --- Resize (handles) ---
    var resizeStartX, resizeStartY, startW, startH, startLeft, startTop, resizeDir;

    $modal.on('mousedown', '.modal-resize-handle', function(e) {
        resizeDir = $(this).attr('class').match(/dlg-(\w+)/)[1];

        // Capture sizes before locking (max-height may still cap the height)
        startH = $content.outerHeight();
        startW = $dialog.outerWidth();

        lockAbsolute();
        startLeft = parseFloat($dialog.css('left')) || 0;
        startTop  = parseFloat($dialog.css('top'))  || 0;

        // Freeze explicit dimensions so CSS rules no longer interfere
        $content.css({ 'max-height': 'none', height: startH + 'px' });
        $dialog.css({ 'max-width': 'none', width: startW + 'px' });

        resizeStartX = e.clientX;
        resizeStartY = e.clientY;

        $(document).on('mousemove.dlgResize', function(e) {
            var dx = e.clientX - resizeStartX;
            var dy = e.clientY - resizeStartY;
            var nW = startW, nH = startH, nL = startLeft, nT = startTop;

            if (resizeDir.indexOf('e') >= 0) nW = Math.max(MIN_W, startW + dx);
            if (resizeDir.indexOf('w') >= 0) { nW = Math.max(MIN_W, startW - dx); nL = startLeft + startW - nW; }
            if (resizeDir.indexOf('s') >= 0) nH = Math.max(MIN_H, startH + dy);
            if (resizeDir.indexOf('n') >= 0) { nH = Math.max(MIN_H, startH - dy); nT = startTop + startH - nH; }

            $dialog.css({ top: nT + 'px', left: nL + 'px', width: nW + 'px' });
            $content.css({ height: nH + 'px' });
        });
        $(document).on('mouseup.dlgResize', function() {
            $(document).off('mousemove.dlgResize mouseup.dlgResize');
        });

        e.preventDefault();
        e.stopPropagation();
    });

    // --- Reset on close ---
    $modal.on('hidden.bs.modal', function() {
        $dialog.css({ position: '', margin: '', transform: '', top: '', left: '', width: '', 'max-width': '' });
        $content.css({ height: '', 'max-height': '' });
    });
}
