module Classification
  # Deterministic, title-based rule for NBC Sports Premier League highlights, e.g.
  #   "Everton v. Manchester United | PREMIER LEAGUE HIGHLIGHTS | 9/6/2026 | NBC Sports"
  class PremierLeagueTitleRule
    REQUIRED = [/premier league/i, /highlights/i].freeze

    # Returns a spoiler-safe title ("Everton vs Manchester United") or nil.
    def safe_title_for(title)
      return unless REQUIRED.all? { |pattern| title.match?(pattern) }

      teams = MatchupParser.split(title)
      return if teams.nil?

      "#{teams[0]} vs #{teams[1]}"
    end
  end
end
