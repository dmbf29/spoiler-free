# Orchestrates a sync across every active channel. One channel failing (API
# error, bad data) must not stop the others.
class FetchYoutubeVideosJob < ApplicationJob
  queue_as :default

  def perform
    Channel.active.find_each do |channel|
      summary = ChannelSynchronizer.new(channel).call
      Rails.logger.info("[FetchYoutubeVideosJob] #{summary}")
    rescue Youtube::Client::Error => e
      Rails.logger.error("[FetchYoutubeVideosJob] #{channel.name} failed: #{e.message}")
    end
  end
end
