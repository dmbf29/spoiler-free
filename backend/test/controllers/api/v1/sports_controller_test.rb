require "test_helper"

class Api::V1::SportsControllerTest < ActionDispatch::IntegrationTest
  test "lists sports that have an active competition, with nested competitions" do
    get "/api/v1/sports"
    assert_response :success

    body = JSON.parse(response.body)
    soccer = body.find { |s| s["slug"] == "soccer" }

    assert_equal "fa-solid fa-futbol", soccer["icon"]
    assert_includes soccer["competitions"].map { |c| c["slug"] }, "premier-league"
  end

  test "each nested competition carries a photo_url key" do
    get "/api/v1/sports"

    competitions = JSON.parse(response.body).flat_map { |s| s["competitions"] }
    assert competitions.any?
    competitions.each do |competition|
      assert competition.key?("photo_url") # nil without an attachment, present as a key
    end
  end
end
