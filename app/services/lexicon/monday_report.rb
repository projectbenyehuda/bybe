# frozen_string_literal: true

module Lexicon
  # Builds a report item for the lexicon issues board (MONDAY_BOARD_ID) and posts
  # it via MondayClient. Used from the verification workbench for general notes,
  # missing-work flags and broken-link corrections.
  class MondayReport
    def self.call(**)
      new(**).call
    end

    # @param entry [LexEntry]
    # @param report_type [Symbol] :general, :missing_work or :fixed_broken_link
    # @param current_url [String] full URL of the verification page
    # @param description [String, nil] free-text (only for :general reports)
    # @param publication [Publication, nil] the publication missing from the lexicon (only for :missing_work)
    # @param record [LexCitation, LexLink, nil] the record whose broken link was replaced
    #   (only for :fixed_broken_link)
    # @param old_link [String, nil] the broken URL that was replaced (only for :fixed_broken_link)
    # rubocop:disable Metrics/ParameterLists -- keyword args, each optional and specific to a report_type
    def initialize(entry:, report_type:, current_url:, description: nil, publication: nil, record: nil,
                   old_link: nil)
      # rubocop:enable Metrics/ParameterLists
      @entry = entry
      @report_type = report_type
      @current_url = current_url
      @description = description
      @publication = publication
      @record = record
      @old_link = old_link
    end

    def call
      MondayClient.create_item(
        board_id: ENV.fetch('MONDAY_BOARD_ID', nil),
        item_name: item_name_column,
        column_values: build_column_values
      )
    end

    private

    def build_column_values
      values = {
        'text_mm2tn5yc' => @entry.title,
        'link_mm2t7e9n' => { 'url' => @current_url, 'text' => I18n.t('lexicon.verification.monday.link_text') }
      }
      long_text = case @report_type
                  when :missing_work then publication_details
                  when :fixed_broken_link then fixed_broken_link_details
                  else @description
                  end
      values['long_text_mm2tzz8q'] = long_text if long_text.present?
      values
    end

    # Publisher and year of the reported publication, for the Monday item's description column.
    def publication_details
      return nil if @publication.nil?

      I18n.t('lexicon.verification.monday.missing_work_details',
             publisher: @publication.publisher_line.presence || I18n.t('unknown'),
             year: @publication.pub_year.presence || I18n.t('unknown'))
    end

    # Old and new values of a link that an editor replaced after it was flagged as broken.
    # A cleared link is reported explicitly rather than as an empty value.
    def fixed_broken_link_details
      return nil if @record.nil?

      removed = I18n.t('lexicon.verification.monday.link_removed')
      I18n.t('lexicon.verification.monday.fixed_broken_link_details',
             old_link: @old_link.presence || removed,
             new_link: current_link.presence || removed)
    end

    # LexCitation and LexLink store the URL under different column names.
    def current_link
      @record.is_a?(LexLink) ? @record.url : @record.link
    end

    # Identifies the corrected record in the report title: a citation by its title,
    # a link by its description (falling back to the URL itself when unlabelled).
    def fixed_broken_link_subject
      if @record.is_a?(LexLink)
        I18n.t('lexicon.verification.monday.fixed_broken_link_subject.link',
               title: @record.description.presence || @record.url)
      else
        I18n.t('lexicon.verification.monday.fixed_broken_link_subject.citation', title: @record.title)
      end
    end

    def item_name_column
      case @report_type
      when :missing_work
        I18n.t('lexicon.verification.monday.missing_work_name', title: @publication&.title || @entry.title)
      when :fixed_broken_link
        I18n.t('lexicon.verification.monday.fixed_broken_link_name',
               subject: @record.nil? ? @entry.title : fixed_broken_link_subject)
      else
        I18n.t('lexicon.verification.monday.general_name')
      end
    end
  end
end
