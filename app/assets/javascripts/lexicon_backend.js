//= require jquery3
//= require rails-ujs

function openModal(path, onSuccess = null) {
	$('#generalDlgBody').load(path, function(response, status, _xhr) {
		if (status === "success") {
			setupModalContent();
			setupModalFormHandlers(onSuccess);
			$('#generalDlg').modal('show');
		} else {
			alert('Failed to load modal: ' + status);
		}
	});
}

function setupModalContent() {
	var title = '';
	var h1 = $('#generalDlgBody').find('h1').first();
	if (h1.length > 0) {
		title = h1.text();
		h1.remove();
	}
	$('#generalDlg .modal-title').text(title);
}

function setupModalFormHandlers(onSuccess) {
	const form = $('#generalDlgBody').find('form[data-remote="true"]');

    if (form.length == 0) return;

    form.off('ajax:success ajax:error');

    form.on('ajax:success', function(event) {
        const [data, status, xhr] = event.detail;
        $('#generalDlg').modal('hide');
        if (onSuccess && typeof onSuccess === 'function') {
            onSuccess(data, status, xhr);
        }
    });

    form.on('ajax:error', function(event) {
        const [_data, _status, xhr] = event.detail;
        if (xhr.status == 422) { // we got a validation error, so re-render form
            $('#generalDlgBody').html(xhr.responseText);
            setupModalContent();
            setupModalFormHandlers(onSuccess);
        }
    });
}