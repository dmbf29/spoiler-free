# Groups uploads of the same game from different channels into one card.
#
# We don't model teams yet (V3), so this is a heuristic rather than an identity
# match: same competition + published close together + both sides of the
# matchup fuzzy-match on word tokens. Titles differ across channels
# ("Texas Tech Red Raiders" vs "Texas Tech Raiders"), hence the overlap
# threshold instead of equality. Rows stay separate in the database; this only
# decides presentation.
class VideoGrouper
  WINDOW = 36.hours
  MIN_SIDE_OVERLAP = 0.6
  SEPARATOR = " vs ".freeze

  # videos: any order. Returns an array of groups (arrays of videos), each group
  # led by its newest video, groups ordered newest first.
  def self.call(videos)
    new.call(videos)
  end

  def call(videos)
    groups = []

    videos.sort_by { |v| -v.published_at.to_f }.each do |video|
      group = groups.find { |candidate| same_game?(candidate, video) }
      group ? group << video : groups << [video]
    end

    groups
  end

  private

  def same_game?(group, video)
    lead = group.first

    lead.competition_id == video.competition_id &&
      (lead.published_at - video.published_at).abs <= WINDOW &&
      group.none? { |member| member.channel_id == video.channel_id } &&
      same_matchup?(lead.safe_title, video.safe_title)
  end

  def same_matchup?(a, b)
    sides_a = sides(a)
    sides_b = sides(b)
    return false if sides_a.nil? || sides_b.nil?

    aligned?(sides_a, sides_b) || aligned?(sides_a, sides_b.reverse)
  end

  def aligned?(sides_a, sides_b)
    sides_a.zip(sides_b).all? { |x, y| overlap(x, y) >= MIN_SIDE_OVERLAP }
  end

  def sides(title)
    parts = title.to_s.split(SEPARATOR, 2)
    return unless parts.size == 2

    tokens = parts.map { |part| part.downcase.scan(/[[:alnum:]]+/).to_set }
    tokens if tokens.none?(&:empty?)
  end

  # Jaccard similarity of word sets.
  def overlap(x, y)
    (x & y).size.to_f / (x | y).size
  end
end
