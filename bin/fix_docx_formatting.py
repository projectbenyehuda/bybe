#!/usr/bin/env python3
"""
Fix DOCX formatting by explicitly applying inherited style properties.

This script fixes DOCX files where bold/italic formatting is defined in paragraph
styles but not applied directly to runs. This makes the formatting visible to
pandoc and other converters that don't properly handle style inheritance.

Usage:
    fix_docx_formatting.py input.docx [output.docx]

If output.docx is not specified, overwrites input.docx (after creating a backup).
"""

import xml.etree.ElementTree as ET
from zipfile import ZipFile
import shutil
import os
import sys
import argparse


def fix_docx_inherited_formatting(input_path, output_path=None, verbose=True):
    """
    Fix DOCX by explicitly applying inherited style properties to runs.

    Args:
        input_path: Path to input DOCX file
        output_path: Path to output DOCX file (if None, overwrites input)
        verbose: Print progress messages

    Returns:
        Number of modifications made
    """

    # Determine output path
    if output_path is None:
        output_path = input_path

    # Create backup
    backup_path = input_path + '.backup'
    if os.path.exists(backup_path):
        # Don't overwrite existing backup
        i = 1
        while os.path.exists(f"{input_path}.backup.{i}"):
            i += 1
        backup_path = f"{input_path}.backup.{i}"

    shutil.copy2(input_path, backup_path)
    if verbose:
        print(f"Created backup: {backup_path}")

    # Extract DOCX to temp directory
    extract_dir = '/tmp/docx_fix_temp_' + str(os.getpid())
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir)

    try:
        with ZipFile(input_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)

        # Parse documents
        ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

        # Register all common namespaces to preserve them
        namespaces = {
            'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
            'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
            'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
            'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
            'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
        }

        for prefix, uri in namespaces.items():
            ET.register_namespace(prefix, uri)

        doc_path = os.path.join(extract_dir, 'word', 'document.xml')
        styles_path = os.path.join(extract_dir, 'word', 'styles.xml')

        # Parse documents
        doc_tree = ET.parse(doc_path)
        styles_tree = ET.parse(styles_path)

        # Build style properties map
        style_props = {}

        for style in styles_tree.findall('.//w:style', ns):
            style_id = style.get('{' + ns['w'] + '}styleId')
            if style_id:
                rPr = style.find('.//w:rPr', ns)
                if rPr is not None:
                    # Check for bold
                    b_tag = rPr.find('w:b', ns)
                    bCs_tag = rPr.find('w:bCs', ns)

                    # Check for italic
                    i_tag = rPr.find('w:i', ns)
                    iCs_tag = rPr.find('w:iCs', ns)

                    # If tag exists without val or val != "0", formatting is ON
                    def is_on(tag):
                        if tag is None:
                            return False
                        val = tag.get('{' + ns['w'] + '}val')
                        return (val is None or val not in ['0', 'false'])

                    style_props[style_id] = {
                        'bold': is_on(b_tag),
                        'bold_cs': is_on(bCs_tag),
                        'italic': is_on(i_tag),
                        'italic_cs': is_on(iCs_tag),
                    }

        if verbose:
            bold_styles = [sid for sid, props in style_props.items()
                          if props['bold'] or props['bold_cs']]
            italic_styles = [sid for sid, props in style_props.items()
                            if props['italic'] or props['italic_cs']]

            print(f"\nFound {len(style_props)} styles with formatting")
            if bold_styles:
                print(f"  {len(bold_styles)} styles with bold")
            if italic_styles:
                print(f"  {len(italic_styles)} styles with italic")

        # Process all paragraphs
        modifications = 0
        total_runs = 0

        for para in doc_tree.findall('.//w:p', ns):
            # Get paragraph style
            pPr = para.find('w:pPr', ns)
            para_style_id = None

            if pPr is not None:
                pStyle = pPr.find('w:pStyle', ns)
                if pStyle is not None:
                    para_style_id = pStyle.get('{' + ns['w'] + '}val')

            # Get inherited properties from style
            inherited = {
                'bold': False,
                'bold_cs': False,
                'italic': False,
                'italic_cs': False,
            }

            if para_style_id and para_style_id in style_props:
                inherited = style_props[para_style_id]

            # Process runs in this paragraph
            for run in para.findall('.//w:r', ns):
                total_runs += 1
                rPr = run.find('w:rPr', ns)

                # If no run properties, create them if needed
                if rPr is None and any(inherited.values()):
                    rPr = ET.Element('{' + ns['w'] + '}rPr')
                    # Insert rPr as first child of run
                    run.insert(0, rPr)

                if rPr is not None:
                    # Apply inherited bold
                    if rPr.find('w:b', ns) is None and inherited['bold']:
                        new_b = ET.Element('{' + ns['w'] + '}b')
                        rPr.insert(0, new_b)
                        modifications += 1

                    if rPr.find('w:bCs', ns) is None and inherited['bold_cs']:
                        new_bCs = ET.Element('{' + ns['w'] + '}bCs')
                        rPr.insert(0, new_bCs)
                        modifications += 1

                    # Apply inherited italic
                    if rPr.find('w:i', ns) is None and inherited['italic']:
                        new_i = ET.Element('{' + ns['w'] + '}i')
                        rPr.insert(0, new_i)
                        modifications += 1

                    if rPr.find('w:iCs', ns) is None and inherited['italic_cs']:
                        new_iCs = ET.Element('{' + ns['w'] + '}iCs')
                        rPr.insert(0, new_iCs)
                        modifications += 1

        if verbose:
            print(f"\nProcessed {total_runs} runs")
            print(f"Applied {modifications} explicit formatting properties")

        # Write modified document back
        doc_tree.write(doc_path, encoding='utf-8', xml_declaration=True)

        # Repackage as DOCX
        with ZipFile(output_path, 'w') as zip_ref:
            for root, dirs, files in os.walk(extract_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, extract_dir)
                    zip_ref.write(file_path, arcname)

        if verbose:
            print(f"\nFixed DOCX saved to: {output_path}")

        return modifications

    finally:
        # Cleanup
        if os.path.exists(extract_dir):
            shutil.rmtree(extract_dir)


def main():
    parser = argparse.ArgumentParser(
        description='Fix DOCX formatting by applying inherited style properties',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s input.docx                 # Fix in-place (creates backup)
  %(prog)s input.docx output.docx     # Save to new file
  %(prog)s -q input.docx              # Quiet mode (no output)
        """
    )

    parser.add_argument('input', help='Input DOCX file')
    parser.add_argument('output', nargs='?', help='Output DOCX file (optional)')
    parser.add_argument('-q', '--quiet', action='store_true',
                       help='Suppress output messages')

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    if not args.input.lower().endswith('.docx'):
        print(f"Error: Input file must be a .docx file", file=sys.stderr)
        sys.exit(1)

    try:
        modifications = fix_docx_inherited_formatting(
            args.input,
            args.output,
            verbose=not args.quiet
        )

        if not args.quiet:
            print(f"\n{'='*60}")
            print(f"Success! Applied {modifications} formatting fixes")
            print(f"{'='*60}")

        sys.exit(0)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
