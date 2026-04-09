
/*
 * Function used to insert image tag into a markdown TextArea.
 * The image tag is generated from the selected item in the ddslick dropdown.
 * @param textAreaSelector - the selector of the TextArea where the image tag should be inserted (e.g. '#markdown')
 * @param ddslickDropDownSelector - the selector of the ddslick dropdown (e.g. '#images')
 */
function insertImageFromDDSlick(textAreaSelector, ddslickDropDownSelector) {
  const $txt = $(textAreaSelector);
  const caretPos = $txt[0].selectionStart;
  const scrollLeft = $txt[0].scrollLeft;
  const scrollTop  = $txt[0].scrollTop;
  const textAreaTxt = $txt.val();

  const ddData = $(ddslickDropDownSelector).data('ddslick');
  const $selectedOption = ddData.original.find('option:selected');
  const txtToAdd = "\n" + imageTagFromOption($selectedOption) + "\n";
  $txt.val(textAreaTxt.substring(0, caretPos) + txtToAdd + textAreaTxt.substring(caretPos) );
  $txt.focus();
  $txt.caretTo(caretPos+txtToAdd.length);
  $txt[0].scrollTo(scrollLeft, scrollTop); // restore scroll position
}

function imageTagFromOption(option) {
  const $opt = $(option);
  const attrs = {
    src: $opt.val(),
    alt: $opt.text().trim()
  };
  const width = $opt.data('width');
  const height = $opt.data('height');
  if (width) attrs.width = width;
  if (height) attrs.height = height;
  return $('<img>', attrs)[0].outerHTML;
}
