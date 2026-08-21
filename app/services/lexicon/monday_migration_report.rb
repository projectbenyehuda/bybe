# frozen_string_literal: true

module Lexicon
  # Announces a completed migration verification on the "migrated entries" Monday
  # board (LEXICON_MIGRATED_MONDAY_BOARD_ID), so a second pair of eyes can review
  # it there. Posted when an editor marks a LexEntry as verified.
  #
  # The board's checker column (שם הבודק/ת) is deliberately left empty — it is
  # assigned interactively on Monday, after the fact.
  class MondayMigrationReport
    # Board column ids, all of them text/link columns on the migrated-entries board.
    VERIFIER_COLUMN = 'text_mm5wq5fh'
    TITLE_COLUMN = 'text_mm2tn5yc'
    LINK_COLUMN = 'link_mm2t7e9n'

    def self.call(**)
      new(**).call
    end

    # @param entry [LexEntry] the entry that was just marked verified
    # @param verifier [User, nil] the editor who completed the verification
    # @param entry_url [String] full URL of the entry's verification page
    def initialize(entry:, verifier:, entry_url:)
      @entry = entry
      @verifier = verifier
      @entry_url = entry_url
    end

    def call
      MondayClient.create_item(
        board_id: ENV.fetch('LEXICON_MIGRATED_MONDAY_BOARD_ID', nil),
        item_name: @entry.title,
        column_values: column_values
      )
    end

    private

    def column_values
      {
        TITLE_COLUMN => @entry.title,
        LINK_COLUMN => { 'url' => @entry_url, 'text' => I18n.t('lexicon.verification.monday.link_text') }
      }.tap do |values|
        values[VERIFIER_COLUMN] = @verifier.name if @verifier&.name.present?
      end
    end
  end
end
