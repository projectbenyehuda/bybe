class DoubleManifestationsAlternateTitlesLimit < ActiveRecord::Migration[7.2]
  def change
    change_column :manifestations, :alternate_titles, :string, limit: 1024
  end
end
