# Attaches a classified highlight to the scheduled Game it shows, by comparing
# the two team names in its safe title with the teams of games that kicked off
# shortly before the upload.
#
# Titles name teams inconsistently ("Texas Tech", "Texas Tech Red Raiders",
# "Miami (OH) RedHawks", "Michigan St."), so a side matches a team when it is
# the full ESPN name, or a known short form (ESPN short name, abbreviation,
# config/team_aliases.yml, the name without its nickname) optionally followed by words from the nickname. That
# keeps "Texas" from matching Texas Tech while accepting "Texas Longhorns".
# Order of the two sides is ignored (channels disagree on home/away).
class GameMatcher
  # Highlights are posted after the game; the earliest are a few hours after
  # kickoff and stragglers can lag by a few days.
  LOOKBACK = 5.days
  SEPARATOR = " vs ".freeze
  ALIASES_PATH = Rails.root.join("config/team_aliases.yml")

  def self.aliases
    @aliases ||= (YAML.safe_load_file(ALIASES_PATH) || {}).transform_keys(&:to_s)
  end

  # "Michigan St." / "A&M" / "Miami (OH)" -> comparable word sets.
  def self.tokens(text)
    text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase
        .gsub(/['\u2019]/, "").gsub("&", " and ").scan(/[a-z0-9]+/)
        .map { |word| word == "st" ? "state" : word }.to_set
  end

  # Returns the Game the video was attached to, or nil.
  def call(video)
    return unless video.is_highlight? && video.competition_id && video.safe_title.present?

    sides = video.safe_title.split(SEPARATOR, 2).map { |side| self.class.tokens(strip_trailer(side)) }
    return if sides.size != 2 || sides.any?(&:empty?)

    game = candidates(video).select { |candidate| same_matchup?(candidate, sides) }.max_by(&:kickoff_at)
    video.update!(game: game) if game
    game
  end

  private

  # Some channels leave cruft after the matchup in the stored title:
  # "... College Football", "... Highlights 🏈", "... FINAL MOMENTS 👀",
  # "... l Full Game Highlights l ESPN College Football".
  TRAILER = /\s+[l|]\s+.*\z|\s*\b(?:final moments|highlights?|college football)\b.*\z|\s*\p{So}.*\z/i

  def strip_trailer(side)
    side.sub(TRAILER, "")
  end

  def candidates(video)
    Game.where(competition_id: video.competition_id, kickoff_at: (video.published_at - LOOKBACK)..video.published_at)
        .includes(:home_team, :away_team)
  end

  def same_matchup?(game, sides)
    (match?(game.home_team, sides[0]) && match?(game.away_team, sides[1])) ||
      (match?(game.home_team, sides[1]) && match?(game.away_team, sides[0]))
  end

  # The full name, or a short form plus only words from the full name
  # (its nickname), e.g. "Texas Tech" + "Raiders" for Texas Tech Red Raiders.
  def match?(team, side)
    full = self.class.tokens(team.name)
    return true if side == full

    short_forms(team).any? { |short| short.subset?(side) && (side - short).subset?(full) }
  end

  def short_forms(team)
    forms = [team.short_name, team.location, team.abbreviation, *self.class.aliases[team.espn_id]]
    forms.compact.map { |form| self.class.tokens(form) }.reject(&:empty?)
  end
end
