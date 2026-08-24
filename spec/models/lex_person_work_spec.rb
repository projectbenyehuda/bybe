# frozen_string_literal: true

require 'rails_helper'

describe LexPersonWork do
  describe '#comment' do
    # Regression: the column was varchar(255), so a long bibliographic note was silently
    # truncated (or rejected in strict mode) on save. It is now varchar(4096).
    it 'persists a comment of 4096 characters without truncation' do
      long_comment = 'א' * 4096
      work = create(:lex_person_work, comment: long_comment)

      expect(work.reload.comment).to eq long_comment
    end
  end
end
