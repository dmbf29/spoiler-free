require "test_helper"

class Api::V1::YoutubeWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SECRET = "test-websub-secret".freeze

  setup do
    @original_secret = ENV["YOUTUBE_WEBSUB_SECRET"]
    ENV["YOUTUBE_WEBSUB_SECRET"] = SECRET
    @channel = channels(:nbc_sports)
  end

  teardown { ENV["YOUTUBE_WEBSUB_SECRET"] = @original_secret }

  def atom(video_id, channel_id)
    <<~XML
      <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <id>yt:video:#{video_id}</id>
          <yt:videoId>#{video_id}</yt:videoId>
          <yt:channelId>#{channel_id}</yt:channelId>
          <title>Everton v. Manchester United | PREMIER LEAGUE HIGHLIGHTS</title>
        </entry>
      </feed>
    XML
  end

  def signature(body, secret: SECRET)
    "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', secret, body)}"
  end

  def push(body, signature: signature(body))
    post "/api/v1/youtube/webhook", params: body,
         headers: { "CONTENT_TYPE" => "application/atom+xml", "X-Hub-Signature" => signature }
  end

  test "echoes the hub challenge for a known channel" do
    get "/api/v1/youtube/webhook", params: {
      "hub.mode" => "subscribe",
      "hub.topic" => Youtube::WebSub.topic_for(@channel.youtube_channel_id),
      "hub.challenge" => "abc123",
      "hub.lease_seconds" => "432000"
    }

    assert_response :success
    assert_equal "abc123", response.body
  end

  test "rejects verification for an unknown channel" do
    get "/api/v1/youtube/webhook", params: {
      "hub.mode" => "subscribe",
      "hub.topic" => Youtube::WebSub.topic_for("UCunknown"),
      "hub.challenge" => "abc123"
    }

    assert_response :not_found
  end

  test "enqueues a sync for a correctly signed notification" do
    body = atom("newvid123", @channel.youtube_channel_id)

    assert_enqueued_with(job: SyncYoutubeVideosJob, args: [@channel.id, ["newvid123"]]) { push(body) }
    assert_response :no_content
  end

  test "ignores a notification with a bad signature" do
    body = atom("newvid123", @channel.youtube_channel_id)

    assert_no_enqueued_jobs { push(body, signature: signature(body, secret: "wrong")) }
    assert_response :no_content
  end

  test "ignores a notification with no signature" do
    body = atom("newvid123", @channel.youtube_channel_id)

    assert_no_enqueued_jobs { push(body, signature: nil) }
    assert_response :no_content
  end

  test "ignores notifications for unknown or inactive channels" do
    assert_no_enqueued_jobs do
      push(atom("v1", "UCunknown"))
      push(atom("v2", channels(:inactive_channel).youtube_channel_id))
    end
  end

  test "ignores malformed XML and deletion notices" do
    assert_no_enqueued_jobs do
      push("<feed><entry>")
      push('<feed xmlns:at="http://purl.org/atompub/tombstones/1.0"><at:deleted-entry ref="yt:video:x"/></feed>')
    end
    assert_response :no_content
  end
end
