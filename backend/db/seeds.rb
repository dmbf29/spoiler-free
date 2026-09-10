# Idempotent seeds. Run with: bin/rails db:seed
# Attributes are updated on re-run (e.g. flipping a competition's `active` flag).

# --- Sports -------------------------------------------------------------------
sports = [
  { slug: "soccer", name: "Soccer", font_awesome_class: "fa-solid fa-futbol" },
  { slug: "football", name: "Football", font_awesome_class: "fa-solid fa-football" }
]
sports.each { |attrs| Sport.find_or_initialize_by(slug: attrs[:slug]).update!(attrs.except(:slug)) }

soccer = Sport.find_by!(slug: "soccer")
football = Sport.find_by!(slug: "football")

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
    slug: "carabao-cup",
    name: "Carabao Cup",
    sport: soccer,
    active: true,
    video_naming_convention: "Home vs. Away: Extended Highlights | Carabao Cup | CBS Sports Golazo"
  },
  {
    slug: "college-football",
    name: "College Football",
    sport: football,
    active: true,
    video_naming_convention: "Away vs. Home | COLLEGE FOOTBALL HIGHLIGHTS | M/D/YY | NBC Sports " \
      "(also 'CFB ON FOX' and 'ESPN College Football', which vary the wording)"
  }
]

competitions.each do |attrs|
  Competition.find_or_initialize_by(slug: attrs[:slug]).update!(attrs.except(:slug))
end

# --- Competition crests -------------------------------------------------------
# Attach any league crest checked in under db/seeds/crests/<slug>.<ext>.
# Idempotent: skips a competition whose attached blob already matches the file.
Dir[Rails.root.join("db/seeds/crests/*")].each do |path|
  slug = File.basename(path, ".*")
  competition = Competition.find_by(slug: slug) or next

  checksum = OpenSSL::Digest::MD5.file(path).base64digest
  next if competition.photo.attached? && competition.photo.blob.checksum == checksum

  competition.photo.attach(
    io: File.open(path),
    filename: File.basename(path),
    content_type: Marcel::MimeType.for(Pathname.new(path))
  )
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
  },
  {
    youtube_channel_id: "UCpwix-O6ceqMgdxhqIynzFA",
    name: "CFB ON FOX",
    youtube_url: "https://www.youtube.com/@cfbonfox",
    uploads_playlist_id: "UUpwix-O6ceqMgdxhqIynzFA",
    active: true
  },
  {
    youtube_channel_id: "UCzRWWsFjqHk1an4OnVPsl9g",
    name: "ESPN College Football",
    youtube_url: "https://www.youtube.com/@espncfb",
    uploads_playlist_id: "UUzRWWsFjqHk1an4OnVPsl9g",
    active: true
  }
]

channels.each do |attrs|
  Channel.find_or_initialize_by(youtube_channel_id: attrs[:youtube_channel_id])
         .update!(attrs.except(:youtube_channel_id))
end

puts "Seeded: #{Sport.count} sports, #{Competition.count} competitions " \
     "(#{Competition.active.count} active), #{Channel.count} channels"
