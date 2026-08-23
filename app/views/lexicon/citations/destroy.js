if ($('#citations').length) {
  // Entry-edit view: lazy-reload just the citations section
  reloadContent($('#citations'));
} else {
  // Verification view: the deleted card lives in the migrated pane, so reload the page
  reloadPage();
}
