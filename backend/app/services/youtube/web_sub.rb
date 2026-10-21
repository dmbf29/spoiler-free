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
    DETAILS_URL = "https://pubsubhubbub.appspot.com/subscription-details".freeze
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
    # by GETting our webhook; a 202 here only means the request was accepted, so
    # websub_expires_at is recorded by the webhook when verification arrives.
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
    rescue Faraday::Error => e
      raise Error, "WebSub subscribe failed for #{channel.name} (#{e.try(:response_status) || e.class})"
    end

    # What the hub itself says about this channel's subscription: the text of its
    # /subscription-details page (state, expiry, last delivery...). Needs the
    # secret we subscribed with. Returns an array of non-blank text lines.
    def hub_status(channel)
      response = connection.get(
        DETAILS_URL,
        "hub.callback" => callback_url,
        "hub.topic" => self.class.topic_for(channel.youtube_channel_id),
        "hub.secret" => self.class.secret
      )
      page_text(response.body)
    rescue Faraday::ClientError => e
      page_text(e.response&.dig(:body)).presence || raise(Error, "hub status failed (#{e.try(:response_status)})")
    rescue Faraday::Error => e
      raise Error, "hub status failed (#{e.class})"
    end

    private

    def page_text(html)
      doc = Nokogiri::HTML(html.to_s)
      doc.css("script, style").remove
      lines = doc.xpath("//body//text()").map { |node| node.text.strip }.reject(&:blank?)
      from = lines.index { |l| l.start_with?("Subscription Details") }
      to = lines.index { |l| l.start_with?("These legal disclaimers") }
      return [] unless from

      details = lines[(from + 1)...(to || lines.size)]
      # The hub appends the last delivered Atom <entry>, which carries the
      # original (spoiler-prone) video title. Never surface it.
      details.take_while { |line| !line.start_with?("<entry") }
    end

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
