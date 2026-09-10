require "test_helper"

class VideoClassifierTest < ActiveSupport::TestCase
  setup do
    @classifier = VideoClassifier.new(competitions: [competitions(:premier_league)])
  end

  def upload(title)
    Youtube::Upload.new("id" => "x", "snippet" => { "title" => title })
  end

  test "classifies an NBC Premier League highlight with a spoiler-safe title" do
    result = @classifier.classify(
      upload("Everton v. Manchester United | PREMIER LEAGUE HIGHLIGHTS | 9/6/2026 | NBC Sports")
    )

    assert result.highlight?
    assert_equal competitions(:premier_league), result.competition
    assert_equal "Everton vs Manchester United", result.safe_title
  end

  test "rejects reaction / analysis / press conference videos" do
    [
      "INSTANT REACTION to Everton v. Manchester United | NBC Sports",
      "Tactical ANALYSIS: how City broke down the press | NBC Sports",
      "Arne Slot press conference | Premier League"
    ].each do |title|
      refute @classifier.classify(upload(title)).highlight?, title
    end
  end

  test "rejects a video with no highlight keyword" do
    refute @classifier.classify(upload("Everton v. Manchester United | FULL MATCH | NBC Sports")).highlight?
  end

  test "rejects a highlight for a competition that is not active / has no rule" do
    result = @classifier.classify(
      upload("Wisconsin vs. Notre Dame | COLLEGE FOOTBALL HIGHLIGHTS | 9/6/2026 | NBC Sports")
    )

    refute result.highlight?
  end

  test "spoiler-safe title never leaks the original title's score" do
    result = @classifier.classify(
      upload("Oregon 34-27 Boise State | PREMIER LEAGUE HIGHLIGHTS | NBC Sports")
    )
    # Not a real PL title format, but if it ever matched it must not contain digits/score.
    assert_nil result.safe_title
  end

end

# --- Champions League (CBS Sports Golazo) ---------------------------------------
class VideoClassifierChampionsLeagueTest < ActiveSupport::TestCase
  setup do
    @classifier = VideoClassifier.new(
      competitions: [competitions(:premier_league), competitions(:champions_league)]
    )
  end

  def upload(title)
    Youtube::Upload.new("id" => "x", "snippet" => { "title" => title })
  end

  test "classifies a CBS Golazo UCL highlight and strips the ': Extended Highlights' suffix" do
    result = @classifier.classify(
      upload("Liverpool vs. Atlético Madrid: Extended Highlights | UCL League Phase MD 1 | CBS Sports Golazo")
    )

    assert result.highlight?
    assert_equal competitions(:champions_league), result.competition
    assert_equal "Liverpool vs Atlético Madrid", result.safe_title
  end

  test "handles non-English club names" do
    result = @classifier.classify(
      upload("Sporting CP vs. Galatasaray: Extended Highlights | UCL League Phase MD 1 | CBS Sports Golazo")
    )
    assert_equal "Sporting CP vs Galatasaray", result.safe_title
  end

  test "does not match CBS Europa League or studio-show uploads" do
    [
      "Roma vs. Nice: Extended Highlights | UEL League Phase MD 1 | CBS Sports Golazo",
      "Who wins the UCL this season? | Champions League Today | CBS Sports Golazo",
      "Extended Highlights: the best UCL goals of Matchday 1 | CBS Sports Golazo"
    ].each do |title|
      refute @classifier.classify(upload(title)).highlight?, title
    end
  end

  test "still classifies Premier League correctly when both rules are active" do
    result = @classifier.classify(
      upload("Fulham v. Crystal Palace | PREMIER LEAGUE HIGHLIGHTS | 9/5/2026 | NBC Sports")
    )
    assert_equal competitions(:premier_league), result.competition
    assert_equal "Fulham vs Crystal Palace", result.safe_title
  end
end
