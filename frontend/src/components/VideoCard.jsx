import { useState } from 'react'
import { formatDate, formatDuration } from '../lib/format.js'
import VideoPlayer from './VideoPlayer.jsx'

export default function VideoCard({ video }) {
  const [playing, setPlaying] = useState(false)

  const duration = formatDuration(video.duration_seconds)
  const date = formatDate(video.published_at)

  return (
    <article className="card">
      <h2 className="card__title">{video.safe_title}</h2>

      <div className="card__meta">
        {video.sport && <span>{video.sport.name}</span>}
        {date && <span>{date}</span>}
        {duration && <span>{duration}</span>}
      </div>

      {playing ? (
        <>
          <VideoPlayer youtubeVideoId={video.youtube_video_id} title={video.safe_title} />
          {video.region_restricted && (
            <p className="card__note">
              This video may only play from certain countries (US region required).
            </p>
          )}
        </>
      ) : (
        <button
          className="btn"
          onClick={() => setPlaying(true)}
          disabled={video.embeddable === false}
        >
          {video.embeddable === false ? 'Playback unavailable' : 'Watch Highlights'}
        </button>
      )}
    </article>
  )
}
