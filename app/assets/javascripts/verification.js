// Verification Workbench JavaScript

$(function() {
    // Initialize verification page if present
    if ($('.verification-container').length > 0) {
        initVerification();
    }
});

function initVerification() {
    const container = $('.verification-container');
    const entryId = container.data('verification-entry-id');
    const updateUrl = container.data('verification-update-url');
    const saveProgressUrl = container.data('verification-save-progress-url');

    // Handle checklist checkbox toggles
    $('.checklist-items input[type="checkbox"]').on('change', function() {
        const checkbox = $(this);
        const path = checkbox.data('path');
        const verified = checkbox.is(':checked');
        const sectionId = checkbox.data('section-id');

        updateChecklistItem(updateUrl, path, verified, sectionId);
    });

    // Handle "Save Progress" button
    $('#save-progress-btn').on('click', function(e) {
        e.preventDefault();
        const notes = $('#overall_notes').val();

        $.ajax({
            url: saveProgressUrl,
            type: 'PATCH',
            dataType: 'json',
            data: {
                overall_notes: notes
            },
            success: function(data) {
                showToast(data.message || 'התקדמות נשמרה');
            },
            error: function(xhr) {
                alert('Error saving progress: ' + xhr.status);
            }
        });
    });

    // Handle quick verify buttons on citations and links
    $('[data-action="click->verification#quickVerify"]').on('click', function(e) {
        e.preventDefault();
        const button = $(this);
        const path = button.data('path');
        const isCurrentlyVerified = button.hasClass('btn-success');
        const newVerified = !isCurrentlyVerified;

        updateChecklistItem(updateUrl, path, newVerified, null, function() {
            // Update button state
            if (newVerified) {
                button.removeClass('btn-outline-success').addClass('btn-success');
            } else {
                button.removeClass('btn-success').addClass('btn-outline-success');
            }

            // Update parent card
            const card = button.closest('.citation-card, .link-card');
            if (newVerified) {
                card.removeClass('not-verified').addClass('verified');
            } else {
                card.removeClass('verified').addClass('not-verified');
            }
        });
    });

    // Handle checklist label clicks - scroll to section
    $('.checklist-items label').on('click', function(e) {
        // Only scroll if clicked on label text, not checkbox
        if ($(e.target).is('input[type="checkbox"]')) {
            return;
        }

        const label = $(this);
        const checkbox = label.find('input[type="checkbox"]');
        const sectionId = checkbox.data('section-id');

        if (sectionId) {
            const section = $('#' + sectionId);
            if (section.length > 0) {
                // Scroll to section
                section[0].scrollIntoView({ behavior: 'smooth', block: 'start' });

                // Flash highlight
                section.addClass('highlight-flash');
                setTimeout(function() {
                    section.removeClass('highlight-flash');
                }, 2000);
            }
        }
    });
}

function updateChecklistItem(url, path, verified, sectionId, callback) {
    $.ajax({
        url: url,
        type: 'PATCH',
        dataType: 'json',
        data: {
            path: path,
            verified: verified,
            notes: ''
        },
        success: function(data) {
            // Update progress bar
            updateProgressBar(data.percentage);

            // Update mark verified button state
            updateMarkVerifiedButton(data.complete);

            // Update section styling if sectionId provided
            if (sectionId) {
                const section = $('#' + sectionId);
                if (section.length > 0) {
                    if (verified) {
                        section.removeClass('not-verified').addClass('verified');
                        section.find('.verification-badge')
                            .removeClass('not-verified')
                            .addClass('verified')
                            .text('✓ מאומת');
                    } else {
                        section.removeClass('verified').addClass('not-verified');
                        section.find('.verification-badge')
                            .removeClass('verified')
                            .addClass('not-verified')
                            .text('לא אומת');
                    }
                }
            }

            // Show toast
            showToast('נשמר');

            // Call callback if provided
            if (callback && typeof callback === 'function') {
                callback();
            }
        },
        error: function(xhr) {
            alert('Error updating checklist: ' + xhr.status);
        }
    });
}

function updateProgressBar(percentage) {
    const progressBar = $('#main-progress-bar');
    const progressText = progressBar.parent().prev('strong');

    progressBar.css('width', percentage + '%')
        .attr('aria-valuenow', percentage)
        .text(percentage + '%');

    if (progressText.length > 0) {
        progressText.text(percentage + '%');
    }
}

function updateMarkVerifiedButton(complete) {
    const button = $('#mark-verified-btn');
    if (complete) {
        button.prop('disabled', false);
    } else {
        button.prop('disabled', true);
    }
}

function showToast(message) {
    const toast = $('<div class="toast-notification"></div>').text(message);
    $('body').append(toast);

    setTimeout(function() {
        toast.remove();
    }, 3000);
}

// Callback for when a section is edited and saved
function onSectionEditSuccess(sectionId) {
    return function(data, status, xhr) {
        if (data.success) {
            // Update progress bar if percentage provided
            if (data.percentage !== undefined) {
                updateProgressBar(data.percentage);
                updateMarkVerifiedButton(data.complete);
            }

            // Update the section's verification badge
            const section = $('#' + sectionId);
            if (section.length > 0) {
                section.removeClass('not-verified').addClass('verified');
                section.find('.verification-badge')
                    .removeClass('not-verified')
                    .addClass('verified')
                    .text('✓ מאומת');
            }

            // Update the corresponding checklist checkbox
            const checkboxPath = sectionId.replace('section-', '');
            const checkbox = $('input[data-section-id="' + sectionId + '"]');
            if (checkbox.length > 0) {
                checkbox.prop('checked', true);
            }

            // For title section of LexPerson, also update life_years checkbox
            if (sectionId === 'section-title') {
                const lifeYearsCheckbox = $('input[data-section-id="section-life-years"]');
                if (lifeYearsCheckbox.length > 0) {
                    lifeYearsCheckbox.prop('checked', true);
                }
            }

            // Show success message
            showToast(data.message || 'נשמר בהצלחה');

            // Reload the page to show updated content
            // This ensures the section content is refreshed with the new data
            setTimeout(function() {
                location.reload();
            }, 500);
        }
    };
}

// Override modal close callback to reload relevant sections
function closeModalWithReload(reloadSelector) {
    $('#generalDlg').modal('hide');
    $('#generalDlg').data('onSuccess', null);

    if (reloadSelector) {
        const element = $(reloadSelector);
        if (element.length > 0) {
            // Reload the section or trigger a refresh
            location.reload(); // Simple approach - reload entire page
        }
    }
}
