module Espn
  # One ESPN scoreboard event reduced to spoiler-safe fields. The raw payload
  # also carries scores, records and stat leaders; this is the only place that
  # reads it, and it deliberately never touches those keys.
  class Event
    STATUS_MAP = {
      "pre" => "scheduled",
      "in" => "in_progress",
      "post" => "final"
    }.freeze

    def initialize(data)
      @data = data
    end

    def espn_id = @data["id"].to_s
    def season = @data.dig("season", "year")
    def season_type = @data.dig("season", "type")
    def week = @data.dig("week", "number")
    def kickoff_at = Time.zone.parse(@data["date"])
    def neutral_site = competition["neutralSite"] ? true : false
    def tv = Array(competition["broadcasts"]).flat_map { |b| b["names"] }.compact.join(", ").presence

    # Pre-game rank only; ESPN reports 99 for unranked.
    def home_rank = rank(home)
    def away_rank = rank(away)

    def status
      return "postponed" if type_name == "STATUS_POSTPONED"
      return "canceled" if type_name == "STATUS_CANCELED"

      STATUS_MAP.fetch(@data.dig("status", "type", "state"), "scheduled")
    end

    def home_team = team_attributes(home)
    def away_team = team_attributes(away)

    # Games with a placeholder side (e.g. TBD bowl slots) can't be stored.
    def complete?
      home && away && home.dig("team", "id").present? && away.dig("team", "id").present?
    end

    private

    def competition = @data.dig("competitions", 0) || {}
    def type_name = @data.dig("status", "type", "name")
    def home = Array(competition["competitors"]).find { |c| c["homeAway"] == "home" }
    def away = Array(competition["competitors"]).find { |c| c["homeAway"] == "away" }

    def rank(competitor)
      value = competitor&.dig("curatedRank", "current")
      value if value.to_i.between?(1, 25)
    end

    def team_attributes(competitor)
      team = competitor.fetch("team")
      {
        espn_id: team["id"].to_s,
        name: team["displayName"],
        nickname: team["name"],
        short_name: team["shortDisplayName"] || team["location"],
        abbreviation: team["abbreviation"],
        logo_url: team["logo"],
        color: team["color"],
        conference_id: team["conferenceId"]&.to_s
      }
    end
  end
end
