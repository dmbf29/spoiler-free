class Game < ApplicationRecord
  STATUSES = %w[scheduled in_progress final postponed canceled].freeze

  belongs_to :competition
  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  has_many :videos, dependent: :nullify

  validates :espn_id, presence: true, uniqueness: true
  validates :season, :kickoff_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :chronological, -> { order(:kickoff_at, :id) }
  scope :for_week, ->(season, week, season_type: 2) { where(season: season, season_type: season_type, week: week) }
end
