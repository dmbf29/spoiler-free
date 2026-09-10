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
        { name: competition.name, slug: competition.slug }
      end
    }
  end
end
