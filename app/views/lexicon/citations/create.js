if ($('#citations').length) {
  // Entry-edit view: lazy-reload just the citations section
  reloadContent($('#citations'));
} else {
  // Verification view: the new card belongs in the migrated pane, so reload the page
  reloadPage();
}
