module Api
  module V1
    class GamesController < Api::BaseController
      # Saturday games are still "this week" on Sunday/Monday, so the default
      # week is the one holding the first game that kicked off in this window.
      CURRENT_WEEK_LOOKBACK = 36.hours

      # GET /api/v1/games
      # ?competition=<slug> (default college-football) &season=<year> &week=<n>
      # Without season/week, returns the current week. Response:
      # { season:, week:, weeks: [<n>, ...], games: [...] } — games chronological.
      def index
        competition = Competition.active.find_by!(slug: params.fetch(:competition, "college-football"))
        scope = competition.games.where(season_type: 2)
        season, week = season_and_week(scope)

        games = scope.for_week(season, week).chronological.includes(:home_team, :away_team, videos: :channel)
        weeks = scope.where(season: season).distinct.order(:week).pluck(:week)

        render json: { season: season, week: week, weeks: weeks, games: GameSerializer.list(games) }
      end

      private

      def season_and_week(scope)
        if params[:week].present?
          season = params[:season].presence&.to_i || scope.maximum(:season)
          return [season, params[:week].to_i]
        end

        anchor = scope.where(kickoff_at: CURRENT_WEEK_LOOKBACK.ago..).chronological.first ||
                 scope.chronological.last
        anchor ? [anchor.season, anchor.week] : [nil, nil]
      end
    end
  end
end
