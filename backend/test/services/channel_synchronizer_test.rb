require "test_helper"

class ChannelSynchronizerTest < ActiveSupport::TestCase
  # Stands in for Youtube::Client; records which ids were fetched.
  class FakeClient
    attr_reader :fetched_ids

    def initialize(resources)
      @resources = resources
      @fetched_ids = []
    end

    def videos(ids)
      @fetched_ids.concat(ids)
      @resources.select { |r| ids.include?(r["id"]) }
    end
  end

  setup do
    @channel = channels(:nbc_sports)
  end

  def resource(id, title: "Newcastle v. Arsenal | PREMIER LEAGUE HIGHLIGHTS | 9/13/2026 | NBC Sports",
               channel_id: @channel.youtube_channel_id)
    {
      "id" => id,
      "snippet" => { "title" => title, "channelId" => channel_id, "publishedAt" => "2026-09-13T20:00:00Z" },
      "contentDetails" => { "duration" => "PT8M30S" }
    }
  end

  test "sync_videos stores a pushed highlight once" do
    client = FakeClient.new([resource("push_new")])
    sync = ChannelSynchronizer.new(@channel, client: client)

    assert_difference -> { Video.where(youtube_video_id: "push_new").count }, 1 do
      summary = sync.sync_videos(["push_new"])
      assert_equal 1, summary.new_videos
      assert_equal 1, summary.highlights
    end

    assert_equal "Newcastle vs Arsenal", Video.find_by!(youtube_video_id: "push_new").safe_title
  end

  test "a video already stored (e.g. by the poll) is skipped, not re-fetched or duplicated" do
    client = FakeClient.new([resource("pl_everton_manutd")])

    assert_no_difference "Video.count" do
      summary = ChannelSynchronizer.new(@channel, client: client).sync_videos(["pl_everton_manutd"])
      assert_equal 1, summary.skipped
    end
    assert_empty client.fetched_ids
  end

  test "duplicate ids in one push are collapsed" do
    client = FakeClient.new([resource("dup_vid")])

    assert_difference "Video.count", 1 do
      ChannelSynchronizer.new(@channel, client: client).sync_videos(%w[dup_vid dup_vid])
    end
    assert_equal ["dup_vid"], client.fetched_ids
  end

  test "losing a race to a concurrent sync is a no-op, not an error or a duplicate" do
    # Simulate the poll committing the same video between our "known?" check
    # and our insert: right before the sync saves, another writer gets in first.
    videos = @channel.videos
    original = videos.method(:find_or_initialize_by)
    channel = @channel
    racing = lambda do |**attrs|
      record = original.call(**attrs)
      record.define_singleton_method(:save!) do |*args|
        channel.videos.create!(youtube_video_id: attrs[:youtube_video_id], original_title: "x", published_at: Time.current)
        super(*args)
      end
      record
    end

    client = FakeClient.new([resource("racy")])
    videos.define_singleton_method(:find_or_initialize_by) { |**attrs| racing.call(**attrs) }

    assert_difference -> { Video.where(youtube_video_id: "racy").count }, 1 do
      summary = ChannelSynchronizer.new(@channel, client: client).sync_videos(["racy"])
      assert_equal 0, summary.highlights
    end
  end

  test "ignores a pushed video that belongs to a different channel" do
    client = FakeClient.new([resource("other_chan", channel_id: "UCsomeoneelse")])

    assert_no_difference "Video.count" do
      ChannelSynchronizer.new(@channel, client: client).sync_videos(["other_chan"])
    end
  end
end
