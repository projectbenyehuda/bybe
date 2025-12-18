# DOCX Bold Text Conversion Issue - Root Cause & Solution

## Problem Summary

After upgrading pandoc from 3.1.3 to 3.8.3 on December 6, 2025, bold text in DOCX files was not being properly converted to Markdown format.

## Root Cause

**This is NOT a pandoc version issue.** Both versions have the same limitation.

The real issue is **OOXML style inheritance**:

1. Some DOCX files use **paragraph styles** that define bold formatting
2. Individual text runs **inherit** this bold from the paragraph style
3. The runs have NO explicit `<w:b>` tags in their properties
4. **LibreOffice/Word**: Correctly inherit and display bold text ✓
5. **Pandoc & python-docx**: Only look at direct run formatting, ignore style inheritance ✗

### Technical Details

In OOXML (Office Open XML), paragraph styles can define default formatting:

```xml
<!-- Paragraph style with bold enabled -->
<w:style w:styleId="a4">
  <w:rPr>
    <w:b/>          <!-- No val attribute = TRUE = bold ON -->
    <w:bCs/>        <!-- Bold for complex scripts -->
  </w:rPr>
</w:style>
```

Text runs can either:
1. **Explicitly override**: `<w:b w:val="0"/>` (bold OFF)
2. **Inherit from style**: No `<w:b>` tag (inherits parent style's bold)

Pandoc only recognizes explicit bold tags on runs, missing inherited formatting.

## Solution

Created script: `bin/fix_docx_formatting.py`

This script:
1. Parses the DOCX OOXML structure
2. Reads paragraph style formatting properties
3. For each run without explicit formatting tags, adds them based on inherited style
4. Creates a backup before modifying

### Usage

```bash
# Fix in-place (creates .backup file)
python3 bin/fix_docx_formatting.py input.docx

# Save to new file
python3 bin/fix_docx_formatting.py input.docx output.docx

# Quiet mode
python3 bin/fix_docx_formatting.py -q input.docx
```

## Integration into Workflow

### Automatic fix in Ingestible model (Implemented)

The fix has been integrated into `app/models/ingestible.rb` as a Ruby service:

```ruby
def convert_to_markdown
  return unless docx.attached?

  bin = docx.download # grab the docx binary

  # Fix inherited formatting (bold/italic from paragraph styles) before pandoc conversion
  # This ensures pandoc can see formatting that's defined in styles but not directly on runs
  bin = FixDocxInheritedFormatting.call(bin)

  tmpfile = Tempfile.new(['docx2mmd__', '.docx'], encoding: 'ascii-8bit')
  # ... rest of existing code
```

The `FixDocxInheritedFormatting` service is located in `app/services/fix_docx_inherited_formatting.rb` and automatically processes all DOCX files before conversion to Markdown.

## Test Results

Tested with `tmp/tst2.docx`:
- **Before fix**: 0 bold runs detected by pandoc
- **After fix (Python script)**: 78 formatting properties explicitly applied
- **After fix (Ruby service)**: 78 formatting properties explicitly applied
- **Example**: "יומן" now converts to `**יומן**` in Markdown ✓
- **RSpec tests**: All 4 specs passing ✓

## Known Limitations

1. **Footnote RTL formatting**: Pandoc 3.8.3 has a separate bug with RTL text in footnotes
   - Creates empty span tags and malformed bold markers
   - Example: `** **<span dir="rtl">text</span>` instead of `**<span>text</span>**`
   - This requires a different fix or downgrading pandoc

2. **Other inherited properties**: The script currently handles bold and italic
   - Can be extended to handle underline, color, fonts, etc.

## Implementation Details - Ruby Service

The Ruby implementation (`FixDocxInheritedFormatting`) faced several challenges during development:

1. **XML Serialization**: Nokogiri by default adds indentation when serializing XML. DOCX files require compact XML without extra whitespace. Fixed by using `save_with: Nokogiri::XML::Node::SaveOptions::AS_XML` to disable formatting.

2. **Namespace Handling**: Creating namespaced nodes requires properly setting the namespace object, not just using prefixed names like 'w:b'. Fixed by using a helper method that assigns the correct namespace from the document root.

3. **ZIP File Completeness**: Ruby's `Dir.glob('**/*')` doesn't match hidden directories like `_rels` by default. The critical `_rels/.rels` file was missing from the repackaged ZIP. Fixed by adding `File::FNM_DOTMATCH` flag to include hidden files.

All three issues were resolved, resulting in a fully functional Ruby service that produces identical output to the Python script.

## Files Changed

- `bin/fix_docx_formatting.py` - Python conversion fix script (reference implementation)
- `app/services/fix_docx_inherited_formatting.rb` - Ruby service (production implementation)
- `app/models/ingestible.rb` - Integrated fix into convert_to_markdown method
- `spec/services/fix_docx_inherited_formatting_spec.rb` - RSpec test suite
- `DOCX_BOLD_FIX.md` - This documentation

## Conclusion

**Production Solution**: The `FixDocxInheritedFormatting` Ruby service is now integrated into the application and automatically fixes all DOCX files during the conversion process. No manual pre-processing is required.

**Pandoc version**: Can stay on 3.8.3 - downgrading won't help with this issue.

**Python script**: The `bin/fix_docx_formatting.py` script remains available for standalone use or debugging purposes.

**Alternative**: If the DOCX file source is controlled, edit the document to apply direct formatting instead of relying on paragraph styles.
