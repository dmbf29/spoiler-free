module Api
  module V1
    class VideosController < Api::BaseController
      # GET /api/v1/videos
      # Optional filters: ?sport=<slug>&competition=<slug>
      def index
        videos = Video.displayable
                      .recent
                      .includes(competition: :sport)

        videos = videos.where(competitions: { slug: params[:competition] }) if params[:competition].present?
        videos = videos.where(sports: { slug: params[:sport] }) if params[:sport].present?

        # `references` so the sport/competition filters can hit the joined tables.
        videos = videos.references(competition: :sport) if params[:sport].present? || params[:competition].present?

        render json: VideoSerializer.list(videos)
      end
    end
  end
end
