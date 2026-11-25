require "test_helper"

class Espn::EventTest < ActiveSupport::TestCase
  def event(state:, name: "STATUS_X")
    Espn::Event.new(
      "id" => "1", "date" => "2026-10-31T16:00Z",
      "status" => { "type" => { "state" => state, "name" => name } },
      "competitions" => [ { "competitors" => [] } ]
    )
  end

  test "maps ESPN states to our statuses" do
    assert_equal "scheduled", event(state: "pre").status
    assert_equal "in_progress", event(state: "in").status
    assert_equal "final", event(state: "post").status
    assert_equal "postponed", event(state: "post", name: "STATUS_POSTPONED").status
    assert_equal "canceled", event(state: "post", name: "STATUS_CANCELED").status
  end

  test "parses ESPN's seconds-less timestamps as UTC" do
    assert_equal Time.utc(2026, 10, 31, 16), event(state: "pre").kickoff_at
  end

  def matchup(home_id, away_id)
    Espn::Event.new(
      "id" => "1", "date" => "2026-12-05T19:00Z",
      "competitions" => [ { "competitors" => [
        { "homeAway" => "home", "team" => { "id" => home_id, "displayName" => "TBD" } },
        { "homeAway" => "away", "team" => { "id" => away_id, "displayName" => "TBD" } }
      ] } ]
    )
  end

  test "complete only when both sides are real teams" do
    assert matchup("251", "333").complete?
    refute matchup("-1", "-2").complete?, "ESPN's TBD placeholders use negative ids"
    refute matchup("251", "-1").complete?
    refute matchup("251", nil).complete?
  end

  test "exposes no score, record or leader readers" do
    readers = Espn::Event.public_instance_methods(false).map(&:to_s)
    assert_empty readers.grep(/score|record|leader|result|winner/)
  end
end
