require "test_helper"

class ScheduleSynchronizerTest < ActiveSupport::TestCase
  # Stands in for Espn::Client.
  class FakeClient
    def initialize(events, week: 9, calendar_weeks: (1..15))
      @events = events
      @week = week
      @calendar_weeks = calendar_weeks
    end

    def current_week
      {
        season: 2026, season_type: 2, week: @week,
        calendar: @calendar_weeks.map { |w| { week: w, start: nil, end: nil } }
      }
    end

    def week_events(season:, week:, season_type: 2)
      @events.select { |e| e.week == week }.tap { |_| season && season_type }
    end

    def conference_names = { "151" => "American", "5" => "Independents" }
  end

  def event(id: "1", week: 9, state: "pre", rank_home: 99, rank_away: 99, home_id: "10", away_id: "20",
            date: "2026-10-31T16:00Z", tv: "ESPN2")
    Espn::Event.new(
      "id" => id, "date" => date,
      "season" => { "year" => 2026, "type" => 2 }, "week" => { "number" => week },
      "status" => { "type" => { "state" => state, "name" => "STATUS_X" } },
      "competitions" => [{
        "neutralSite" => true,
        "broadcasts" => [{ "market" => "national", "names" => [tv] }],
        "competitors" => [
          competitor("home", home_id, "Navy", rank_home, state),
          competitor("away", away_id, "Notre Dame", rank_away, state)
        ]
      }]
    )
  end

  def competitor(side, id, name, rank, state)
    {
      "homeAway" => side, "score" => (state == "pre" ? "0" : "42"),
      "curatedRank" => { "current" => rank },
      "records" => [{ "summary" => "9-0" }],
      "team" => {
        "id" => id, "displayName" => "#{name} Team", "shortDisplayName" => name, "abbreviation" => name[0, 4].upcase,
        "logo" => "https://img.test/#{id}.png", "color" => "00225b", "conferenceId" => "151"
      }
    }
  end

  setup { @competition = competitions(:college_football) }

  def sync(events, **opts)
    ScheduleSynchronizer.new(@competition, client: FakeClient.new(events, **opts))
  end

  test "creates teams and games for a week" do
    summary = sync([event]).sync_week(2026, 9)

    assert_equal 1, summary.games
    assert_equal 1, summary.created
    game = Game.find_by!(espn_id: "1")
    assert_equal "Navy", game.home_team.short_name
    assert_equal "American", game.home_team.conference
    assert_equal "ESPN2", game.tv
    assert game.neutral_site
    assert_equal "scheduled", game.status
    assert_equal Time.utc(2026, 10, 31, 16), game.kickoff_at
  end

  test "is idempotent and picks up kickoff and TV changes" do
    sync([event]).sync_week(2026, 9)

    assert_no_difference ["Game.count", "Team.count"] do
      sync([event(date: "2026-10-31T19:30Z", tv: "ABC")]).sync_week(2026, 9)
    end
    game = Game.find_by!(espn_id: "1")
    assert_equal "ABC", game.tv
    assert_equal Time.utc(2026, 10, 31, 19, 30), game.kickoff_at
  end

  test "snapshots pre-game rank and keeps it after the game is played" do
    sync([event(rank_home: 5)]).sync_week(2026, 9)
    assert_equal 5, Game.find_by!(espn_id: "1").home_rank

    sync([event(state: "post", rank_home: 99)]).sync_week(2026, 9)
    game = Game.find_by!(espn_id: "1")
    assert_equal "final", game.status
    assert_equal 5, game.home_rank
  end

  test "treats rank 99 as unranked" do
    sync([event]).sync_week(2026, 9)
    assert_nil Game.find_by!(espn_id: "1").home_rank
  end

  test "skips events missing a team" do
    broken = Espn::Event.new("id" => "9", "date" => "2026-10-31T16:00Z", "competitions" => [{ "competitors" => [] }])
    assert_no_difference "Game.count" do
      assert_equal 0, sync([broken]).sync_week(2026, 9).games
    end
  end

  test "sync_current covers this week and the next, capped at the end of the calendar" do
    client_events = [event(id: "1", week: 9), event(id: "2", week: 10, home_id: "30", away_id: "40")]
    summaries = sync(client_events).sync_current
    assert_equal [9, 10], summaries.map(&:week)

    summaries = sync([], week: 15).sync_current
    assert_equal [15], summaries.map(&:week)
  end
end
