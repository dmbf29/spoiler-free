# Plain serializer for the schedule. Emits only what Game stores — kickoff, TV,
# teams and a coarse status — and never a score, record or result.
class GameSerializer
  def self.list(games)
    games.map { |game| new(game).as_json }
  end

  def initialize(game)
    @game = game
  end

  def as_json
    {
      id: @game.id,
      week: @game.week,
      kickoff_at: @game.kickoff_at.iso8601,
      status: @game.status,
      tv: @game.tv,
      neutral_site: @game.neutral_site,
      home_team: team_json(@game.home_team, @game.home_rank),
      away_team: team_json(@game.away_team, @game.away_rank),
      highlights: highlights_json
    }
  end

  private

  # Playable uploads of this game, one per channel, in the same shape as
  # /videos sources. Only displayable highlights are ever linked to a game.
  def highlights_json
    @game.videos.select(&:is_highlight?).sort_by(&:published_at).map { |video| VideoSerializer.source(video) }
  end

  def team_json(team, rank)
    {
      name: team.name,
      short_name: team.short_name,
      abbreviation: team.abbreviation,
      logo_url: team.logo_url,
      color: team.color,
      conference: team.conference,
      rank: rank
    }
  end
end
