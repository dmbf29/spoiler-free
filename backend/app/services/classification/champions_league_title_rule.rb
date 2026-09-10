module Classification
  # Deterministic, title-based rule for CBS Sports Golazo Champions League
  # highlights, e.g.
  #   "Liverpool vs. Atlético Madrid: Extended Highlights | UCL League Phase MD 1 | CBS Sports Golazo"
  #
  # CBS abbreviates the competition as "UCL" (Europa League is "UEL", Conference
  # "UECL"), so matching \bUCL\b keeps us off their other competitions.
  class ChampionsLeagueTitleRule
    REQUIRED = [/\bUCL\b|UEFA Champions League|Champions League/i, /highlights/i].freeze

    def safe_title_for(title)
      return unless REQUIRED.all? { |pattern| title.match?(pattern) }

      teams = MatchupParser.split(title)
      return if teams.nil?

      "#{teams[0]} vs #{teams[1]}"
    end
  end
end
