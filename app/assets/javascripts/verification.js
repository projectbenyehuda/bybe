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

            // Update the corresponding checklist checkbox
            const checkbox = $('.checklist-items input[data-path="' + path + '"]');
            if (checkbox.length > 0) {
                checkbox.prop('checked', newVerified);
            }
        });
    });

    // Handle set profile image buttons
    $('[data-action="click->verification#setProfileImage"]').on('click', function(e) {
        e.preventDefault();
        const button = $(this);
        const attachmentId = button.data('attachment-id');
        const setProfileImageUrl = container.data('verification-set-profile-image-url');
        const profileImageBadgeText = container.data('profile-image-badge-text') || 'Profile Image';

        $.ajax({
            url: setProfileImageUrl,
            type: 'PATCH',
            dataType: 'json',
            headers: {
                'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
            },
            data: {
                attachment_id: attachmentId
            },
            success: function(data) {
                // Update all attachment buttons to show as not selected
                $('[data-action="click->verification#setProfileImage"]').each(function() {
                    $(this).removeClass('btn-primary').addClass('btn-outline-primary').text('Use as Profile');
                });

                // Update clicked button to show as selected
                button.removeClass('btn-outline-primary').addClass('btn-primary').text('✓ ' + profileImageBadgeText);

                // Remove all profile-image-selected classes
                $('.attachment-item').removeClass('profile-image-selected');

                // Add profile-image-selected class to the selected attachment
                $('#attachment-' + attachmentId).addClass('profile-image-selected');

                // Remove all "Profile Image" badges
                $('.attachment-info .profile-image-badge').remove();

                // Add "Profile Image" badge to the selected attachment
                $('#attachment-' + attachmentId + ' .attachment-info')
                    .append('<span class="badge profile-image-badge bg-primary ms-2">' + profileImageBadgeText + '</span>');

                showToast('Profile image set successfully');
            },
            error: function(xhr) {
                var statusInfo = xhr && xhr.status ? ' (status ' + xhr.status + ')' : '';
                showToast('Error setting profile image' + statusInfo);
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

    // Handle hide/show verified items toggle
    $('#hide-verified-toggle').on('change', function() {
        const hideVerified = $(this).is(':checked');

        if (hideVerified) {
            // Hide verified sections in the migrated entry view
            $('.verification-section.verified').addClass('hidden-verified');

            // Hide verified checklist items (both top-level and nested)
            $('.checklist-items input[type="checkbox"]:checked').closest('li').addClass('hidden-verified');

            // Hide verified citation and link cards
            $('.citation-card.verified, .link-card.verified').addClass('hidden-verified');
        } else {
            // Show all items
            $('.hidden-verified').removeClass('hidden-verified');
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
