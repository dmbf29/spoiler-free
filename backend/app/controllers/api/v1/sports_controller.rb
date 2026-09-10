module Api
  module V1
    class SportsController < Api::BaseController
      # GET /api/v1/sports
      # Only sports that have at least one active (classified/displayed) competition.
      def index
        sports = Sport.joins(:competitions)
                      .where(competitions: { active: true })
                      .distinct
                      .order(:name)
                      .includes(:competitions)

        render json: SportSerializer.list(sports)
      end
    end
  end
end
