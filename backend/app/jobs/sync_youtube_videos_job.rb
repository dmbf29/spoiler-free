# Imports specific videos for one channel — the WebSub push path. The 30-minute
# FetchYoutubeVideosJob poll remains the backstop for missed notifications; both
# go through ChannelSynchronizer, so a video is only ever stored once.
class SyncYoutubeVideosJob < ApplicationJob
  queue_as :default

  retry_on Youtube::Client::Error, wait: 1.minute, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(channel_id, video_ids)
    channel = Channel.find(channel_id)
    summary = ChannelSynchronizer.new(channel).sync_videos(video_ids)
    Rails.logger.info("[SyncYoutubeVideosJob] #{summary}")
  end
end
