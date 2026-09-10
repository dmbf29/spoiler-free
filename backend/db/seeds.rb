# Idempotent seeds. Run with: bin/rails db:seed
# Attributes are updated on re-run (e.g. flipping a competition's `active` flag).

# --- Sports -------------------------------------------------------------------
soccer = Sport.find_or_create_by!(slug: "soccer") { |s| s.name = "Soccer" }
football = Sport.find_or_create_by!(slug: "football") { |s| s.name = "Football" }

# --- Competitions -----------------------------------------------------------------
# `active: true`  -> classified and shown in the UI
# `active: false` -> seeded for later, safely ignored for now
competitions = [
  {
    slug: "premier-league",
    name: "Premier League",
    sport: soccer,
    active: true,
    video_naming_convention: "Home v. Away | PREMIER LEAGUE HIGHLIGHTS | M/D/YYYY | NBC Sports"
  },
  {
    slug: "champions-league",
    name: "Champions League",
    sport: soccer,
    active: true,
    video_naming_convention: "Home vs. Away: Extended Highlights | UCL League Phase MD N | CBS Sports Golazo"
  },
  {
    slug: "college-football",
    name: "College Football",
    sport: football,
    active: false,
    video_naming_convention: "Away vs. Home | COLLEGE FOOTBALL HIGHLIGHTS | M/D/YY | NBC Sports"
  }
]

competitions.each do |attrs|
  Competition.find_or_initialize_by(slug: attrs[:slug]).update!(attrs.except(:slug))
end

# --- Channels ------------------------------------------------------------------
channels = [
  {
    youtube_channel_id: "UCqZQlzSHbVJrwrn5XvzrzcA",
    name: "NBC Sports",
    youtube_url: "https://www.youtube.com/@NBCSports",
    uploads_playlist_id: "UUqZQlzSHbVJrwrn5XvzrzcA",
    active: true
  },
  {
    youtube_channel_id: "UCET00YnetHT7tOpu12v8jxg",
    name: "CBS Sports Golazo",
    youtube_url: "https://www.youtube.com/@cbssportsgolazo",
    uploads_playlist_id: "UUET00YnetHT7tOpu12v8jxg",
    active: true
  }
]

channels.each do |attrs|
  Channel.find_or_initialize_by(youtube_channel_id: attrs[:youtube_channel_id])
         .update!(attrs.except(:youtube_channel_id))
end

puts "Seeded: #{Sport.count} sports, #{Competition.count} competitions " \
     "(#{Competition.active.count} active), #{Channel.count} channels"
