module Api
  module V1
    # WebSub callback for YouTube push notifications.
    #   GET  — the hub verifying a subscription; we echo hub.challenge.
    #   POST — a "video published/updated" notification, signed with our secret.
    class YoutubeWebhooksController < ApplicationController
      def verify
        channel = Channel.find_by(youtube_channel_id: Youtube::WebSub.channel_id_from_topic(params["hub.topic"]))

        if channel && params["hub.challenge"].present? &&
           %w[subscribe unsubscribe].include?(params["hub.mode"])
          record_lease(channel)
          render plain: params["hub.challenge"]
        else
          head :not_found
        end
      end

      def receive
        # The spec wants a 2xx even for a bad signature (the hub would just
        # retry); we simply don't act on it.
        if Youtube::WebSub.valid_signature?(request.raw_post, request.headers["X-Hub-Signature"])
          enqueue_syncs(Youtube::PushNotification.parse(request.raw_post))
        end

        head :no_content
      end

      private

      # The hub only calls this once it has accepted the subscription, so this is
      # the moment we are truly subscribed (and for how long).
      def record_lease(channel)
        case params["hub.mode"]
        when "subscribe"
          lease = params["hub.lease_seconds"].to_i
          lease = Youtube::WebSub::LEASE_SECONDS unless lease.positive?
          channel.update!(websub_expires_at: lease.seconds.from_now)
        when "unsubscribe"
          channel.update!(websub_expires_at: nil)
        end
      end

      def enqueue_syncs(entries)
        entries.group_by(&:channel_id).each do |youtube_channel_id, channel_entries|
          channel = Channel.active.find_by(youtube_channel_id: youtube_channel_id)
          next if channel.nil?

          SyncYoutubeVideosJob.perform_later(channel.id, channel_entries.map(&:video_id).uniq)
        end
      end
    end
  end
end
