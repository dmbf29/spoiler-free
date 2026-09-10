# Decides whether an upload is a displayable game highlight, which supported
# competition it belongs to, and its spoiler-safe title. Deterministic and
# title-based for V1 — no API calls, no AI.
#
#   VideoClassifier.new(competitions: Competition.active).classify(upload)
#   #=> Classification::Result
class VideoClassifier
  # Any of these in the title disqualifies the video outright.
  EXCLUDE_PATTERNS = [
    /\breaction\b/i,
    /\banalysis\b/i,
    /press conference/i,
    /post-?game/i,
    /pre-?game/i,
    /\bpreview\b/i,
    /predictions?/i,
    /\bwatchalong\b/i,
    /watch along/i
  ].freeze

  # Cheap pre-filter: unless a competition rule positively claims the upload, the
  # title has to at least say "highlights". Some channels (ESPN, FOX college
  # football) drop the word, so a rule match is allowed to override this.
  INCLUDE_PATTERNS = [/highlights/i].freeze

  def initialize(competitions:)
    @competitions = competitions.to_a
  end

  def classify(upload)
    title = upload.title

    return Classification::Result.rejected("excluded keyword") if EXCLUDE_PATTERNS.any? { |p| title.match?(p) }

    @competitions.each do |competition|
      rule = Classification::TitleRules.for(competition.slug)
      next if rule.nil?

      safe_title = rule.safe_title_for(title)
      return Classification::Result.highlight(competition: competition, safe_title: safe_title) if safe_title.present?
    end

    return Classification::Result.rejected("no highlight keyword") if INCLUDE_PATTERNS.none? { |p| title.match?(p) }

    Classification::Result.rejected("no competition rule matched")
  end
end
