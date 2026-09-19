module Api
  module V1
    class VideosController < Api::BaseController
      # Highlights arrive continuously, so we paginate by date range rather
      # than page number/offset (which would shift under newly-synced videos).
      DEFAULT_WINDOW = 7.days

      # GET /api/v1/videos
      # Optional filters: ?sport=<slug>&competition=<slug>
      # Optional date range (ISO8601): ?since=<time>&before=<time>. With
      # neither given, defaults to the last 7 days.
      def index
        videos = Video.displayable
                      .recent
                      .includes(:channel, competition: [:sport, { photo_attachment: :blob }])

        videos = videos.where(competitions: { slug: params[:competition] }) if params[:competition].present?
        videos = videos.where(sports: { slug: params[:sport] }) if params[:sport].present?

        # `references` so the sport/competition filters can hit the joined tables.
        videos = videos.references(competition: :sport) if params[:sport].present? || params[:competition].present?

        since = parse_time(params[:since])
        before = parse_time(params[:before])
        since ||= DEFAULT_WINDOW.ago if since.nil? && before.nil?

        videos = videos.where(published_at: since..) if since
        videos = videos.where(published_at: ...before) if before

        render json: VideoSerializer.list(videos)
      end

      private

      def parse_time(value)
        return if value.blank?

        Time.iso8601(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
