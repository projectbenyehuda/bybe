//= require jquery3
//= require rails-ujs

function openModal(path, onSuccess = null) {
    $('#generalDlg').data('onSuccess', onSuccess);

    $.get(path).done(function(htmlContent) {
        setupModalContent(htmlContent);
        $('#generalDlg').modal('show');
    }).fail(function(xhr, status, error) {
        alert('Failed to load modal: ' + status + ' - ' + error);
    });
}

function setupModalContent(content) {
    $('#generalDlgBody').html(content);

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
