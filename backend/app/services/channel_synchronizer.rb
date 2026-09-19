# Orchestrates syncing one channel: fetch recent uploads from YouTube, skip
# ones we already have, classify the rest, and persist them. Callable from the
# console, a rake task, or FetchYoutubeVideosJob.
#
#   ChannelSynchronizer.new(Channel.first).call
class ChannelSynchronizer
  Summary = Struct.new(:channel, :fetched, :new_videos, :highlights, :skipped, keyword_init: true) do
    def to_s
      "#{channel.name}: fetched=#{fetched} new=#{new_videos} highlights=#{highlights} skipped_existing=#{skipped}"
    end
  end

  # How many of the channel's most recent uploads to look at per sync. High-volume
  # channels like NBC Sports post ~30-40 videos/day (podcasts, shows, other
  # sports), so match highlights get buried quickly — 50 only reaches ~1.5 days
  # back. Cost is ~1 quota unit per 50 items for playlistItems + the same for
  # videos.list, so 300 is ~12 units/sync (quota is 10k/day).
  DEFAULT_LOOKBACK = 300

  def initialize(channel, client: Youtube::Client.new, lookback: DEFAULT_LOOKBACK)
    @channel = channel
    @client = client
    @lookback = lookback
    @classifier = VideoClassifier.new(competitions: Competition.active.includes(:sport))
  end

  def call
    playlist_id = resolve_uploads_playlist_id
    recent_ids = recent_upload_ids(playlist_id)

    summary = import(recent_ids)
    @channel.update!(last_synced_at: Time.current)
    summary
  end

  # Import specific videos (e.g. ones YouTube pushed to us via WebSub) without
  # walking the uploads playlist. Same skip-known/classify/persist pipeline as
  # #call, so a video seen by both the push and the poll is only stored once.
  def sync_videos(video_ids)
    import(Array(video_ids).uniq)
  end

  private

  def import(ids)
    new_ids = ids - Video.where(youtube_video_id: ids).pluck(:youtube_video_id)

    highlights = 0
    @client.videos(new_ids).each do |resource|
      upload = Youtube::Upload.new(resource)
      next if upload.channel_id.present? && upload.channel_id != @channel.youtube_channel_id

      highlights += 1 if persist(upload)&.is_highlight?
    end

    Summary.new(
      channel: @channel,
      fetched: ids.size,
      new_videos: new_ids.size,
      highlights: highlights,
      skipped: ids.size - new_ids.size
    )
  end

  def resolve_uploads_playlist_id
    return @channel.uploads_playlist_id if @channel.uploads_playlist_id.present?

    id = @client.uploads_playlist_id(@channel.youtube_channel_id)
    @channel.update!(uploads_playlist_id: id)
    id
  end

  def recent_upload_ids(playlist_id)
    ids = []
    page_token = nil

    while ids.size < @lookback
      page = @client.playlist_items(playlist_id, page_token: page_token)
      ids.concat(page[:items].map { |item| item.dig("contentDetails", "videoId") }.compact)
      page_token = page[:next_page_token]
      break if page_token.blank?
    end

    ids.first(@lookback)
  end

  # Always store a row (even for non-highlights) so we never re-classify the same
  # upload on the next sync. Non-highlights get competition: nil, is_highlight: false.
  def persist(upload)
    result = @classifier.classify(upload)

    video = @channel.videos.find_or_initialize_by(youtube_video_id: upload.youtube_video_id)
    video.assign_attributes(
      competition: result.competition,
      original_title: upload.title,
      safe_title: result.safe_title,
      published_at: upload.published_at,
      duration_seconds: upload.duration_seconds,
      is_highlight: result.highlight?,
      region_restricted: upload.region_restricted?,
      region_restriction: upload.region_restriction,
      embeddable: upload.embeddable?,
      raw_payload: upload.raw
    )
    video.save!
    video
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # A concurrent sync (the poll and a WebSub push can overlap) saved this
    # video between our "is it known?" check and the insert. The unique index on
    # youtube_video_id guarantees one row; treat the loser as a no-op.
    raise unless Video.exists?(youtube_video_id: upload.youtube_video_id)

    nil
  end
end
