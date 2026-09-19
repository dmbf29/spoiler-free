# Plain serializer that emits ONLY spoiler-safe fields. The raw YouTube title
# (original_title) and raw_payload are deliberately never included here.
class VideoSerializer
  # Each item is one game. `videos` are grouped (VideoGrouper) so the same game
  # uploaded by several channels becomes one item with several `sources`.
  def self.list(videos)
    VideoGrouper.call(videos).map { |group| new(group).as_json }
  end

  # group: videos of the same game, newest first. The lead supplies the
  # game-level fields (title, sport, competition, published_at).
  def initialize(group)
    @group = Array(group)
    @video = @group.first
  end

  def as_json
    {
      id: @video.id,
      safe_title: @video.safe_title,
      sport: sport_json,
      competition: competition_json,
      published_at: @video.published_at&.iso8601,
      sources: @group.map { |video| source_json(video) }
    }
  end

  private

  # One playable upload of the game. Region/embed flags are per-video since
  # channels can differ.
  def source_json(video)
    {
      id: video.id,
      channel: channel_json(video),
      youtube_video_id: video.youtube_video_id,
      published_at: video.published_at&.iso8601,
      duration_seconds: video.duration_seconds,
      duration_iso8601: video.duration_iso8601,
      region_restricted: video.region_restricted,
      region_restriction: region_restriction_json(video),
      embeddable: video.embeddable
    }
  end

  # Normalizes the raw YouTube shape into { mode:, regions: } (or nil). Region
  # codes aren't spoilers, so unlike original_title/raw_payload this is safe to
  # expose.
  def region_restriction_json(video)
    data = video.region_restriction
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

  def channel_json(video)
    channel = video.channel
    return if channel.nil?

    { name: channel.name, youtube_url: channel.youtube_url }
  end

  def competition_photo_url(competition)
    return unless competition.photo.attached?

    competition.photo.url
  rescue StandardError
    nil
  end
end
