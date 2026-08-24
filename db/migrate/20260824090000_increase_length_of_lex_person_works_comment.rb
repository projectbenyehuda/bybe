# frozen_string_literal: true

# The default varchar(255) was too short for real work comments, which sometimes carry a full
# bibliographic note. Widen to 4096 so long comments survive ingest instead of being rejected.
class IncreaseLengthOfLexPersonWorksComment < ActiveRecord::Migration[8.0]
  def up
    change_column :lex_person_works, :comment, :string, limit: 4096
  end

  def down
    change_column :lex_person_works, :comment, :string, limit: 255
  end
end
