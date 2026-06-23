// Verification Workbench JavaScript

$(function() {
    // Initialize verification page if present
    if ($('.verification-container').length > 0) {
        initVerification();
    }
});

function initVerification() {
    const container = $('.verification-container');

    // Make the checklist modal draggable/resizable, matching the #generalDlg modals.
    if (typeof initModalManipulation === 'function') {
        initModalManipulation('#checklistModal');
    }

    const entryId = container.data('verification-entry-id');
    const updateUrl = container.data('verification-update-url');
    const saveProgressUrl = container.data('verification-save-progress-url');

    // Show link-check toast after a citation link edit + page reload.
    // sessionStorage is set by update.js.erb before location.reload(); flash data-attributes
    // are kept as a fallback for non-JS flows.
    const linkCheckToastType = sessionStorage.getItem('link-check-toast-type') || container.data('link-check-toast-type');
    const linkCheckToastMessage = sessionStorage.getItem('link-check-toast-message') || container.data('link-check-toast-message');
    if (linkCheckToastType && linkCheckToastMessage) {
        sessionStorage.removeItem('link-check-toast-type');
        sessionStorage.removeItem('link-check-toast-message');
        showToast(linkCheckToastMessage, linkCheckToastType);
    }

    // Remove legacy key left by older code versions (no-op if already absent).
    sessionStorage.removeItem('source_scroll_top');

    // Restore source iframe scroll position after any page reload.
    // Chromium-based browsers (Chrome, Edge) do not auto-preserve iframe internal
    // scroll across reloads (unlike Firefox which restores it via session history),
    // so we save/restore iframe.contentWindow.scrollY explicitly.
    var savedIframeScroll = sessionStorage.getItem('source_iframe_scroll_y');
    if (savedIframeScroll !== null) {
        sessionStorage.removeItem('source_iframe_scroll_y');
        var iframeScrollY = parseInt(savedIframeScroll, 10);
        if (iframeScrollY > 0) {
            var iframe = document.querySelector('.source-iframe');
            if (iframe) {
                var applyIframeScroll = function() {
                    try { iframe.contentWindow.scrollTo(0, iframeScrollY); } catch (e) {}
                };
                // Always register the load listener so we catch the src loading after
                // DOMContentLoaded.  The readyState === 'complete' check alone is a
                // false positive: the initial about:blank document reports 'complete'
                // before the real src has even started loading.
                iframe.addEventListener('load', applyIframeScroll);
                // Also apply immediately if the iframe already holds real source content
                // (e.g. loaded from cache before DOMContentLoaded fired).
                try {
                    if (iframe.contentDocument &&
                            iframe.contentDocument.readyState === 'complete' &&
                            iframe.contentWindow.location.href !== 'about:blank') {
                        applyIframeScroll();
                    }
                } catch (e) {}
            }
        }
    }

    // Scroll to a section after a work edit + page reload, OR restore migrated pane scroll.
    // section scroll takes precedence; plain scroll restore is used when no section is targeted.
    // Must scroll .migrated-content directly (the grid pane has overflow: hidden; the
    // window itself does not scroll in this layout, so scrollIntoView targets the wrong element).
    const scrollToSection = sessionStorage.getItem('scroll_to_section');
    const savedMigratedScroll = sessionStorage.getItem('migrated_scroll_top');
    if (scrollToSection) {
        sessionStorage.removeItem('scroll_to_section');
        sessionStorage.removeItem('migrated_scroll_top');
        setTimeout(function() {
            var el = document.getElementById(scrollToSection);
            if (!el) return;
            var scrollParent = el.closest('.migrated-content');
            if (scrollParent) {
                var offset = el.getBoundingClientRect().top
                           - scrollParent.getBoundingClientRect().top
                           + scrollParent.scrollTop;
                scrollParent.scrollTop = Math.max(0, offset - 8);
            } else {
                el.scrollIntoView({ block: 'start' });
            }
        }, 150);
    } else if (savedMigratedScroll !== null) {
        sessionStorage.removeItem('migrated_scroll_top');
        var migratedScrollVal = parseInt(savedMigratedScroll, 10);
        if (migratedScrollVal > 0) {
            var migratedContent = document.querySelector('.migrated-content');
            if (migratedContent) {
                // Use rAF-based retry instead of a fixed timeout so that layout changes
                // (e.g. Edge applying its own scroll restoration after JS runs) are
                // detected and corrected within ~500 ms across all browsers.
                restoreScrollWithRetry(migratedContent, migratedScrollVal);
            }
        }
    }

    // Handle checklist checkbox toggles
    $('.checklist-items input[type="checkbox"]').on('change', function() {
        const checkbox = $(this);
        const path = checkbox.data('path');
        const verified = checkbox.is(':checked');
        const sectionId = checkbox.data('section-id');

        updateChecklistItem(updateUrl, path, verified, sectionId);
    });

    // Handle "Overall Notes" auto-save
    $('#overall_notes').on('blur', function() {
        const notes = $(this).val();

        $.ajax({
            url: saveProgressUrl,
            type: 'PATCH',
            dataType: 'json',
            data: {
                overall_notes: notes
            },
            success: function(data) {
                showToast(data.message || container.data('progress-saved-text'));
            },
            error: function(xhr) {
                var statusInfo = xhr && xhr.status ? ' (' + xhr.status + ')' : '';
                showToast((container.data('error-saving-progress-text') || 'Error saving progress') + statusInfo);
            }
        });
    });

    // Handle "Escalate" button
    $('#escalate-btn').on('click', function(e) {
        e.preventDefault();
        const escalateFormUrl = container.data('verification-escalate-form-url');
        const currentNotes = $('#overall_notes').val() || '';

        // Populate the modal's notes field after the modal opens so notes never
        // appear in the URL (browser history, server logs, referrers).
        $('#generalDlg').one('shown.bs.modal', function() {
            $('#escalate_overall_notes').val(currentNotes);
        });

        openModal(escalateFormUrl, function(data) {
            if (data && data.redirect_url) {
                window.location.href = data.redirect_url;
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
            setTimeout(reloadPage, 300);
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
                var useAsProfileText = container.data('use-as-profile-text') || 'Use as Profile';
                $('[data-action="click->verification#setProfileImage"]').each(function() {
                    $(this).removeClass('btn-primary').addClass('btn-outline-primary').text(useAsProfileText);
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

                showToast(container.data('profile-image-set-text') || 'Profile image set successfully');
            },
            error: function(xhr) {
                var statusInfo = xhr && xhr.status ? ' (' + xhr.status + ')' : '';
                showToast((container.data('error-setting-profile-image-text') || 'Error setting profile image') + statusInfo);
            }
        });
    });

    // Handle general "Report to Monday" button — opens a modal with a textarea
    $('#monday-report-btn').on('click', function() {
        $('#monday-report-description').val('');
        $('#mondayReportModal').modal('show');
    });

    $('#monday-report-submit').on('click', function() {
        var btn = $(this);
        var reportUrl = $('#monday-report-btn').data('report-url');
        var description = $('#monday-report-description').val();

        btn.prop('disabled', true);
        $.ajax({
            url: reportUrl,
            type: 'POST',
            dataType: 'json',
            headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
            data: { type: 'general', description: description },
            success: function(data) {
                $('#mondayReportModal').modal('hide');
                showToast(data.message);
            },
            error: function(xhr) {
                var err = (xhr.responseJSON && xhr.responseJSON.error) || 'Error sending report';
                showToast(err);
            },
            complete: function() {
                btn.prop('disabled', false);
            }
        });
    });

    // Handle per-work "missing work" report buttons
    $(document).on('click', '.monday-missing-work-btn', function() {
        var btn = $(this);
        var reportUrl = btn.data('report-url');
        var workTitle = btn.data('work-title');

        btn.prop('disabled', true);
        $.ajax({
            url: reportUrl,
            type: 'POST',
            dataType: 'json',
            headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
            data: { type: 'missing_work', work_title: workTitle },
            success: function(data) {
                showToast(data.message);
            },
            error: function(xhr) {
                var err = (xhr.responseJSON && xhr.responseJSON.error) || 'Error sending report';
                showToast(err);
                btn.prop('disabled', false);
            }
        });
    });

    // Handle remove attachment buttons
    $('[data-action="click->verification#removeAttachment"]').on('click', function(e) {
        e.preventDefault();
        const button = $(this);
        const attachmentId = button.data('attachment-id');
        const removeAttachmentUrl = container.data('verification-remove-attachment-url');

        $.ajax({
            url: removeAttachmentUrl,
            type: 'POST',
            dataType: 'json',
            headers: {
                'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
            },
            data: {
                _method: 'delete',
                attachment_id: attachmentId
            },
            success: function() {
                $('#attachment-' + attachmentId).remove();
                showToast(container.data('attachment-removed-text') || 'Attachment removed');
            },
            error: function(xhr) {
                var statusInfo = xhr && xhr.status ? ' (' + xhr.status + ')' : '';
                showToast((container.data('error-removing-attachment-text') || 'Error removing attachment') + statusInfo);
            }
        });
    });

    // Handle checklist label clicks - close the checklist modal then scroll to section
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
            if (section.length === 0) { return; }

            const scrollToTarget = function() {
                var scrollParent = section[0].closest('.migrated-content');
                if (scrollParent) {
                    var offset = section[0].getBoundingClientRect().top
                               - scrollParent.getBoundingClientRect().top
                               + scrollParent.scrollTop;
                    scrollParent.scrollTop = Math.max(0, offset - 8);
                } else {
                    section[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
                section.addClass('highlight-flash');
                setTimeout(function() { section.removeClass('highlight-flash'); }, 2000);
            };

            const checklistModal = $('#checklistModal');
            if (checklistModal.hasClass('show')) {
                checklistModal.one('hidden.bs.modal', scrollToTarget);
                checklistModal.modal('hide');
            } else {
                scrollToTarget();
            }
        }
    });

    // Handle hide/show verified items toggle
    const hideVerifiedToggle = $('#hide-verified-toggle');

    // Restore checkbox state from localStorage
    const savedHideVerified = localStorage.getItem('hideVerifiedItems') === 'true';
    if (savedHideVerified) {
        hideVerifiedToggle.prop('checked', true);
    }

    // Apply hiding behavior based on current checkbox state (including restored state)
    function applyHideVerifiedState() {
        const hideVerified = hideVerifiedToggle.is(':checked');

        if (hideVerified) {
            // Hide verified sections in the migrated entry view
            $('.verification-section.verified').addClass('hidden-verified');

            // Hide verified checklist items (both top-level and nested)
            $('.checklist-items input[type="checkbox"]:checked').closest('li').addClass('hidden-verified');

            // Hide verified citation and link cards
            $('.citation-card.verified, .link-card.verified, .work-card.verified').addClass('hidden-verified');
        } else {
            // Show all items
            $('.hidden-verified').removeClass('hidden-verified');
        }
    }

    // Apply state on page load
    applyHideVerifiedState();

    // Handle checkbox changes
    hideVerifiedToggle.on('change', function() {
        const hideVerified = $(this).is(':checked');

        // Save state to localStorage
        localStorage.setItem('hideVerifiedItems', hideVerified);

        // Apply the hiding/showing behavior
        applyHideVerifiedState();
    });
}

function updateChecklistItem(url, path, verified, sectionId, callback) {
    const container = $('.verification-container');
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
                            .text(container.data('verified-badge-text') || '✓ Verified');
                    } else {
                        section.removeClass('verified').addClass('not-verified');
                        section.find('.verification-badge')
                            .removeClass('verified')
                            .addClass('not-verified')
                            .text(container.data('not-verified-badge-text') || 'Not Verified');
                    }
                }
            }

            // Show toast
            showToast(container.data('saved-text') || 'Saved');

            // Call callback if provided
            if (callback && typeof callback === 'function') {
                callback();
            }
        },
        error: function(xhr) {
            var statusInfo = xhr && xhr.status ? ' (' + xhr.status + ')' : '';
            showToast((container.data('error-updating-checklist-text') || 'Error updating checklist') + statusInfo);
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

function showToast(message, type) {
    const toast = $('<div class="toast-notification"></div>');
    if (type) toast.addClass('toast-' + type);
    toast.text(message);
    $('body').append(toast);

    setTimeout(function() {
        toast.remove();
    }, 3000);
}

// Callback for when a section is edited and saved
function onSectionEditSuccess(sectionId) {
    const container = $('.verification-container');
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
                    .text(container.data('verified-badge-text') || '✓ Verified');
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
            showToast(data.message || container.data('section-updated-text'));

            // Reload the page to show updated content
            setTimeout(reloadPage, 500);
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
            reloadPage();
        }
    }
}

// Save both pane scroll positions before any reload.
// For the source pane we save the iframe's internal scrollY, not the outer
// container's scrollTop, because the meaningful scroll is inside the iframe.
function saveScrollPositions() {
    var iframe = document.querySelector('.source-iframe');
    if (iframe) {
        try {
            sessionStorage.setItem('source_iframe_scroll_y', String(iframe.contentWindow.scrollY || 0));
        } catch (e) {}
    }
    var migratedContent = document.querySelector('.migrated-content');
    if (migratedContent) {
        sessionStorage.setItem('migrated_scroll_top', String(migratedContent.scrollTop));
    }
}

// Retry setting scrollTop on every animation frame until it takes effect or 500 ms
// elapses.  A fixed setTimeout(100) is not reliable on some browsers (e.g. Edge)
// where the browser's own scroll-restoration can run and override our value after
// DOMContentLoaded but before the first paint.
function restoreScrollWithRetry(el, scrollVal) {
    var deadline = Date.now() + 500;
    function tryScroll() {
        el.scrollTop = scrollVal;
        if (el.scrollTop < scrollVal - 1 && Date.now() < deadline) {
            requestAnimationFrame(tryScroll);
        }
    }
    requestAnimationFrame(tryScroll);
}

// Open the per-work edit form as a non-modal panel.
// Unlike openModal(), this version uses backdrop:false and makes the overlay
// transparent to pointer events so the source (PHP) pane remains interactive.
// Esc still dismisses the panel via Bootstrap's keyboard:true option.
function openWorkEditPanel(path, onSuccess) {
    $('#generalDlg').data('onSuccess', onSuccess);

    $.get(path).done(function(htmlContent) {
        setupModalContent(htmlContent);

        // Apply non-modal class before show so CSS takes effect from the first frame.
        $('#generalDlg').addClass('no-modal-mode');

        $('#generalDlg').modal({ show: true, keyboard: true, backdrop: false, focus: false });
        // Bootstrap 4 adds 'modal-open' to <body> synchronously inside show().
        // Remove it immediately so background scrolling/interaction stays available.
        $('body').removeClass('modal-open');

        $('#generalDlg').one('hidden.bs.modal', function() {
            $(this).removeClass('no-modal-mode');
        });
    }).fail(function(xhr, status, error) {
        alert('Failed to load: ' + status + ' - ' + error);
    });
}

// Reload the page, preserving source pane scroll position
function reloadPage() {
    saveScrollPositions();
    location.reload();
}

// Reload the page, preserving source pane scroll and scrolling migrated pane to a section
function reloadScrollingToSection(sectionId) {
    saveScrollPositions();
    sessionStorage.setItem('scroll_to_section', sectionId);
    location.reload();
}

// Confirm an auto-matched work-to-publication proposal
function confirmWorkMatch(button) {
    var $btn = $(button);
    var workId = $btn.data('work-id');
    var publicationId = $btn.data('publication-id');
    var collectionId = $btn.data('collection-id');
    var confirmUrl = $btn.data('confirm-url');

    $btn.prop('disabled', true);

    $.ajax({
        url: confirmUrl,
        type: 'PATCH',
        dataType: 'json',
        headers: {
            'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
        },
        data: {
            work_id: workId,
            publication_id: publicationId,
            collection_id: collectionId || ''
        },
        success: function(data) {
            // Keep the modal open so the reviewer can approve (or skip) the
            // remaining proposals. Mark just this row as confirmed.
            var $row = $('#match-row-' + workId);
            $row.addClass('text-muted');
            $row.find('.match-actions').html(
                $('<span>', { 'class': 'text-success font-weight-bold', text: '✓ ' + (data.message || '') })
            );
            showToast(data.message);
            // Refresh the works section once, when the reviewer closes the modal,
            // so the underlying page reflects the confirmed matches.
            $('#generalDlg')
                .off('hidden.bs.modal.workmatch')
                .one('hidden.bs.modal.workmatch', function() {
                    reloadScrollingToSection('section-works');
                });
        },
        error: function(xhr) {
            $btn.prop('disabled', false);
            var err = (xhr.responseJSON && xhr.responseJSON.error) || 'Error confirming match';
            showToast(err);
        }
    });
}
