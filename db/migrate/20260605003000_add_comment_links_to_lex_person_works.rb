# frozen_string_literal: true

# Stores person links found in plain (non-role) work comments, mirroring title_links.
# Each element is { 'text' => '...', 'entry_id' => 123 }, so the comment can be rendered
# with the named person hyperlinked to their LexEntry.
class AddCommentLinksToLexPersonWorks < ActiveRecord::Migration[8.1]
  def change
    add_column :lex_person_works, :comment_links, :json
  end
end
