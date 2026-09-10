# Plain serializer that emits ONLY spoiler-safe fields. The raw YouTube title
# (original_title) and raw_payload are deliberately never included here.
class VideoSerializer
  def self.list(videos)
    videos.map { |video| new(video).as_json }
  end

  def initialize(video)
    @video = video
  end

  def as_json
    {
      id: @video.id,
      safe_title: @video.safe_title,
      sport: sport_json,
      competition: competition_json,
      published_at: @video.published_at&.iso8601,
      duration_seconds: @video.duration_seconds,
      duration_iso8601: @video.duration_iso8601,
      youtube_video_id: @video.youtube_video_id,
      region_restricted: @video.region_restricted,
      embeddable: @video.embeddable
    }
  end

  private

  def sport_json
    sport = @video.competition&.sport
    return if sport.nil?

    { name: sport.name, slug: sport.slug, icon: sport.font_awesome_class }
  end

  def competition_json
    competition = @video.competition
    return if competition.nil?

    { name: competition.name, slug: competition.slug, photo_url: competition_photo_url(competition) }
  end

  def competition_photo_url(competition)
    return unless competition.photo.attached?

    competition.photo.url
  rescue StandardError
    nil
  end
end
