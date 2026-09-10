module Classification
  # Registry mapping a competition slug to its title-parsing rule. Add a class
  # here (and flip the competition's `active` flag) to support a new competition
  # — nothing else in the pipeline changes.
  module TitleRules
    REGISTRY = {
      "premier-league" => PremierLeagueTitleRule
      # V2:
      # "champions-league" => ChampionsLeagueTitleRule,
      # "college-football" => CollegeFootballTitleRule,
    }.freeze

    module_function

    def for(competition_slug)
      klass = REGISTRY[competition_slug]
      klass&.new
    end
  end
end
