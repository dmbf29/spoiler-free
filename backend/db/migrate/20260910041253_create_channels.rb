class CreateChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :channels do |t|
      t.string :name, null: false
      t.string :youtube_channel_id, null: false
      t.string :youtube_url
      # The channel's "uploads" playlist id. May be blank until the first sync
      # resolves it from the YouTube API.
      t.string :uploads_playlist_id
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :channels, :youtube_channel_id, unique: true
  end
end
