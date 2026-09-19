module Youtube
  # YouTube push notifications via WebSub (PubSubHubbub). We subscribe each
  # channel's Atom feed at Google's hub; the hub then POSTs to our webhook when
  # a video is published or updated. Costs no Data API quota.
  #
  # Config (env): PUBLIC_BASE_URL (the app's public https origin) and
  # YOUTUBE_WEBSUB_SECRET (HMAC key the hub signs notifications with).
  class WebSub
    class Error < StandardError; end
    class NotConfigured < Error; end

    HUB_URL = "https://pubsubhubbub.appspot.com/subscribe".freeze
    TOPIC_URL = "https://www.youtube.com/xml/feeds/videos.xml".freeze
    CALLBACK_PATH = "/api/v1/youtube/webhook".freeze
    LEASE_SECONDS = 5.days.to_i
    # The hub verifies our callback before it answers, even for hub.verify=async,
    # and routinely takes 10-20s to reply — well past our usual 15s API timeout.
    HUB_TIMEOUT = 60
    SIGNATURE_ALGORITHMS = { "sha1" => "SHA1", "sha256" => "SHA256" }.freeze

    def self.topic_for(youtube_channel_id)
      "#{TOPIC_URL}?channel_id=#{youtube_channel_id}"
    end

    def self.channel_id_from_topic(topic)
      Rack::Utils.parse_query(URI(topic.to_s).query)["channel_id"]
    rescue URI::InvalidURIError
      nil
    end

    def self.secret
      ENV["YOUTUBE_WEBSUB_SECRET"].presence
    end

    def self.configured?
      secret.present? && ENV["PUBLIC_BASE_URL"].present?
    end

    # Checks the hub's "X-Hub-Signature: sha1=<hex>" header against the raw body.
    def self.valid_signature?(body, header)
      return false if secret.blank? || header.blank?

      algorithm, signature = header.split("=", 2)
      digest = SIGNATURE_ALGORITHMS[algorithm]
      return false if digest.nil? || signature.blank?

      expected = OpenSSL::HMAC.hexdigest(digest, secret, body.to_s)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    # Asks the hub to (re)subscribe the channel. The hub verifies asynchronously
    # by GETting our webhook; a 202 here only means the request was accepted.
    def subscribe(channel)
      raise NotConfigured, "PUBLIC_BASE_URL and YOUTUBE_WEBSUB_SECRET must be set" unless self.class.configured?

      connection.post(
        HUB_URL,
        "hub.mode" => "subscribe",
        "hub.topic" => self.class.topic_for(channel.youtube_channel_id),
        "hub.callback" => callback_url,
        "hub.verify" => "async",
        "hub.secret" => self.class.secret,
        "hub.lease_seconds" => LEASE_SECONDS
      )
      channel.update!(websub_expires_at: LEASE_SECONDS.seconds.from_now)
    rescue Faraday::Error => e
      raise Error, "WebSub subscribe failed for #{channel.name} (#{e.try(:response_status) || e.class})"
    end

    private

    def callback_url
      ENV.fetch("PUBLIC_BASE_URL").chomp("/") + CALLBACK_PATH
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.request :url_encoded
        f.options.timeout = HUB_TIMEOUT
        f.options.open_timeout = 5
        f.response :raise_error
      end
    end
  end
end
