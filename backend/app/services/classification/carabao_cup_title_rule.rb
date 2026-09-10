module Classification
  # Deterministic, title-based rule for CBS Sports Golazo Carabao Cup (EFL Cup)
  # highlights, e.g.
  #   "Chelsea vs. Leeds United: Extended Highlights | Carabao Cup | CBS Sports Golazo"
  #
  # CBS names the competition "Carabao Cup" in the pipe-delimited middle segment;
  # that keeps us off their other English competitions and off the UCL rule
  # (which gates on \bUCL\b / "Champions League").
  class CarabaoCupTitleRule
    REQUIRED = [/carabao cup/i, /highlights/i].freeze

    def safe_title_for(title)
      return unless REQUIRED.all? { |pattern| title.match?(pattern) }

      teams = MatchupParser.split(title)
      return if teams.nil?

      "#{teams[0]} vs #{teams[1]}"
    end
  end
end
