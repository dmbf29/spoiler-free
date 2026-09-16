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
      channel: channel_json,
      published_at: @video.published_at&.iso8601,
      duration_seconds: @video.duration_seconds,
      duration_iso8601: @video.duration_iso8601,
      youtube_video_id: @video.youtube_video_id,
      region_restricted: @video.region_restricted,
      region_restriction: region_restriction_json,
      embeddable: @video.embeddable
    }
  end

  private

  # Normalizes the raw YouTube shape into { mode:, regions: } (or nil). Region
  # codes aren't spoilers, so unlike original_title/raw_payload this is safe to
  # expose.
  def region_restriction_json
    data = @video.region_restriction
    return if data.blank?

    if data["allowed"].present?
      { mode: "allowed", regions: Array(data["allowed"]) }
    elsif data["blocked"].present?
      { mode: "blocked", regions: Array(data["blocked"]) }
    end
  end

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

  def channel_json
    channel = @video.channel
    return if channel.nil?

    { name: channel.name }
  end

  def competition_photo_url(competition)
    return unless competition.photo.attached?

    competition.photo.url
  rescue StandardError
    nil
  end
end
