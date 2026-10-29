class Team < ApplicationRecord
  has_many :home_games, class_name: "Game", foreign_key: :home_team_id, dependent: :restrict_with_error
  has_many :away_games, class_name: "Game", foreign_key: :away_team_id, dependent: :restrict_with_error

  validates :espn_id, presence: true, uniqueness: true
  validates :name, :short_name, presence: true

  # "Central Michigan" for "Central Michigan Chippewas". Titles often use this
  # in place of ESPN's abbreviated short_name ("C Michigan").
  def location
    return if nickname.blank?

    name.delete_suffix(nickname).strip.presence
  end
end
