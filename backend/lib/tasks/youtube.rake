namespace :youtube do
  desc "Sync recent uploads for all active channels (runs inline, not via the queue)"
  task sync: :environment do
    Channel.active.find_each do |channel|
      puts ChannelSynchronizer.new(channel).call
    rescue Youtube::Client::Error => e
      warn "#{channel.name} failed: #{e.message}"
    end
  end

  desc "Sync one channel by id, e.g. bin/rails 'youtube:sync_channel[1]'"
  task :sync_channel, [:channel_id] => :environment do |_t, args|
    channel = Channel.find(args.fetch(:channel_id))
    puts ChannelSynchronizer.new(channel).call
  end

  desc "Enqueue FetchYoutubeVideosJob on the background queue"
  task enqueue_sync: :environment do
    FetchYoutubeVideosJob.perform_later
    puts "Enqueued FetchYoutubeVideosJob"
  end

  desc "(Re)subscribe every active channel to YouTube push notifications (WebSub). " \
       "Needs PUBLIC_BASE_URL and YOUTUBE_WEBSUB_SECRET."
  task subscribe: :environment do
    web_sub = Youtube::WebSub.new
    Channel.active.find_each do |channel|
      web_sub.subscribe(channel)
      puts "Requested subscription for #{channel.name} (hub accepted; run youtube:status to confirm)"
    rescue Youtube::WebSub::Error => e
      warn e.message
    end
  end

  desc "Show push-notification (WebSub) status per channel: our recorded lease, " \
       "plus what Google's hub reports. Run where YOUTUBE_WEBSUB_SECRET is set."
  task status: :environment do
    web_sub = Youtube::WebSub.new
    Channel.active.order(:name).each do |channel|
      lease = channel.websub_expires_at
      ours = lease && lease > Time.current ? "subscribed until #{lease.utc}" : "NOT subscribed (no verified lease)"
      puts "#{channel.name}: #{ours}"
      next unless Youtube::WebSub.configured?

      begin
        web_sub.hub_status(channel).each { |line| puts "    hub: #{line}" }
      rescue Youtube::WebSub::Error => e
        puts "    hub: #{e.message}"
      end
    end
  end

  desc "Re-run the classifier over already-stored uploads: promotes newly-matching " \
       "ones and demotes highlights that no longer qualify. No API calls."
  task reclassify: :environment do
    classifier = VideoClassifier.new(competitions: Competition.active.includes(:sport))
    promoted = 0
    demoted = 0

    Video.find_each do |video|
      upload = Youtube::Upload.new("snippet" => { "title" => video.original_title })
      result = classifier.classify(upload)

      if result.highlight? && !video.is_highlight?
        video.update!(competition: result.competition, safe_title: result.safe_title, is_highlight: true)
        promoted += 1
        puts "  + #{result.competition.slug}: #{result.safe_title}"
      elsif !result.highlight? && video.is_highlight?
        video.update!(competition: nil, safe_title: nil, is_highlight: false)
        demoted += 1
        puts "  - #{video.original_title}"
      end
    end

    puts "Reclassified stored uploads: #{promoted} promoted, #{demoted} demoted."
  end
end
