import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api/client.js'
import FilterBar from '../components/FilterBar.jsx'
import GameRow from '../components/GameRow.jsx'
import SourceChannels from '../components/SourceChannels.jsx'
import WeekPicker from '../components/WeekPicker.jsx'
import { formatDay } from '../lib/format.js'

// Weekly schedule for one competition. The week lives in the URL (?week=9) so
// it's bookmarkable; with no param the API returns the current week.
export default function SchedulePage({ competition }) {
  const [searchParams, setSearchParams] = useSearchParams()
  const week = searchParams.get('week')

  const [sports, setSports] = useState([])
  const [schedule, setSchedule] = useState(null)
  const [status, setStatus] = useState('loading') // loading | ready | error
  const [onlyHighlights, setOnlyHighlights] = useState(false)

  useEffect(() => {
    api.listSports().then(setSports).catch(() => setSports([]))
  }, [])

  useEffect(() => {
    let cancelled = false
    setStatus('loading')

    api
      .listGames({ competition, week })
      .then((data) => {
        if (cancelled) return
        setSchedule(data)
        setStatus('ready')
      })
      .catch(() => {
        if (!cancelled) setStatus('error')
      })

    return () => {
      cancelled = true
    }
  }, [competition, week])

  const games = useMemo(() => {
    const all = schedule?.games ?? []
    return onlyHighlights ? all.filter((game) => game.highlights.length > 0) : all
  }, [schedule, onlyHighlights])

  const days = useMemo(() => groupByDay(games), [games])
  const sourceItems = useMemo(
    () => games.map((game) => ({ sources: game.highlights })),
    [games],
  )

  return (
    <>
      <FilterBar sports={sports} sportSlug="football" />

      {status === 'loading' && !schedule && <p className="state">Loading schedule…</p>}
      {status === 'error' && (
        <p className="state state--error">Couldn’t reach the schedule API.</p>
      )}

      {schedule && schedule.week != null && (
        <div className="schedule__controls">
          <WeekPicker
            week={schedule.week}
            weeks={schedule.weeks}
            onChange={(next) => next != null && setSearchParams({ week: next })}
          />
          <label className="toggle">
            <input
              type="checkbox"
              checked={onlyHighlights}
              onChange={(event) => setOnlyHighlights(event.target.checked)}
            />
            Highlights ready
          </label>
        </div>
      )}

      {schedule && status === 'ready' && <SourceChannels videos={sourceItems} />}

      {status === 'ready' && schedule?.week == null && (
        <p className="state">No schedule has been loaded yet.</p>
      )}
      {status === 'ready' && schedule?.week != null && games.length === 0 && (
        <p className="state">
          {onlyHighlights ? 'No highlights are ready for this week yet.' : 'No games this week.'}
        </p>
      )}

      <div className={status === 'loading' ? 'schedule schedule--loading' : 'schedule'}>
        {days.map(({ key, label, games: dayGames }) => (
          <section key={key} className="schedule__day">
            <h2 className="schedule__heading">{label}</h2>
            <div className="game-list">
              {dayGames.map((game) => (
                <GameRow key={game.id} game={game} />
              ))}
            </div>
          </section>
        ))}
      </div>
    </>
  )
}

// Games arrive in kickoff order; group consecutive ones by the viewer's local day.
function groupByDay(games) {
  const days = []
  for (const game of games) {
    const label = formatDay(game.kickoff_at)
    const last = days[days.length - 1]
    if (last && last.key === label) last.games.push(game)
    else days.push({ key: label, label, games: [game] })
  }
  return days
}
