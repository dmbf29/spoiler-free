import { useCallback, useEffect, useState } from 'react'

// Games the viewer has marked to watch, kept only in this browser.
// Stored as { [gameId]: kickoffIso } so entries for long-finished games can be
// pruned without asking the API about them.
const STORAGE_KEY = 'spoilerFree.watchlist.v1'
const MAX_AGE_MS = 60 * 24 * 60 * 60 * 1000 // drop games that kicked off 60+ days ago

function read() {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}')
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {}
    const cutoff = Date.now() - MAX_AGE_MS
    return Object.fromEntries(
      Object.entries(parsed).filter(([, kickoff]) => !(Date.parse(kickoff) < cutoff)),
    )
  } catch {
    return {}
  }
}

function write(entries) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(entries))
  } catch {
    // Storage blocked or full (e.g. private mode): the watchlist just won't persist.
  }
}

export default function useWatchlist() {
  const [entries, setEntries] = useState(read)

  // Keep other open tabs in sync.
  useEffect(() => {
    const onStorage = (event) => {
      if (event.key === STORAGE_KEY) setEntries(read())
    }
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  const isWatched = useCallback((game) => String(game.id) in entries, [entries])

  const toggle = useCallback((game) => {
    setEntries((current) => {
      const key = String(game.id)
      const next = { ...current }
      if (key in next) delete next[key]
      else next[key] = game.kickoff_at
      write(next)
      return next
    })
  }, [])

  return { isWatched, toggle }
}
