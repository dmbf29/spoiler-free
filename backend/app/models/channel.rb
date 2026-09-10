class Channel < ApplicationRecord
  has_many :videos, dependent: :destroy

  validates :name, presence: true
  validates :youtube_channel_id, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  # YouTube derives a channel's uploads playlist id from its channel id by
  # swapping the "UC" prefix for "UU". We still prefer an explicitly stored
  # value (resolved via the API) when present.
  def uploads_playlist
    uploads_playlist_id.presence || youtube_channel_id.sub(/\AUC/, "UU")
  end
end
