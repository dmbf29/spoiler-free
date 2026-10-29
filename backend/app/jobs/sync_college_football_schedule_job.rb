# Keeps the college football schedule fresh: kickoff times and TV move around,
# and game status flips to in_progress/final on game days. One ESPN call per
# week, so running it every 30 minutes is cheap.
class SyncCollegeFootballScheduleJob < ApplicationJob
  queue_as :default

  retry_on Espn::Client::Error, wait: 5.minutes, attempts: 3

  def perform
    competition = Competition.find_by(slug: "college-football")
    return if competition&.api_url.blank?

    ScheduleSynchronizer.new(competition).sync_current.each do |summary|
      Rails.logger.info("[SyncCollegeFootballScheduleJob] #{summary}")
    end
  end
end
