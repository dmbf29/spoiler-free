require "test_helper"

class GameMatcherTest < ActiveSupport::TestCase
  KICKOFF = Time.utc(2026, 10, 31, 16)

  setup do
    @competition = competitions(:college_football)
    @channel = channels(:nbc_sports)
    @matcher = GameMatcher.new
  end

  def team(id, name, nickname, short, abbr = nil)
    Team.create!(espn_id: id, name: "#{name} #{nickname}", nickname: nickname, short_name: short, abbreviation: abbr)
  end

  def game(away, home, kickoff: KICKOFF, id: "g#{Game.count}")
    Game.create!(competition: @competition, espn_id: id, season: 2026, week: 9, kickoff_at: kickoff,
                 home_team: home, away_team: away)
  end

  def video(title, published_at: KICKOFF + 6.hours, id: "v#{Video.count}")
    Video.create!(channel: @channel, competition: @competition, youtube_video_id: id, original_title: title,
                  safe_title: title, published_at: published_at, is_highlight: true)
  end

  test "matches a title using the full name, the short name or the location" do
    cmich = team("174", "Central Michigan", "Chippewas", "C Michigan", "CMU")
    unm = team("167", "New Mexico", "Lobos", "New Mexico", "UNM")
    g = game(cmich, unm)

    ["Central Michigan vs New Mexico", "Central Michigan Chippewas vs New Mexico Lobos",
     "C Michigan vs New Mexico Lobos", "CMU vs UNM"].each do |title|
      v = video(title)
      assert_equal g, @matcher.call(v), title
      assert_equal g, v.reload.game
    end
  end

  test "ignores the order of the two teams and rank-free punctuation" do
    miami = team("193", "Miami (OH)", "RedHawks", "Miami OH")
    ohio = team("195", "Ohio", "Bobcats", "Ohio")
    g = game(miami, ohio)

    assert_equal g, @matcher.call(video("Ohio vs Miami (OH) RedHawks"))
  end

  test "does not confuse Texas with Texas Tech" do
    texas = team("251", "Texas", "Longhorns", "Texas")
    tech = team("2641", "Texas Tech", "Red Raiders", "Texas Tech")
    okla = team("201", "Oklahoma", "Sooners", "Oklahoma")
    game(okla, texas, id: "a")
    tech_game = game(okla, tech, id: "b")

    assert_equal tech_game, @matcher.call(video("Oklahoma vs Texas Tech"))
    assert_equal "a", @matcher.call(video("Oklahoma vs Texas")).espn_id
    assert_nil @matcher.call(video("Oklahoma vs Texas A&M"))
  end

  test "normalizes St. and ampersands" do
    msu = team("127", "Michigan State", "Spartans", "Michigan State")
    um = team("130", "Michigan", "Wolverines", "Michigan")
    g = game(msu, um)

    assert_equal g, @matcher.call(video("Michigan St. vs Michigan"))
  end

  test "only matches games that kicked off shortly before the upload" do
    a = team("1", "Alpha", "Ants", "Alpha")
    b = team("2", "Beta", "Bees", "Beta")
    game(a, b)

    assert_nil @matcher.call(video("Alpha vs Beta", published_at: KICKOFF - 1.hour))
    assert_nil @matcher.call(video("Alpha vs Beta", published_at: KICKOFF + 10.days))
  end

  test "picks the most recent meeting when teams play twice in the window" do
    a = team("1", "Alpha", "Ants", "Alpha")
    b = team("2", "Beta", "Bees", "Beta")
    game(a, b, kickoff: KICKOFF - 3.days, id: "first")
    second = game(b, a, kickoff: KICKOFF, id: "second")

    assert_equal second, @matcher.call(video("Alpha vs Beta"))
  end

  test "skips non-highlights and unparseable titles" do
    a = team("1", "Alpha", "Ants", "Alpha")
    b = team("2", "Beta", "Bees", "Beta")
    game(a, b)

    not_highlight = video("Alpha vs Beta")
    not_highlight.update!(is_highlight: false)
    assert_nil @matcher.call(not_highlight)
    assert_nil @matcher.call(video("Alpha"))
  end
end
