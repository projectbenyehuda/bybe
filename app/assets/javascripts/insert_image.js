
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

function sanitizeImageUrl(rawUrl) {
  if (!rawUrl) return null;
  try {
    const parsed = new URL(rawUrl, window.location.origin);
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
      return parsed.href;
    }
  } catch (e) {
    // Invalid URL: ignore
  }
  return null;
}

function imageTagFromOption(option) {
  const $opt = $(option);
  // Use DOM API so width/height become HTML attributes (not inline styles).
  // jQuery's $('<img>', {width, height}) routes through .width()/.height(),
  // which sets style="width:Xpx" instead of the width="X" attribute.
  const img = document.createElement('img');
  const safeSrc = sanitizeImageUrl($opt.val());
  if (!safeSrc) return '';
  img.src = safeSrc;
  img.alt = $opt.text().trim();
  const width = $opt.data('width');
  const height = $opt.data('height');
  if (width) img.setAttribute('width', width);
  if (height) img.setAttribute('height', height);
  return img.outerHTML;
}
