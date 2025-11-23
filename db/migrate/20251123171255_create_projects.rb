# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.text :description
      t.date :start_date
      t.date :end_date
      t.string :contact_person_name
      t.string :contact_person_phone
      t.string :contact_person_email
      t.text :comments
      t.string :default_external_link
      t.string :default_link_description

      t.timestamps
    end
  end
end
