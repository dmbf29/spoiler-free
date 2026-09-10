module Classification
  # Outcome of classifying a single upload.
  class Result
    attr_reader :competition, :safe_title, :reason

    def self.highlight(competition:, safe_title:)
      new(is_highlight: true, competition: competition, safe_title: safe_title, reason: "matched #{competition.slug}")
    end

    def self.rejected(reason)
      new(is_highlight: false, competition: nil, safe_title: nil, reason: reason)
    end

    def initialize(is_highlight:, competition:, safe_title:, reason:)
      @is_highlight = is_highlight
      @competition = competition
      @safe_title = safe_title
      @reason = reason
    end

    def highlight?
      @is_highlight
    end
  end
end
