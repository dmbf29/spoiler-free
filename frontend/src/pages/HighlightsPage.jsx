import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { api } from '../api/client.js'
import FilterBar from '../components/FilterBar.jsx'
import VideoCard from '../components/VideoCard.jsx'

export default function HighlightsPage() {
  const { sportSlug, competitionSlug } = useParams()

  const [sports, setSports] = useState([])
  const [videos, setVideos] = useState([])
  const [status, setStatus] = useState('loading') // loading | ready | error

  // Filter options (load once).
  useEffect(() => {
    api.listSports().then(setSports).catch(() => setSports([]))
  }, [])

  // Highlights (reload when the URL filter changes).
  useEffect(() => {
    let cancelled = false
    setStatus('loading')

    api
      .listVideos({ sport: sportSlug, competition: competitionSlug })
      .then((data) => {
        if (cancelled) return
        setVideos(data)
        setStatus('ready')
      })
      .catch(() => {
        if (!cancelled) setStatus('error')
      })

    return () => {
      cancelled = true
    }
  }, [sportSlug, competitionSlug])

  return (
    <>
      <FilterBar sports={sports} sportSlug={sportSlug} />

      {status === 'loading' && <p className="state">Loading highlights…</p>}
      {status === 'error' && (
        <p className="state state--error">
          Couldn’t reach the highlights API. Is the Rails server running on :3000?
        </p>
      )}
      {status === 'ready' && videos.length === 0 && (
        <p className="state">No highlights available yet.</p>
      )}

      {status === 'ready' && videos.length > 0 && (
        <div className="video-list">
          {videos.map((video) => (
            <VideoCard key={video.id} video={video} />
          ))}
        </div>
      )}
    </>
  )
}
