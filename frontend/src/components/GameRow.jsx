import { useState } from 'react'
import { formatKickoffTime } from '../lib/format.js'
import { SourceActions } from './VideoCard.jsx'
import VideoPlayer from './VideoPlayer.jsx'

// One scheduled game: matchup, kickoff and TV, and — once a channel has
// uploaded highlights — a way to watch them. Never shows a score or result;
// the only state surfaced is whether highlights exist yet.
export default function GameRow({ game }) {
  const [playingId, setPlayingId] = useState(null)

  const sources = game.highlights
  const multiple = sources.length > 1
  const playing = sources.find((source) => source.id === playingId)
  const title = `${game.away_team.short_name} at ${game.home_team.short_name}`

  return (
    <article className="game">
      <div className="game__main">
        <div className="game__teams">
          <Team team={game.away_team} />
          <span className="game__at">{game.neutral_site ? 'vs' : '@'}</span>
          <Team team={game.home_team} />
        </div>
        <div className="game__info">
          <span className="game__time">{formatKickoffTime(game.kickoff_at)}</span>
          {game.tv && <span className="game__tv">{game.tv}</span>}
        </div>
      </div>

      {playing ? (
        <>
          <VideoPlayer
            youtubeVideoId={playing.youtube_video_id}
            title={title}
            onClose={() => setPlayingId(null)}
          />
          {playing.region_restricted && (
            <p className="card__note">
              This video may only play from certain countries (US region required).
            </p>
          )}
        </>
      ) : sources.length > 0 ? (
        sources.map((source) => (
          <SourceActions
            key={source.id}
            source={source}
            multiple={multiple}
            onPlay={() => setPlayingId(source.id)}
          />
        ))
      ) : (
        <p className="game__status">{statusLabel(game.status)}</p>
      )}
    </article>
  )
}

function statusLabel(status) {
  switch (status) {
    case 'postponed':
      return 'Postponed'
    case 'canceled':
      return 'Canceled'
    case 'in_progress':
      return 'In progress'
    case 'final':
      return 'Awaiting highlights'
    default:
      return 'Upcoming'
  }
}

function Team({ team }) {
  return (
    <span className="team">
      {team.logo_url && (
        <span className="team__logo">
          <img src={team.logo_url} alt="" loading="lazy" />
        </span>
      )}
      {team.rank && <span className="team__rank">{team.rank}</span>}
      <span className="team__name">{team.short_name}</span>
    </span>
  )
}
