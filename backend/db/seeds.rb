# Idempotent seeds. Run with: bin/rails db:seed

# --- Sports -------------------------------------------------------------------
soccer = Sport.find_or_create_by!(slug: "soccer") { |s| s.name = "Soccer" }
football = Sport.find_or_create_by!(slug: "football") { |s| s.name = "Football" }

# --- Competitions ----------------------------------------------------------------
# `active: true`  -> classified and shown in the UI (V1)
# `active: false` -> seeded for later (V2), safely ignored for now
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
    active: false,
    video_naming_convention: "Home v. Away | CHAMPIONS LEAGUE HIGHLIGHTS | ..."
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
  Competition.find_or_create_by!(slug: attrs[:slug]) do |c|
    c.name = attrs[:name]
    c.sport = attrs[:sport]
    c.active = attrs[:active]
    c.video_naming_convention = attrs[:video_naming_convention]
  end
end

# --- Channels ------------------------------------------------------------------
# NBC Sports (https://www.youtube.com/@NBCSports/videos)
Channel.find_or_create_by!(youtube_channel_id: "UCqZQlzSHbVJrwrn5XvzrzcA") do |ch|
  ch.name = "NBC Sports"
  ch.youtube_url = "https://www.youtube.com/@NBCSports"
  ch.uploads_playlist_id = "UUqZQlzSHbVJrwrn5XvzrzcA"
  ch.active = true
end

puts "Seeded: #{Sport.count} sports, #{Competition.count} competitions " \
     "(#{Competition.active.count} active), #{Channel.count} channels"
