class Channel < ApplicationRecord
  has_many :videos, dependent: :destroy

  validates :name, presence: true
  validates :youtube_channel_id, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  # Channels whose WebSub (push) subscription is missing or expires within
  # `within`, and so should be (re)subscribed.
  scope :needing_websub_renewal, lambda { |within: 2.days|
    where(websub_expires_at: nil).or(where(websub_expires_at: ..within.from_now))
  }

  # YouTube derives a channel's uploads playlist id from its channel id by
  # swapping the "UC" prefix for "UU". We still prefer an explicitly stored
  # value (resolved via the API) when present.
  def uploads_playlist
    uploads_playlist_id.presence || youtube_channel_id.sub(/\AUC/, "UU")
  end
end
