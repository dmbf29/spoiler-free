require "test_helper"

class Api::V1::GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @competition = competitions(:college_football)
    @navy = Team.create!(espn_id: "2426", name: "Navy Midshipmen", short_name: "Navy", conference: "American")
    @nd = Team.create!(espn_id: "87", name: "Notre Dame Fighting Irish", short_name: "Notre Dame")
    make_game("a", week: 9, kickoff: 1.day.from_now)
    make_game("b", week: 9, kickoff: 2.days.from_now)
    make_game("c", week: 10, kickoff: 8.days.from_now)
  end

  def make_game(id, week:, kickoff:)
    Game.create!(
      competition: @competition, espn_id: id, season: 2026, week: week, kickoff_at: kickoff,
      home_team: @navy, away_team: @nd, status: "scheduled", tv: "ABC", away_rank: 5
    )
  end

  test "defaults to the current week, chronological, with the available weeks" do
    get "/api/v1/games"
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 9, body["week"]
    assert_equal [9, 10], body["weeks"]
    assert_equal 2, body["games"].size
    game = body["games"].first
    assert_equal "Navy", game.dig("home_team", "short_name")
    assert_equal 5, game.dig("away_team", "rank")
    assert_equal "ABC", game["tv"]
  end

  test "lists the highlight sources attached to a game, without titles" do
    game = Game.find_by!(espn_id: "a")
    Video.create!(channel: channels(:nbc_sports), competition: @competition, game: game,
                  youtube_video_id: "yt_a", original_title: "Navy vs Notre Dame | COLLEGE FOOTBALL HIGHLIGHTS",
                  safe_title: "Notre Dame vs Navy", published_at: 1.hour.ago, is_highlight: true)

    get "/api/v1/games"
    body = JSON.parse(response.body)

    highlights = body["games"].first["highlights"]
    assert_equal ["yt_a"], highlights.map { |h| h["youtube_video_id"] }
    assert_equal "NBC Sports", highlights.first.dig("channel", "name")
    assert_equal [], body["games"].last["highlights"]
    refute_includes response.body, "original_title"
    refute_includes response.body, "COLLEGE FOOTBALL HIGHLIGHTS"
    refute_includes response.body, "safe_title"
  end

  test "selects a week explicitly" do
    get "/api/v1/games", params: { week: 10 }
    assert_equal 1, JSON.parse(response.body)["games"].size
  end

  test "never exposes scores, records or results" do
    get "/api/v1/games"
    refute_match(/score|record|winner|result/i, response.body)
  end

  test "unknown competition is a 404" do
    get "/api/v1/games", params: { competition: "nope" }
    assert_response :not_found
  end

  test "empty schedule returns no games" do
    Game.delete_all
    get "/api/v1/games"
    assert_equal [], JSON.parse(response.body)["games"]
  end
end
