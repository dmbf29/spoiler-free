module Espn
  # Thin wrapper around ESPN's public (unofficial, undocumented) scoreboard API.
  # Fetching only — see Espn::Event for which fields we keep. The base URL comes
  # from Competition#api_url so other leagues can reuse this client.
  class Client
    class Error < StandardError; end

    # ESPN group id for FBS (Division I). FCS is a different group.
    FBS_GROUP = "80".freeze
    REGULAR_SEASON = 2

    def initialize(base_url:, group: FBS_GROUP)
      @base_url = base_url
      @group = group
    end

    # Current week, season and the season's week calendar, from the default
    # scoreboard: { season:, season_type:, week:, calendar: [{ week:, start:, end: }] }
    def current_week
      data = get("scoreboard", groups: @group, limit: 1)
      calendar = data.dig("leagues", 0, "calendar", 0, "entries").to_a.map do |entry|
        { week: entry["value"].to_i, start: entry["startDate"], end: entry["endDate"] }
      end

      {
        season: data.dig("season", "year"),
        season_type: data.dig("season", "type") || REGULAR_SEASON,
        week: data.dig("week", "number"),
        calendar: calendar
      }
    end

    # Every game in a week, as Espn::Event objects.
    def week_events(season:, week:, season_type: REGULAR_SEASON)
      data = get("scoreboard", year: season, seasontype: season_type, week: week, groups: @group, limit: 400)
      data.fetch("events", []).map { |event| Event.new(event) }
    end

    # { "151" => "American", ... } — scoreboard teams carry only a conference id.
    def conference_names
      data = get("scoreboard/conferences")
      data.fetch("conferences", []).to_h { |c| [c["groupId"].to_s, c["shortName"] || c["name"]] }
    end

    private

    def connection
      @connection ||= Faraday.new(url: @base_url) do |f|
        f.options.timeout = 15
        f.options.open_timeout = 5
        f.response :raise_error
      end
    end

    def get(path, params = {})
      JSON.parse(connection.get(path, params).body)
    rescue Faraday::Error, JSON::ParserError => e
      status = e.respond_to?(:response_status) ? e.response_status : nil
      raise Error, "ESPN request to #{path} failed (#{status || e.class})"
    end
  end
end
