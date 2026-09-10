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
end
