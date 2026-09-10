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
end
