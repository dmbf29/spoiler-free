require "test_helper"

class Api::V1::VideosControllerTest < ActionDispatch::IntegrationTest
  test "returns displayable highlights, newest first" do
    get "/api/v1/videos"
    assert_response :success

    body = JSON.parse(response.body)
    titles = body.map { |v| v["safe_title"] }
    assert_equal ["Everton vs Manchester United", "Brentford vs Sunderland"], titles
  end

  test "never exposes the original YouTube title or raw payload" do
    get "/api/v1/videos"
    raw = response.body

    refute_includes raw, "original_title"
    refute_includes raw, "raw_payload"
    refute_includes raw, "PREMIER LEAGUE HIGHLIGHTS"
  end

  test "filters by competition slug" do
    get "/api/v1/videos", params: { competition: "champions-league" }
    assert_response :success
    assert_empty JSON.parse(response.body)
  end

  test "excludes non-highlight videos" do
    get "/api/v1/videos"
    ids = source_ids(JSON.parse(response.body))
    refute_includes ids, "misc_reaction_video"
  end

  test "exposes normalized region_restriction (not the raw YouTube shape)" do
    get "/api/v1/videos"
    body = JSON.parse(response.body)

    restricted = find_source(body, "pl_everton_manutd")
    assert_equal true, restricted["region_restricted"]
    assert_equal "allowed", restricted.dig("region_restriction", "mode")
    assert_equal %w[US GU PR VI], restricted.dig("region_restriction", "regions")

    unrestricted = find_source(body, "pl_brentford_sunderland")
    assert_nil unrestricted["region_restriction"]
  end

  test "includes the sport icon and a competition photo_url key" do
    get "/api/v1/videos"
    video = JSON.parse(response.body).first

    assert_equal "fa-solid fa-futbol", video.dig("sport", "icon")
    assert video["competition"].key?("photo_url") # nil without an attachment, present as a key
  end

  test "includes the channel's YouTube link, for the frontend's sourced-from strip" do
    get "/api/v1/videos"
    source = find_source(JSON.parse(response.body), "pl_everton_manutd")

    assert_equal "NBC Sports", source.dig("channel", "name")
    assert_equal "https://www.youtube.com/@NBCSports", source.dig("channel", "youtube_url")
  end

  test "defaults to the last 7 days when no date params are given" do
    get "/api/v1/videos"
    ids = source_ids(JSON.parse(response.body))

    assert_includes ids, "pl_everton_manutd"
    assert_includes ids, "pl_brentford_sunderland"
  end

  test "since excludes videos published before the given time" do
    get "/api/v1/videos", params: { since: 12.hours.ago.iso8601 }
    ids = source_ids(JSON.parse(response.body))

    assert_includes ids, "pl_everton_manutd"
    refute_includes ids, "pl_brentford_sunderland"
  end

  test "before excludes videos published at or after the given time, for loading older pages" do
    get "/api/v1/videos", params: { before: 12.hours.ago.iso8601 }
    ids = source_ids(JSON.parse(response.body))

    refute_includes ids, "pl_everton_manutd"
    assert_includes ids, "pl_brentford_sunderland"
  end

  test "since and before together select a bounded window" do
    get "/api/v1/videos", params: { since: 36.hours.ago.iso8601, before: 12.hours.ago.iso8601 }
    ids = source_ids(JSON.parse(response.body))

    assert_equal ["pl_brentford_sunderland"], ids
  end

  test "ignores an unparseable date param instead of erroring" do
    get "/api/v1/videos", params: { since: "not-a-date" }
    assert_response :success
  end

  test "combines the same game from different channels into one item with multiple sources" do
    published = 3.hours.ago
    [[:cfb_on_fox, "Houston Cougars vs Texas Tech Red Raiders", "fox_1"],
     [:espn_cfb, "Houston Cougars vs Texas Tech Raiders", "espn_1"]].each_with_index do |(channel, title, yt), i|
      Video.create!(channel: channels(channel), competition: competitions(:college_football),
                    youtube_video_id: yt, original_title: title, safe_title: title,
                    published_at: published - i.minutes, is_highlight: true, embeddable: true, raw_payload: {})
    end

    get "/api/v1/videos", params: { competition: "college-football" }
    body = JSON.parse(response.body)

    assert_equal 1, body.size
    assert_equal %w[fox_1 espn_1], body.first["sources"].map { |s| s["youtube_video_id"] }
    assert_equal ["CFB ON FOX", "ESPN College Football"], body.first["sources"].map { |s| s.dig("channel", "name") }
  end

  private

  def source_ids(body)
    body.flat_map { |item| item["sources"].map { |s| s["youtube_video_id"] } }
  end

  def find_source(body, youtube_video_id)
    body.flat_map { |item| item["sources"] }.find { |s| s["youtube_video_id"] == youtube_video_id }
  end
end
