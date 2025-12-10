class CreateLexIssues < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_issues, if_not_exists: true do |t|
      t.string :subtitle
      t.string :volume
      t.string :issue
      t.integer :seq_num
      t.text :toc
      t.references :lex_publication, foreign_key: true

      t.timestamps
    end
    add_index :lex_issues, :subtitle, if_not_exists: true
    add_index :lex_issues, :seq_num, if_not_exists: true
  end
end
