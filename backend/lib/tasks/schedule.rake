namespace :schedule do
  def cfb_synchronizer
    ScheduleSynchronizer.new(Competition.find_by!(slug: "college-football"))
  end

  desc "Sync the current and next college football week from ESPN (inline)"
  task sync: :environment do
    cfb_synchronizer.sync_current.each { |summary| puts summary }
  end

  desc "Backfill every regular-season week on ESPN's calendar (inline)"
  task sync_season: :environment do
    cfb_synchronizer.sync_season.each { |summary| puts summary }
  end

  desc "Sync one week, e.g. bin/rails 'schedule:sync_week[2026,9]'"
  task :sync_week, %i[season week] => :environment do |_t, args|
    puts cfb_synchronizer.sync_week(args.fetch(:season).to_i, args.fetch(:week).to_i)
  end

  desc "Attach highlights that have no game yet to their scheduled game " \
       "(REMATCH=1 re-matches every highlight). Lists what it could not match."
  task match_videos: :environment do
    matcher = GameMatcher.new
    scope = Video.displayable.joins(:competition).merge(Competition.where(id: Game.select(:competition_id)))
    scope = scope.where(game_id: nil) unless ENV["REMATCH"].present?

    matched = 0
    scope.includes(:channel).order(:published_at).each do |video|
      if matcher.call(video)
        matched += 1
      else
        puts "  unmatched: #{video.published_at.to_date} #{video.channel.name}: #{video.safe_title}"
      end
    end
    puts "Matched #{matched} highlights to games."
  end

  desc "Highlights from the last 30 days with no game — candidates for config/team_aliases.yml"
  task unmatched: :environment do
    Video.displayable.where(game_id: nil, competition_id: Game.select(:competition_id))
         .where(published_at: 30.days.ago..).includes(:channel).order(:published_at).each do |video|
      puts "#{video.published_at.to_date} #{video.channel.name}: #{video.safe_title}"
    end
  end
end
