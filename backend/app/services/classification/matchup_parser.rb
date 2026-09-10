module Classification
  # Splits "Team A v. Team B" (and common variants) into two team names.
  module MatchupParser
    SEPARATORS = [" v. ", " vs. ", " vs ", " v ", " V ", " @ "].freeze

    module_function

    # Returns [home, away] or nil. NBC lists soccer as "Home v. Away" and college
    # football as "Away vs. Home"; callers decide what the two slots mean and we
    # just preserve left/right order.
    def split(text)
      segment = text.to_s.split("|").first.to_s.strip
      # CBS Golazo appends the format to the matchup itself, before the first
      # pipe: "Liverpool vs. Atlético Madrid: Extended Highlights".
      segment = segment.sub(/:?\s*(?:extended |match |game )?highlights\s*\z/i, "").strip
      return if segment.empty?

      SEPARATORS.each do |sep|
        next unless segment.include?(sep)

        left, right = segment.split(sep, 2).map { |part| clean(part) }
        return [left, right] if left.present? && right.present?
      end

      nil
    end

    def clean(part)
      part.to_s
          .gsub(/\((?:en español|en espanol|full match|full)\)/i, "") # NBC language/format tags
          .strip
          .sub(/\A[-–—]\s*/, "")
          .squeeze(" ")
    end
  end
end
