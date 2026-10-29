# Upserts a competition's teams and games from ESPN's scoreboard, a week at a
# time. Idempotent: safe to run on a schedule. Stores only what Espn::Event
# exposes (no scores, records or raw payload).
class ScheduleSynchronizer
  Summary = Struct.new(:week, :games, :created, keyword_init: true) do
    def to_s = "week #{week}: #{games} games (#{created} new)"
  end

  def initialize(competition, client: nil)
    @competition = competition
    if client.nil? && competition.api_url.blank?
      raise ArgumentError, "#{competition.slug} has no api_url; run bin/rails db:migrate or db:seed"
    end

    @client = client || Espn::Client.new(base_url: competition.api_url)
  end

  # Current week plus the next `ahead` weeks.
  def sync_current(ahead: 1)
    current = @client.current_week
    last_week = current[:calendar].map { |e| e[:week] }.max || current[:week]
    (current[:week]..[current[:week] + ahead, last_week].min).map do |week|
      sync_week(current[:season], week, season_type: current[:season_type])
    end
  end

  # Every regular-season week on ESPN's calendar (backfill / season start).
  def sync_season
    current = @client.current_week
    current[:calendar].map do |entry|
      sync_week(current[:season], entry[:week], season_type: current[:season_type])
    end
  end

  def sync_week(season, week, season_type: Espn::Client::REGULAR_SEASON)
    events = @client.week_events(season: season, week: week, season_type: season_type).select(&:complete?)
    created = events.count { |event| upsert(event) }
    Summary.new(week: week, games: events.size, created: created)
  end

  private

  def upsert(event)
    game = Game.find_or_initialize_by(espn_id: event.espn_id)
    new_record = game.new_record?

    game.assign_attributes(
      competition: @competition,
      season: event.season,
      season_type: event.season_type || Espn::Client::REGULAR_SEASON,
      week: event.week,
      kickoff_at: event.kickoff_at,
      neutral_site: event.neutral_site,
      tv: event.tv,
      status: event.status,
      home_team: upsert_team(event.home_team),
      away_team: upsert_team(event.away_team)
    )

    # Ranks are only trusted before the game: after kickoff ESPN reports the
    # live ranking, which can encode the result. Keep the pre-game snapshot
    # (a game first seen after it was played gets no rank).
    if game.status == "scheduled"
      game.home_rank = event.home_rank
      game.away_rank = event.away_rank
    end

    game.save!
    new_record
  end

  def upsert_team(attrs)
    attrs = attrs.dup
    conference = conference_names[attrs.delete(:conference_id)]
    team = Team.find_or_initialize_by(espn_id: attrs.delete(:espn_id))
    team.update!(attrs.merge(conference: conference || team.conference))
    team
  end

  def conference_names
    @conference_names ||= @client.conference_names
  end
end
