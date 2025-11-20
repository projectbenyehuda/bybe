# frozen_string_literal: true

class LengthenOauthTokenInUsers < ActiveRecord::Migration[8.0]
  def up
    change_column :users, :oauth_token, :string, limit: 4096
  end

  def down
    change_column :users, :oauth_token, :string, limit: 255
  end
end
