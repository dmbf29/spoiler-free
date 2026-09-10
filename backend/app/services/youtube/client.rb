module Youtube
  # Thin wrapper around the YouTube Data API v3. Fetching only — no
  # classification or persistence logic lives here.
  class Client
    class Error < StandardError; end
    class MissingApiKey < Error; end

    BASE_URL = "https://www.googleapis.com/youtube/v3".freeze
    MAX_IDS_PER_REQUEST = 50

    def initialize(api_key: ENV["YOUTUBE_API_KEY"])
      raise MissingApiKey, "YOUTUBE_API_KEY is not set" if api_key.blank?

      @api_key = api_key
    end

    # Resolve a channel's "uploads" playlist id.
    def uploads_playlist_id(channel_id)
      data = get("channels", part: "contentDetails", id: channel_id)
      item = data.fetch("items", []).first
      raise Error, "Channel not found: #{channel_id}" if item.nil?

      item.dig("contentDetails", "relatedPlaylists", "uploads")
    end

    # One page of a playlist's items, newest first. Returns
    # { items: [...], next_page_token: "..." | nil }.
    def playlist_items(playlist_id, page_token: nil, max_results: 50)
      data = get(
        "playlistItems",
        part: "snippet,contentDetails",
        playlistId: playlist_id,
        maxResults: max_results,
        pageToken: page_token
      )
      { items: data.fetch("items", []), next_page_token: data["nextPageToken"] }
    end

    # Full video resources for up to 50 ids per call (batched automatically).
    def videos(ids)
      Array(ids).each_slice(MAX_IDS_PER_REQUEST).flat_map do |batch|
        get(
          "videos",
          part: "snippet,contentDetails,status",
          id: batch.join(",")
        ).fetch("items", [])
      end
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.options.timeout = 15
        f.options.open_timeout = 5
        f.response :raise_error
      end
    end

    def get(path, params)
      response = connection.get(path, params.compact.merge(key: @api_key))
      JSON.parse(response.body)
    rescue Faraday::Error => e
      status = e.respond_to?(:response_status) ? e.response_status : nil
      raise Error, "YouTube API request to #{path} failed (#{status || e.class})"
    end
  end
end
