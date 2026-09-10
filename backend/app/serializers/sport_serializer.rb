
class SportSerializer
  def self.list(sports)
    sports.map { |sport| new(sport).as_json }
  end

  def initialize(sport)
    @sport = sport
  end

  def as_json
    {
      name: @sport.name,
      slug: @sport.slug,
      icon: @sport.font_awesome_class,
      competitions: @sport.competitions.select(&:active?).map do |competition|
        {
          name: competition.name,
          slug: competition.slug,
          photo_url: competition_photo_url(competition)
        }
      end
    }
  end

  private

  def competition_photo_url(competition)
    return unless competition.photo.attached?

    competition.photo.url
  rescue StandardError
    nil
  end
end
