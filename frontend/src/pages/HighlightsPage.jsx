import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { api } from '../api/client.js'
import FilterBar from '../components/FilterBar.jsx'
import SourceChannels from '../components/SourceChannels.jsx'
import VideoCard from '../components/VideoCard.jsx'

const WINDOW_DAYS = 7
const DAY_MS = 24 * 60 * 60 * 1000

function daysAgoIso(days) {
  return new Date(Date.now() - days * DAY_MS).toISOString()
}

export default function HighlightsPage() {
  const { sportSlug, competitionSlug } = useParams()

  const [sports, setSports] = useState([])
  const [videos, setVideos] = useState([])
  const [status, setStatus] = useState('loading') // loading | ready | error
  const [oldestDaysBack, setOldestDaysBack] = useState(WINDOW_DAYS)
  const [loadingMore, setLoadingMore] = useState(false)

  // Filter options (load once).
  useEffect(() => {
    api.listSports().then(setSports).catch(() => setSports([]))
  }, [])

  // Highlights (reload the initial 7-day window when the URL filter changes).
  useEffect(() => {
    let cancelled = false
    setStatus('loading')

    api
      .listVideos({ sport: sportSlug, competition: competitionSlug, since: daysAgoIso(WINDOW_DAYS) })
      .then((data) => {
        if (cancelled) return
        setVideos(data)
        setOldestDaysBack(WINDOW_DAYS)
        setStatus('ready')
      })
      .catch(() => {
        if (!cancelled) setStatus('error')
      })

    return () => {
      cancelled = true
    }
  }, [sportSlug, competitionSlug])

  function loadOlder() {
    const nextDaysBack = oldestDaysBack + WINDOW_DAYS
    setLoadingMore(true)

    api
      .listVideos({
        sport: sportSlug,
        competition: competitionSlug,
        since: daysAgoIso(nextDaysBack),
        before: daysAgoIso(oldestDaysBack),
      })
      .then((data) => {
        setVideos((prev) => [...prev, ...data])
        setOldestDaysBack(nextDaysBack)
      })
      .catch(() => {})
      .finally(() => setLoadingMore(false))
  }

  return (
    <>
      <FilterBar sports={sports} sportSlug={sportSlug} />

      {status === 'ready' && <SourceChannels videos={videos} />}

      {status === 'loading' && <p className="state">Loading highlights…</p>}
      {status === 'error' && (
        <p className="state state--error">
          Couldn’t reach the highlights API. Is the Rails server running on :3000?
        </p>
      )}
      {status === 'ready' && videos.length === 0 && (
        <p className="state">No highlights in the last {oldestDaysBack} days.</p>
      )}

      {status === 'ready' && videos.length > 0 && (
        <div className="video-list">
          {videos.map((video) => (
            <VideoCard key={video.id} video={video} />
          ))}
        </div>
      )}

      {status === 'ready' && (
        <p className="load-more">
          <button className="btn" onClick={loadOlder} disabled={loadingMore}>
            {loadingMore ? 'Loading…' : 'Load older highlights'}
          </button>
        </p>
      )}
    </>
  )
}
