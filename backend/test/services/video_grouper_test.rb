require "test_helper"

class VideoGrouperTest < ActiveSupport::TestCase
  def video(title, channel:, competition: :college_football, hours_ago: 1, id: title.hash)
    Video.new(
      id: id, safe_title: title, channel: channels(channel), competition: competitions(competition),
      published_at: hours_ago.hours.ago, youtube_video_id: "yt#{id}", original_title: title
    )
  end

  test "groups the same game across channels despite differing team names" do
    fox = video("Houston Cougars vs Texas Tech Red Raiders", channel: :cfb_on_fox, hours_ago: 1, id: 1)
    espn = video("Houston Cougars vs Texas Tech Raiders", channel: :espn_cfb, hours_ago: 2, id: 2)

    groups = VideoGrouper.call([espn, fox])

    assert_equal 1, groups.size
    assert_equal [fox, espn], groups.first # newest leads
  end

  test "groups when a channel lists the teams in the opposite order" do
    a = video("Houston Cougars vs Texas Tech Raiders", channel: :cfb_on_fox, id: 1)
    b = video("Texas Tech Raiders vs Houston Cougars", channel: :espn_cfb, id: 2)

    assert_equal 1, VideoGrouper.call([a, b]).size
  end

  test "keeps different games separate, including partial name overlap" do
    a = video("Texas Longhorns vs Oklahoma Sooners", channel: :cfb_on_fox, id: 1)
    b = video("Texas Tech Red Raiders vs Houston Cougars", channel: :espn_cfb, id: 2)
    c = video("Texas A&M Aggies vs Texas Tech Red Raiders", channel: :cbs_sports_cfb, id: 3)

    assert_equal 3, VideoGrouper.call([a, b, c]).size
  end

  test "keeps the same matchup separate when published far apart" do
    a = video("Houston Cougars vs Texas Tech Raiders", channel: :cfb_on_fox, hours_ago: 1, id: 1)
    b = video("Houston Cougars vs Texas Tech Raiders", channel: :espn_cfb, hours_ago: 100, id: 2)

    assert_equal 2, VideoGrouper.call([a, b]).size
  end

  test "does not group across competitions" do
    a = video("Liverpool vs Arsenal", channel: :nbc_sports, competition: :premier_league, id: 1)
    b = video("Liverpool vs Arsenal", channel: :cbs_golazo, competition: :champions_league, id: 2)

    assert_equal 2, VideoGrouper.call([a, b]).size
  end

  test "never merges two uploads from the same channel" do
    a = video("Houston Cougars vs Texas Tech Raiders", channel: :espn_cfb, hours_ago: 1, id: 1)
    b = video("Houston Cougars vs Texas Tech Raiders", channel: :espn_cfb, hours_ago: 2, id: 2)

    assert_equal 2, VideoGrouper.call([a, b]).size
  end

  test "leaves titles without a matchup separator alone" do
    a = video("Houston highlights", channel: :cfb_on_fox, id: 1)
    b = video("Houston highlights", channel: :espn_cfb, id: 2)

    assert_equal 2, VideoGrouper.call([a, b]).size
  end
end
