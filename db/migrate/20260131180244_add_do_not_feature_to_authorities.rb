# frozen_string_literal: true

class AddDoNotFeatureToAuthorities < ActiveRecord::Migration[8.0]
  def change
    add_column :authorities, :do_not_feature, :boolean, default: false, null: false
  end
end
