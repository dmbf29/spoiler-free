module Classification
  # Deterministic, title-based rule for college football highlights. Several
  # channels carry them, with different title shapes:
  #
  #   NBC Sports  "Wisconsin vs. Notre Dame | COLLEGE FOOTBALL HIGHLIGHTS | 9/6/25 | NBC Sports"
  #   NBC (Big Ten) "No. 19 USC Trojans vs. Penn State Nittany Lions | BIG TEN HIGHLIGHTS | 10/10/26 | NBC Sports"
  #   CFB ON FOX  "Central Michigan vs New Mexico Highlights 🏈 FOX College Football"
  #   ESPN        "Louisville Cardinals vs. Ole Miss Rebels | Full Game Highlights | ESPN College Football"
  #   ESPN (hype) "Mason Heintschel 7 TDs 🔥 Miami (OH) RedHawks vs. Pittsburgh Panthers | ESPN College Football"
  #   CBS Sports  "Southern Utah Thunderbirds vs Colorado State Rams | Week 2 Condensed Game Highlights"
  #   Big Ten     "Nebraska at Oregon | Extended Highlights | Big Ten Football | 10/17/2026"
  #   ACC         "Louisville vs. Syracuse Game Highlights | 2026 ACC Football"
  #   Big 12      "#11 Utah vs. Colorado Highlights | 2026 Monster Energy Big 12 Football"
  #
  # MatchupParser strips the per-channel prefixes/suffixes and AP-ranking tags;
  # here we gate on a college-football signal and refuse anything that still
  # looks like it carries a score. "Condensed Game" never names the sport, so it
  # only counts as a signal because every channel we sync that uses that phrase
  # is a dedicated college-football channel — re-check this if a non-CFB channel
  # ever starts using the same phrase.
  class CollegeFootballTitleRule
    #
    # NBC also labels Big Ten games "BIG TEN HIGHLIGHTS" instead of "COLLEGE
    # FOOTBALL HIGHLIGHTS". NBC's Big Ten basketball uploads would match too, but
    # the "Highlights" label is the only signal in the title; revisit if
    # basketball is ever added.
    #
    # The conference channels (Big Ten, ACC, Big 12) brand titles "<conference>
    # Football". Their channels also post non-game clips, and the Big Ten's " at "
    # separator is loose, so for these we additionally insist on "highlights" or
    # "condensed game" in the title.
    CONFERENCE_BRAND = /(?:big ten|acc|big 12) football/i
    REQUIRED = [/college football|condensed game|big ten highlights|#{CONFERENCE_BRAND}/i].freeze
    CONFERENCE_GAME = /highlights|condensed game/i

    # ESPN posts "... HALFTIME HIGHLIGHTS" packages too; they aren't a full-game
    # recap and "HALFTIME" ends up glued to a team name, so drop them outright.
    #
    # ACC Digital Network posts two uploads of every game ("Game Highlights" and
    # "Condensed Game"); keep only the highlights so each game isn't listed twice
    # (the grouper deliberately never merges two uploads from one channel).
    #
    # Big 12 also posts single-player spotlights, "Drew Mestemaker Highlights vs.
    # #20 Houston". A game recap puts "Highlights" after the matchup, so the word
    # sitting right before the separator marks a player clip.
    REJECT = [/half-?time/i, /condensed game.*\bacc football/i, /\bhighlights\s+(?:vs?\.?|at)\s/i].freeze

    def safe_title_for(title)
      return unless REQUIRED.all? { |pattern| title.match?(pattern) }
      return if REJECT.any? { |pattern| title.match?(pattern) }
      return if title.match?(CONFERENCE_BRAND) && !title.match?(CONFERENCE_GAME)

      teams = MatchupParser.split(title, allow_at: title.match?(CONFERENCE_BRAND))
      return if teams.nil?
      return if teams.any? { |team| team.match?(/\d/) } # never let a score slip through

      "#{teams[0]} vs #{teams[1]}"
    end
  end
end
