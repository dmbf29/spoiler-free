import { useState } from 'react'
import { formatDate, formatDuration } from '../lib/format.js'
import { describeRegions } from '../lib/regions.js'
import VideoPlayer from './VideoPlayer.jsx'
import SportLabel from './SportLabel.jsx'

// One game. `video.sources` holds each channel's upload of it (usually one,
// occasionally several) — the viewer picks which one to watch.
export default function VideoCard({ video }) {
  const [playingId, setPlayingId] = useState(null)

  const date = formatDate(video.published_at)
  const logo = video.competition?.photo_url
  const multiple = video.sources.length > 1
  const playing = video.sources.find((source) => source.id === playingId)

  return (
    <article className="card">
      <div className="card__heading">
        {logo && (
          <span className="card__logo">
            <img src={logo} alt={video.competition?.name || ''} />
          </span>
        )}
        <h2 className="card__title">{video.safe_title}</h2>
      </div>

      <div className="card__meta">
        {video.competition?.name && (
          <span>
            <SportLabel sport={video.sport} name={false} />
            {video.competition.name}
          </span>
        )}
        {!multiple && <SourceMeta source={video.sources[0]} />}
        <div className="timing">
          {date && (
            <span>
              <i className="meta-icon fa-solid fa-calendar" aria-hidden="true" />
              {date}
            </span>
          )}
          {!multiple && <Duration source={video.sources[0]} />}
        </div>
      </div>

      {playing ? (
        <>
          <VideoPlayer
            youtubeVideoId={playing.youtube_video_id}
            title={video.safe_title}
            onClose={() => setPlayingId(null)}
          />
          {playing.region_restricted && (
            <p className="card__note">
              This video may only play from certain countries (US region required).
            </p>
          )}
        </>
      ) : (
        video.sources.map((source) => (
          <SourceActions
            key={source.id}
            source={source}
            multiple={multiple}
            onPlay={() => setPlayingId(source.id)}
          />
        ))
      )}
    </article>
  )
}

function SourceMeta({ source }) {
  if (!source.channel?.name) return null

  return (
    <span>
      <i className="meta-icon fa-brands fa-youtube" aria-hidden="true" />
      {source.channel.name}
    </span>
  )
}

function Duration({ source }) {
  const duration = formatDuration(source.duration_seconds)
  if (!duration) return null

  return (
    <span>
      <i className="meta-icon fa-solid fa-stopwatch" aria-hidden="true" />
      {duration}
    </span>
  )
}

function SourceActions({ source, multiple, onPlay }) {
  const region = describeRegions(source.region_restriction)
  const unavailable = source.embeddable === false
  const label = unavailable
    ? 'Playback unavailable'
    : multiple && source.channel?.name
      ? `Watch via ${source.channel.name}`
      : 'Watch Highlights'

  return (
    <div className="card__actions">
      <button className="btn" onClick={onPlay} disabled={unavailable}>
        {label}
      </button>
      {multiple && <Duration source={source} />}
      <span
        className={`card__region${region.restricted ? ' card__region--limited' : ''}`}
        title={region.title}
      >
        <i className={`fa-solid ${region.icon}`} aria-hidden="true" />
        {region.label}
      </span>
    </div>
  )
}
