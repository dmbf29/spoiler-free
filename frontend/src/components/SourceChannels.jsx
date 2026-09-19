// A quiet link strip to the official YouTube channels the currently-shown
// videos came from — makes clear these are their own uploads, not rehosted
// streams. Derived from the videos on screen rather than every synced
// channel, so it only ever names channels actually represented below.
export default function SourceChannels({ videos }) {
  const channels = uniqueChannels(videos)
  if (channels.length === 0) return null

  return (
    <div className="sources">
      <span className="sources__label">Highlights sourced from the official channels:</span>
      <div className="sources__links">
        {channels.map((channel) => (
          <a
            key={channel.name}
            className="source-link"
            href={channel.youtube_url}
            target="_blank"
            rel="noopener noreferrer"
          >
            <i className="fa-brands fa-youtube" aria-hidden="true" />
            {channel.name}
          </a>
        ))}
      </div>
    </div>
  )
}

function uniqueChannels(videos) {
  const byName = new Map()
  for (const video of videos) {
    for (const { channel } of video.sources) {
      if (channel?.name && !byName.has(channel.name)) byName.set(channel.name, channel)
    }
  }
  return [...byName.values()].sort((a, b) => a.name.localeCompare(b.name))
}
