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
    ids = JSON.parse(response.body).map { |v| v["youtube_video_id"] }
    refute_includes ids, "misc_reaction_video"
  end

  test "exposes normalized region_restriction (not the raw YouTube shape)" do
    get "/api/v1/videos"
    body = JSON.parse(response.body)

    restricted = body.find { |v| v["youtube_video_id"] == "pl_everton_manutd" }
    assert_equal true, restricted["region_restricted"]
    assert_equal "allowed", restricted.dig("region_restriction", "mode")
    assert_equal %w[US GU PR VI], restricted.dig("region_restriction", "regions")

    unrestricted = body.find { |v| v["youtube_video_id"] == "pl_brentford_sunderland" }
    assert_nil unrestricted["region_restriction"]
  end

  test "includes the sport icon and a competition photo_url key" do
    get "/api/v1/videos"
    video = JSON.parse(response.body).first

    assert_equal "fa-solid fa-futbol", video.dig("sport", "icon")
    assert video["competition"].key?("photo_url") # nil without an attachment, present as a key
  end
end
