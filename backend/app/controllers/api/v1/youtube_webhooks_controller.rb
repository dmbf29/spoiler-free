module Api
  module V1
    # WebSub callback for YouTube push notifications.
    #   GET  — the hub verifying a subscription; we echo hub.challenge.
    #   POST — a "video published/updated" notification, signed with our secret.
    class YoutubeWebhooksController < ApplicationController
      def verify
        channel_id = Youtube::WebSub.channel_id_from_topic(params["hub.topic"])

        if params["hub.challenge"].present? &&
           %w[subscribe unsubscribe].include?(params["hub.mode"]) &&
           Channel.exists?(youtube_channel_id: channel_id)
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
