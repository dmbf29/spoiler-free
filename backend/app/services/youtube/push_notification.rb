module Youtube
  # Parses the Atom payload the hub POSTs when a video is published/updated:
  #
  #   <feed xmlns:yt="..."><entry><yt:videoId>ID</yt:videoId>
  #     <yt:channelId>UC...</yt:channelId>...</entry></feed>
  #
  # Deletion notices (<at:deleted-entry>) have no <entry>, so they yield nothing.
  class PushNotification
    Entry = Struct.new(:video_id, :channel_id, keyword_init: true)

    def self.parse(xml)
      new(xml).entries
    end

    def initialize(xml)
      @xml = xml
    end

    def entries
      doc = Nokogiri::XML(@xml.to_s) { |config| config.strict.nonet }
      doc.xpath("//*[local-name()='entry']").filter_map do |node|
        video_id = text_of(node, "videoId")
        channel_id = text_of(node, "channelId")
        Entry.new(video_id: video_id, channel_id: channel_id) if video_id && channel_id
      end
    rescue Nokogiri::XML::SyntaxError
      []
    end

    private

    def text_of(node, name)
      node.at_xpath("*[local-name()='#{name}']")&.text.presence
    end
  end
end
