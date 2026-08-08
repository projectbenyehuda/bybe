# frozen_string_literal: true

# Adds the 'pageless' flag, marking authorities (e.g. 'anonymous', 'various authors') which are useful
# for crediting a text, but for which an Authority#toc page would be meaningless.
class AddPagelessToAuthorities < ActiveRecord::Migration[8.0]
  def change
    add_column :authorities, :pageless, :boolean, default: false, null: false
  end
end
