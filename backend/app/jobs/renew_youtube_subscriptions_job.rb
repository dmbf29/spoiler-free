# WebSub subscriptions are leases that lapse after a few days. Re-subscribes any
# active channel whose lease is missing or about to expire.
class RenewYoutubeSubscriptionsJob < ApplicationJob
  queue_as :default

  def perform
    unless Youtube::WebSub.configured?
      Rails.logger.warn("[RenewYoutubeSubscriptionsJob] PUBLIC_BASE_URL / YOUTUBE_WEBSUB_SECRET not set; skipping")
      return
    end

    web_sub = Youtube::WebSub.new
    Channel.active.needing_websub_renewal.find_each do |channel|
      web_sub.subscribe(channel)
      Rails.logger.info("[RenewYoutubeSubscriptionsJob] subscribed #{channel.name}")
    rescue Youtube::WebSub::Error => e
      Rails.logger.error("[RenewYoutubeSubscriptionsJob] #{e.message}")
    end
  end
end
