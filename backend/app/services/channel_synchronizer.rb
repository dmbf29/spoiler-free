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

  # How many of the channel's most recent uploads to look at per sync.
  DEFAULT_LOOKBACK = 50

  def initialize(channel, client: Youtube::Client.new, lookback: DEFAULT_LOOKBACK)
    @channel = channel
    @client = client
    @lookback = lookback
    @classifier = VideoClassifier.new(competitions: Competition.active.includes(:sport))
  end

  def call
    playlist_id = resolve_uploads_playlist_id
    recent_ids = recent_upload_ids(playlist_id)
    new_ids = recent_ids - @channel.videos.where(youtube_video_id: recent_ids).pluck(:youtube_video_id)

    highlights = 0
    @client.videos(new_ids).each do |resource|
      upload = Youtube::Upload.new(resource)
      highlights += 1 if persist(upload).is_highlight?
    end

    @channel.update!(last_synced_at: Time.current)

    Summary.new(
      channel: @channel,
      fetched: recent_ids.size,
      new_videos: new_ids.size,
      highlights: highlights,
      skipped: recent_ids.size - new_ids.size
    )
  end

  private

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
      embeddable: upload.embeddable?,
      raw_payload: upload.raw
    )
    video.save!
    video
  end
end
