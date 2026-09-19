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
      puts "Subscribed #{channel.name} (until #{channel.websub_expires_at})"
    rescue Youtube::WebSub::Error => e
      warn e.message
    end
  end

  desc "Re-run the classifier over already-stored uploads (use after activating a " \
       "competition on a channel that was synced earlier). No API calls."
  task reclassify: :environment do
    classifier = VideoClassifier.new(competitions: Competition.active.includes(:sport))
    promoted = 0

    Video.where(is_highlight: false).find_each do |video|
      upload = Youtube::Upload.new("snippet" => { "title" => video.original_title })
      result = classifier.classify(upload)
      next unless result.highlight?

      video.update!(
        competition: result.competition,
        safe_title: result.safe_title,
        is_highlight: true
      )
      promoted += 1
      puts "  + #{result.competition.slug}: #{result.safe_title}"
    end

    puts "Reclassified #{promoted} stored upload(s) into highlights."
  end
end
