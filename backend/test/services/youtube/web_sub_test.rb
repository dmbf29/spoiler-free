require "test_helper"

class Youtube::WebSubTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h.slice("YOUTUBE_WEBSUB_SECRET", "PUBLIC_BASE_URL")
    ENV["YOUTUBE_WEBSUB_SECRET"] = "s3cret"
    ENV["PUBLIC_BASE_URL"] = "https://spoilerfree.example.com/"
  end

  teardown do
    %w[YOUTUBE_WEBSUB_SECRET PUBLIC_BASE_URL].each { |k| ENV[k] = @env[k] }
  end

  test "extracts the channel id from a topic url" do
    topic = Youtube::WebSub.topic_for("UCabc")
    assert_equal "UCabc", Youtube::WebSub.channel_id_from_topic(topic)
    assert_nil Youtube::WebSub.channel_id_from_topic("not a url")
    assert_nil Youtube::WebSub.channel_id_from_topic(nil)
  end

  test "validates signatures" do
    good = "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', 's3cret', 'body')}"
    assert Youtube::WebSub.valid_signature?("body", good)
    refute Youtube::WebSub.valid_signature?("tampered", good)
    refute Youtube::WebSub.valid_signature?("body", "md5=abc")
    refute Youtube::WebSub.valid_signature?("body", nil)
  end

  test "subscribe posts to the hub but does not claim a lease until the hub verifies" do
    channel = channels(:nbc_sports)
    captured = nil
    fake = Object.new
    fake.define_singleton_method(:post) { |url, params| captured = [url, params] }

    web_sub = Youtube::WebSub.new
    web_sub.instance_variable_set(:@connection, fake)
    web_sub.subscribe(channel)

    url, params = captured
    assert_equal Youtube::WebSub::HUB_URL, url
    assert_equal "subscribe", params["hub.mode"]
    assert_equal Youtube::WebSub.topic_for(channel.youtube_channel_id), params["hub.topic"]
    assert_equal "https://spoilerfree.example.com/api/v1/youtube/webhook", params["hub.callback"]
    assert_nil channel.reload.websub_expires_at
  end

  test "hub_status returns the details text, without the last delivered entry (it carries the original title)" do
    page = <<~HTML
      <html><body><style>.x{}</style><h1>PubSubHubbub Hub</h1>
      <h2>Subscription Details</h2><p>https://example/topic</p>
      <h3>State</h3><p>verified</p><h3>Expires</h3><p>2026-10-26</p>
      <pre>&lt;entry&gt;&lt;title&gt;Team A 3-1 Team B&lt;/title&gt;&lt;/entry&gt;</pre>
      <p>These legal disclaimers are here because...</p><script>svg4everybody();</script></body></html>
    HTML
    fake = Object.new
    fake.define_singleton_method(:get) { |_url, _params| Struct.new(:body).new(page) }
    web_sub = Youtube::WebSub.new
    web_sub.instance_variable_set(:@connection, fake)

    assert_equal ["https://example/topic", "State", "verified", "Expires", "2026-10-26"],
                 web_sub.hub_status(channels(:nbc_sports))
  end

  test "subscribe refuses to run unconfigured" do
    ENV["PUBLIC_BASE_URL"] = nil
    assert_raises(Youtube::WebSub::NotConfigured) { Youtube::WebSub.new.subscribe(channels(:nbc_sports)) }
  end

  test "renewal scope picks channels with no or soon-expiring leases" do
    fresh = channels(:nbc_sports).tap { |c| c.update!(websub_expires_at: 4.days.from_now) }
    expiring = channels(:cbs_golazo).tap { |c| c.update!(websub_expires_at: 1.day.from_now) }
    never = channels(:cfb_on_fox)

    needing = Channel.needing_websub_renewal
    assert_includes needing, expiring
    assert_includes needing, never
    refute_includes needing, fresh
  end
end
