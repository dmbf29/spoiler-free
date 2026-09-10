class CreateVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :videos do |t|
      t.references :channel, null: false, foreign_key: true
      # Optional: null when the video is stored but not a displayable highlight
      # (e.g. a non-highlight upload we keep so we don't re-classify it).
      t.references :competition, null: true, foreign_key: true

      t.string :youtube_video_id, null: false
      # Raw YouTube title — kept for classification/debugging, never sent to the
      # public API.
      t.string :original_title, null: false
      # Spoiler-safe matchup title shown in the UI, e.g. "Everton vs Manchester United".
      t.string :safe_title
      t.datetime :published_at, null: false
      t.integer :duration_seconds

      t.boolean :is_highlight, null: false, default: false
      # Playback geo/embeddability hints from the YouTube API, so the UI can warn
      # instead of showing a broken player.
      t.boolean :region_restricted, null: false, default: false
      t.boolean :embeddable, null: false, default: true

      # Full YouTube API item for this video (debug / re-classification).
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :videos, :youtube_video_id, unique: true
    # Main list query: highlights in reverse-chronological order.
    add_index :videos, [:is_highlight, :published_at]
  end
end
