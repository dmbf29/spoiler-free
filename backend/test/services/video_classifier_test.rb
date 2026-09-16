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

# --- Carabao Cup (CBS Sports Golazo) -----------------------------------------
class VideoClassifierCarabaoCupTest < ActiveSupport::TestCase
  setup do
    @classifier = VideoClassifier.new(
      competitions: [
        competitions(:premier_league),
        competitions(:champions_league),
        competitions(:carabao_cup)
      ]
    )
  end

  def upload(title)
    Youtube::Upload.new("id" => "x", "snippet" => { "title" => title })
  end

  def safe_title(title)
    @classifier.classify(upload(title)).safe_title
  end

  test "classifies CBS Golazo Carabao Cup highlights with a spoiler-safe title" do
    result = @classifier.classify(
      upload("Chelsea vs. Leeds United: Extended Highlights | Carabao Cup | CBS Sports Golazo")
    )

    assert result.highlight?
    assert_equal competitions(:carabao_cup), result.competition
    assert_equal "Chelsea vs Leeds United", result.safe_title
  end

  test "handles the range of club names CBS posts for the Carabao Cup" do
    {
      "Sunderland vs. Hull City: Extended Highlights | Carabao Cup | CBS Sports Golazo" =>
        "Sunderland vs Hull City",
      "Millwall vs. Newcastle United: Extended Highlights | Carabao Cup | CBS Sports Golazo" =>
        "Millwall vs Newcastle United",
      "AFC Bournemouth vs. Lincoln City: Extended Highlights | Carabao Cup | CBS Sports Golazo" =>
        "AFC Bournemouth vs Lincoln City",
      "Tottenham vs. Charlton Athletic: Extended Highlights | Carabao Cup | CBS Sports Golazo" =>
        "Tottenham vs Charlton Athletic"
    }.each { |title, expected| assert_equal expected, safe_title(title), title }
  end

  test "does not match Carabao Cup studio-show or reaction uploads" do
    [
      "Carabao Cup draw reaction: who got the toughest tie? | CBS Sports Golazo",
      "Every Carabao Cup third round goal | CBS Sports Golazo"
    ].each do |title|
      refute @classifier.classify(upload(title)).highlight?, title
    end
  end

  test "still classifies Champions League correctly when the Carabao Cup rule is active" do
    result = @classifier.classify(
      upload("Liverpool vs. Atlético Madrid: Extended Highlights | UCL League Phase MD 1 | CBS Sports Golazo")
    )
    assert_equal competitions(:champions_league), result.competition
    assert_equal "Liverpool vs Atlético Madrid", result.safe_title
  end
end

# --- College Football (NBC Sports, CFB ON FOX, ESPN) --------------------------
class VideoClassifierCollegeFootballTest < ActiveSupport::TestCase
  setup do
    @classifier = VideoClassifier.new(
      competitions: [
        competitions(:premier_league),
        competitions(:champions_league),
        competitions(:college_football)
      ]
    )
  end

  def upload(title)
    Youtube::Upload.new("id" => "x", "snippet" => { "title" => title })
  end

  def safe_title(title)
    @classifier.classify(upload(title)).safe_title
  end

  test "classifies NBC Sports college football titles" do
    result = @classifier.classify(
      upload("Wisconsin vs. Notre Dame | COLLEGE FOOTBALL HIGHLIGHTS | 9/6/2026 | NBC Sports")
    )

    assert result.highlight?
    assert_equal competitions(:college_football), result.competition
    assert_equal "Wisconsin vs Notre Dame", result.safe_title

    assert_equal "Washington State Cougars vs Washington Huskies",
                 safe_title("Washington State Cougars vs. Washington Huskies | COLLEGE FOOTBALL HIGHLIGHTS | 9/6/26 | NBC Sports")
  end

  test "classifies CFB ON FOX titles, dropping the channel suffix and AP ranking" do
    assert_equal "Central Michigan vs New Mexico",
                 safe_title("Central Michigan vs New Mexico Highlights 🏈 FOX College Football")
    assert_equal "Hampton Pirates vs Maryland Terrapins",
                 safe_title("Hampton Pirates vs Maryland Terrapins Highlights 🏈 FOX College Football")
    assert_equal "Northern Illinois Huskies vs Iowa Hawkeyes",
                 safe_title("Northern Illinois Huskies vs No. 22 Iowa Hawkeyes Highlights 🏈 FOX College Football")
    # FOX sometimes omits the word "Highlights" entirely.
    assert_equal "Abilene Christian Wildcats vs Texas Tech Red Raiders",
                 safe_title("Abilene Christian Wildcats vs No. 12 Texas Tech Red Raiders 🏈 FOX College Football")
  end

  test "classifies ESPN titles, stripping any hype phrase before the matchup" do
    assert_equal "Louisville Cardinals vs Ole Miss Rebels",
                 safe_title("Louisville Cardinals vs. Ole Miss Rebels | Full Game Highlights | ESPN College Football")
    assert_equal "Clemson vs LSU",
                 safe_title("THE LANE KIFFIN ERA IS HERE 🤩 Clemson vs. LSU | Full Game Highlights | ESPN College Football")
    # Hype phrase carries a stat ("7 TDs") and there is no "Highlights" word.
    assert_equal "Miami (OH) RedHawks vs Pittsburgh Panthers",
                 safe_title("Mason Heintschel 7 TDs 🔥 Miami (OH) RedHawks vs. Pittsburgh Panthers | ESPN College Football")
  end

  test "rejects reaction / preview / press-conference / halftime college football uploads" do
    [
      "INSTANT REACTION: Wisconsin vs. Notre Dame | COLLEGE FOOTBALL | NBC Sports",
      "Week 2 preview 🏈 FOX College Football",
      "Ryan Day press conference | ESPN College Football",
      "Northern Illinois Huskies vs. Iowa Hawkeyes HALFTIME HIGHLIGHTS | ESPN College Football",
      "STATEMENT HALF 🔥 Ball State vs. Ohio State HALFTIME Highlights | ESPN College Football"
    ].each do |title|
      refute @classifier.classify(upload(title)).highlight?, title
    end
  end

  test "classifies CBS Sports CFB titles, which never say 'college football'" do
    assert_equal "Southern Utah Thunderbirds vs Colorado State Rams",
                 safe_title("Southern Utah Thunderbirds vs Colorado State Rams | Week 2 Condensed Game Highlights")
    assert_equal "Maryland Terrapins vs UConn Huskies",
                 safe_title("Maryland Terrapins vs UConn Huskies | Week 2 Condensed Game Highlights")
    assert_equal "Western Kentucky Hilltoppers vs Nevada Wolf Pack",
                 safe_title("Western Kentucky Hilltoppers vs Nevada Wolf Pack Highlights | Week 1 Condensed Game")
    assert_equal "Boise State Broncos vs Oregon Ducks",
                 safe_title("Boise State Broncos vs No. 2 Oregon Ducks Highlights | Week 1 Condensed Game")
    # No "Highlights" word at all here — only the rule match lets this through.
    assert_equal "Bryant Bulldogs vs Army Black Knights",
                 safe_title("Bryant Bulldogs vs Army Black Knights | Week 1 Condensed Game")
  end

  test "ignores non-game 'season highlights' compilations for a single player" do
    assert_nil safe_title("Makai Lemon 2025 USC Trojans Junior Season Highlights 🏈 FOX College Football")
  end

  test "never emits a college football safe title that contains a digit" do
    assert_nil safe_title("Oregon 34 vs. 27 Boise State | COLLEGE FOOTBALL HIGHLIGHTS | NBC Sports")
  end

  test "does not claim non-college-football highlights" do
    result = @classifier.classify(
      upload("Fulham v. Crystal Palace | PREMIER LEAGUE HIGHLIGHTS | 9/5/2026 | NBC Sports")
    )
    assert_equal competitions(:premier_league), result.competition
  end
end
