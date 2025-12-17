# frozen_string_literal: true

require 'zip'
require 'nokogiri'
require 'tempfile'

# Fix DOCX files where bold/italic formatting is defined in paragraph styles
# but not applied directly to runs. This makes the formatting visible to
# pandoc and other converters that don't properly handle style inheritance.
#
# Example:
#   fixed_binary = FixDocxInheritedFormatting.call(docx_binary_content)
class FixDocxInheritedFormatting < ApplicationService
  WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

  # @param docx_binary [String] Original DOCX file as binary string
  # @return [String] Fixed DOCX file as binary string
  def call(docx_binary)
    @modifications = 0

    # Create temp files for input and output
    input_file = Tempfile.new(['docx_input_', '.docx'], encoding: 'ascii-8bit')
    output_file = Tempfile.new(['docx_output_', '.docx'], encoding: 'ascii-8bit')

    begin
      # Write input binary to temp file
      input_file.write(docx_binary)
      input_file.flush
      input_file.close

      # Fix the DOCX
      fix_docx_file(input_file.path, output_file.path)

      # Read fixed binary
      output_file.close
      File.binread(output_file.path)
    ensure
      input_file.unlink if input_file
      output_file.unlink if output_file
    end
  end

  private

  def fix_docx_file(input_path, output_path)
    # Extract DOCX (which is a ZIP file)
    extract_dir = Dir.mktmpdir('docx_extract_')

    begin
      Zip::File.open(input_path) do |zip_file|
        zip_file.each do |entry|
          fpath = File.join(extract_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(fpath))
          entry.extract(fpath)
        end
      end

      # Parse and fix the document
      doc_path = File.join(extract_dir, 'word', 'document.xml')
      styles_path = File.join(extract_dir, 'word', 'styles.xml')

      if File.exist?(doc_path) && File.exist?(styles_path)
        fix_document_xml(doc_path, styles_path)
      end

      # Repackage as DOCX
      # Use File::FNM_DOTMATCH to include hidden files/dirs like _rels
      Zip::File.open(output_path, Zip::File::CREATE) do |zipfile|
        Dir.glob(File.join(extract_dir, '**', '*'), File::FNM_DOTMATCH).each do |file|
          next if File.directory?(file)
          next if ['.', '..'].include?(File.basename(file))

          arcname = file.sub(extract_dir + File::SEPARATOR, '')
          zipfile.add(arcname, file)
        end
      end
    ensure
      FileUtils.rm_rf(extract_dir)
    end

    @modifications
  end

  def fix_document_xml(doc_path, styles_path)
    # Parse XML documents with namespace handling
    doc = Nokogiri::XML(File.read(doc_path, encoding: 'UTF-8'))
    styles = Nokogiri::XML(File.read(styles_path, encoding: 'UTF-8'))

    # Define namespace for XPath queries
    ns = { 'w' => WORD_NS }

    # Build style properties map
    style_props = build_style_properties_map(styles, ns)

    # Process all paragraphs
    doc.xpath('//w:p', ns).each do |para|
      process_paragraph(para, style_props, ns)
    end

    # Write back preserving namespaces and original formatting (no indentation)
    # Use AS_XML without FORMAT flag to prevent Nokogiri from adding indentation
    save_options = Nokogiri::XML::Node::SaveOptions::AS_XML
    File.write(doc_path, doc.to_xml(save_with: save_options))
  end

  def build_style_properties_map(styles_doc, ns)
    style_props = {}

    styles_doc.xpath('//w:style', ns).each do |style|
      style_id = style['w:styleId']
      next unless style_id

      r_pr = style.at_xpath('.//w:rPr', ns)
      next unless r_pr

      # Check for bold tags
      b_tag = r_pr.at_xpath('w:b', ns)
      b_cs_tag = r_pr.at_xpath('w:bCs', ns)
      i_tag = r_pr.at_xpath('w:i', ns)
      i_cs_tag = r_pr.at_xpath('w:iCs', ns)

      # If tag exists without val attribute or val != "0", formatting is ON
      is_on = ->(tag) { tag && (tag['w:val'].nil? || !%w(0 false).include?(tag['w:val'])) }

      style_props[style_id] = {
        bold: is_on.call(b_tag),
        bold_cs: is_on.call(b_cs_tag),
        italic: is_on.call(i_tag),
        italic_cs: is_on.call(i_cs_tag)
      }
    end

    style_props
  end

  def process_paragraph(para, style_props, ns)
    # Get paragraph style
    p_pr = para.at_xpath('w:pPr', ns)
    para_style_id = nil

    if p_pr
      p_style = p_pr.at_xpath('w:pStyle', ns)
      para_style_id = p_style['w:val'] if p_style
    end

    # Get inherited properties from style
    inherited = {
      bold: false,
      bold_cs: false,
      italic: false,
      italic_cs: false
    }

    if para_style_id && style_props[para_style_id]
      inherited = style_props[para_style_id]
    end

    # Return early if no inherited formatting
    return unless inherited.values.any?

    # Process runs in this paragraph
    para.xpath('.//w:r', ns).each do |run|
      process_run(run, inherited, ns)
    end
  end

  def process_run(run, inherited, ns)
    r_pr = run.at_xpath('w:rPr', ns)

    # Create rPr if it doesn't exist and we need to add formatting
    unless r_pr
      r_pr = create_namespaced_node('rPr', run.document)
      run.prepend_child(r_pr)
    end

    # Apply inherited bold
    if !r_pr.at_xpath('w:b', ns) && inherited[:bold]
      b_node = create_namespaced_node('b', run.document)
      r_pr.prepend_child(b_node)
      @modifications += 1
    end

    if !r_pr.at_xpath('w:bCs', ns) && inherited[:bold_cs]
      b_cs_node = create_namespaced_node('bCs', run.document)
      r_pr.prepend_child(b_cs_node)
      @modifications += 1
    end

    # Apply inherited italic
    if !r_pr.at_xpath('w:i', ns) && inherited[:italic]
      i_node = create_namespaced_node('i', run.document)
      r_pr.prepend_child(i_node)
      @modifications += 1
    end

    return unless !r_pr.at_xpath('w:iCs', ns) && inherited[:italic_cs]

    i_cs_node = create_namespaced_node('iCs', run.document)
    r_pr.prepend_child(i_cs_node)
    @modifications += 1
  end

  # Helper to create nodes with proper namespace
  def create_namespaced_node(name, document)
    node = Nokogiri::XML::Node.new(name, document)
    # Find the 'w' namespace from the document root
    w_ns = document.root.namespace_definitions.find { |n| n.prefix == 'w' }
    node.namespace = w_ns
    node
  end
end
