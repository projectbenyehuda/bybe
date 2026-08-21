if ($('#links').length) {
  // Entry-edit view: lazy-reload just the links section
  reloadContent($('#links'));
} else {
  // Verification view: the deleted card lives in the migrated pane, so reload the page
  reloadPage();
}
