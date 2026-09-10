module Classification
  # Splits "Team A v. Team B" (and common variants) into two team names.
  module MatchupParser
    SEPARATORS = [" v. ", " vs. ", " vs ", " v ", " V ", " @ "].freeze

    # Emoji (Symbol, other) plus an optional variation selector, e.g. "🏈", "🔥".
    EMOJI = /\p{So}\u{FE0F}?/

    module_function

    # Returns [home, away] or nil. NBC lists soccer as "Home v. Away" and college
    # football as "Away vs. Home"; callers decide what the two slots mean and we
    # just preserve left/right order.
    def split(text)
      segment = text.to_s.split("|").first.to_s.strip

      # FOX ("CFB ON FOX") has no pipes: the matchup is followed by
      # "Highlights 🏈 FOX College Football" (the "Highlights" word is sometimes
      # absent). Drop the channel suffix so the trailing-"Highlights" strip below
      # can finish the job.
      segment = segment.sub(/\s*#{EMOJI}*\s*fox college football\s*\z/i, "").strip

      # CBS Golazo appends the format to the matchup itself, before the first
      # pipe: "Liverpool vs. Atlético Madrid: Extended Highlights".
      segment = segment.sub(/:?\s*(?:extended |match |game )?highlights\s*\z/i, "").strip

      # ESPN can lead with a hype phrase before the matchup, always set off by an
      # emoji: "Mason Heintschel 7 TDs 🔥 Miami (OH) RedHawks vs. Pittsburgh...".
      segment = segment.sub(/\A.*#{EMOJI}\s+/, "").strip

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
          .sub(/\A(?:#|no\.?\s*)\d{1,2}\s+/i, "") # AP-ranking prefix: "No. 12 ", "#3 "
          .squeeze(" ")
    end
  end
end
