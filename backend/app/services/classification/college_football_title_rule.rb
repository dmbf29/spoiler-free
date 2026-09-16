module Classification
  # Deterministic, title-based rule for college football highlights. Four
  # channels carry them, with four different title shapes:
  #
  #   NBC Sports  "Wisconsin vs. Notre Dame | COLLEGE FOOTBALL HIGHLIGHTS | 9/6/25 | NBC Sports"
  #   CFB ON FOX  "Central Michigan vs New Mexico Highlights 🏈 FOX College Football"
  #   ESPN        "Louisville Cardinals vs. Ole Miss Rebels | Full Game Highlights | ESPN College Football"
  #   ESPN (hype) "Mason Heintschel 7 TDs 🔥 Miami (OH) RedHawks vs. Pittsburgh Panthers | ESPN College Football"
  #   CBS Sports  "Southern Utah Thunderbirds vs Colorado State Rams | Week 2 Condensed Game Highlights"
  #
  # MatchupParser strips the per-channel prefixes/suffixes and AP-ranking tags;
  # here we gate on a college-football signal and refuse anything that still
  # looks like it carries a score. "Condensed Game" never names the sport, so it
  # only counts as a signal because every channel we sync that uses that phrase
  # is a dedicated college-football channel — re-check this if a non-CFB channel
  # ever starts using the same phrase.
  class CollegeFootballTitleRule
    REQUIRED = [/college football|condensed game/i].freeze

    # ESPN posts "... HALFTIME HIGHLIGHTS" packages too; they aren't a full-game
    # recap and "HALFTIME" ends up glued to a team name, so drop them outright.
    REJECT = [/half-?time/i].freeze

    def safe_title_for(title)
      return unless REQUIRED.all? { |pattern| title.match?(pattern) }
      return if REJECT.any? { |pattern| title.match?(pattern) }

      teams = MatchupParser.split(title)
      return if teams.nil?
      return if teams.any? { |team| team.match?(/\d/) } # never let a score slip through

      "#{teams[0]} vs #{teams[1]}"
    end
  end
end
