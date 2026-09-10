import { useState } from 'react'
import { formatDate, formatDuration } from '../lib/format.js'
import { describeRegions } from '../lib/regions.js'
import SportLabel from './SportLabel.jsx'
import VideoPlayer from './VideoPlayer.jsx'

export default function VideoCard({ video }) {
  const [playing, setPlaying] = useState(false)

  const duration = formatDuration(video.duration_seconds)
  const date = formatDate(video.published_at)
  const logo = video.competition?.photo_url
  const region = describeRegions(video.region_restriction)

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
        {video.sport && (
          <span>
            <SportLabel sport={video.sport} />
            {video.competition?.name && ` – ${video.competition.name}`}
          </span>
        )}
        {date && (
          <span>
            <i className="meta-icon fa-solid fa-calendar" aria-hidden="true" />
            {date}
          </span>
        )}
        {duration && (
          <span>
            <i className="meta-icon fa-solid fa-stopwatch" aria-hidden="true" />
            {duration}
          </span>
        )}
      </div>

      {playing ? (
        <>
          <VideoPlayer
            youtubeVideoId={video.youtube_video_id}
            title={video.safe_title}
            onClose={() => setPlaying(false)}
          />
          {video.region_restricted && (
            <p className="card__note">
              This video may only play from certain countries (US region required).
            </p>
          )}
        </>
      ) : (
        <div className="card__actions">
          <button
            className="btn"
            onClick={() => setPlaying(true)}
            disabled={video.embeddable === false}
          >
            {video.embeddable === false ? 'Playback unavailable' : 'Watch Highlights'}
          </button>
          <span
            className={`card__region${region.restricted ? ' card__region--limited' : ''}`}
            title={region.title}
          >
            <i className={`fa-solid ${region.icon}`} aria-hidden="true" />
            {region.label}
          </span>
        </div>
      )}
    </article>
  )
}
