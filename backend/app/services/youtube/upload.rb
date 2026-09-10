module Youtube
  # Value object over a merged playlistItem + video resource from the API.
  # Normalizes the handful of fields the rest of the app cares about.
  class Upload
    attr_reader :raw

    def initialize(video_resource)
      @raw = video_resource
    end

    def youtube_video_id
      raw["id"]
    end

    def title
      raw.dig("snippet", "title").to_s
    end

    def description
      raw.dig("snippet", "description").to_s
    end

    def published_at
      value = raw.dig("snippet", "publishedAt")
      Time.zone.parse(value) if value.present?
    end

    # ISO 8601 duration ("PT8M32S") -> seconds.
    def duration_seconds
      iso = raw.dig("contentDetails", "duration")
      return if iso.blank?

      ActiveSupport::Duration.parse(iso).to_i
    rescue ArgumentError
      nil
    end

    def region_restricted?
      raw.dig("contentDetails", "regionRestriction").present?
    end

    def embeddable?
      # Absent means embeddable by default.
      raw.dig("status", "embeddable") != false
    end
  end
end
