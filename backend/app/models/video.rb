class Video < ApplicationRecord
  belongs_to :channel
  belongs_to :competition, optional: true
  has_one :sport, through: :competition

  validates :youtube_video_id, presence: true, uniqueness: true
  validates :original_title, presence: true
  validates :published_at, presence: true

  # Videos that are game highlights.
  scope :highlights, -> { where(is_highlight: true) }
  # Newest first.
  scope :recent, -> { order(published_at: :desc) }
  # Safe to show in the spoiler-free UI: a classified highlight, tied to a
  # supported competition, with a derived spoiler-safe title.
  scope :displayable, lambda {
    highlights.where.not(competition_id: nil).where.not(safe_title: [nil, ""])
  }

  def duration_iso8601
    return if duration_seconds.nil?

    ActiveSupport::Duration.build(duration_seconds).iso8601
  end
end
