class AddWebsubExpiresAtToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :websub_expires_at, :datetime
  end
end
