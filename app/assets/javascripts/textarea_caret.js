
/*
 * Scrolls a textarea so that the character at the given offset is comfortably in view.
 *
 * Browsers do not scroll a textarea to a caret placed with setSelectionRange, and soft
 * wrapping rules out finding the caret's line by counting newlines and multiplying by the
 * line height. So we measure it: an off-screen div is given the textarea's typography and
 * content width, filled with the text preceding the offset, and a marker span is appended
 * where the caret will land. The marker's offsetTop is the caret's Y position within the
 * textarea's text.
 *
 * Measuring rather than briefly rewriting textarea.value matters: assigning to value would
 * clear the browser's undo history for the editor.
 *
 * @param textarea - the textarea DOM element
 * @param offset - a character offset into textarea.value
 */
function scrollTextareaToOffset(textarea, offset) {
  const style = window.getComputedStyle(textarea);
  const paddingTop = parseFloat(style.paddingTop);
  const mirror = document.createElement('div');

  ['fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'fontVariant', 'lineHeight',
   'letterSpacing', 'wordSpacing', 'textIndent', 'textTransform', 'direction',
   'tabSize'].forEach(function(property) {
    mirror.style[property] = style[property];
  });
  // wrap exactly as the textarea does, at its content width, with no box of our own
  mirror.style.whiteSpace = 'pre-wrap';
  mirror.style.overflowWrap = 'break-word';
  mirror.style.width = (textarea.clientWidth - parseFloat(style.paddingLeft) -
                        parseFloat(style.paddingRight)) + 'px';
  mirror.style.margin = '0';
  mirror.style.padding = '0';
  mirror.style.border = '0';
  // positioned, so the marker's offsetTop is relative to the mirror
  mirror.style.position = 'absolute';
  mirror.style.top = '0';
  mirror.style.left = '-9999px';
  mirror.style.visibility = 'hidden';

  mirror.textContent = textarea.value.substring(0, offset);
  const marker = document.createElement('span');
  marker.textContent = '​'; // zero-width space: occupies the caret's line, shows nothing
  mirror.appendChild(marker);

  document.body.appendChild(mirror);
  const caretTop = marker.offsetTop;
  document.body.removeChild(mirror);

  // leave a third of the visible height above the line, for context
  textarea.scrollTop = Math.max(0, caretTop + paddingTop - textarea.clientHeight / 3);
}
