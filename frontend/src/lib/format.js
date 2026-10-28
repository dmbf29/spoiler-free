export function formatDuration(seconds) {
  if (seconds == null) return null
  const total = Math.round(seconds)
  const mins = Math.floor(total / 60)
  const secs = total % 60
  if (mins < 60) return `${mins} min`
  const hours = Math.floor(mins / 60)
  return `${hours}h ${mins % 60}m`
}

// published_at comes from the API as a UTC ISO-8601 instant. Passing no timeZone
// option lets the browser render it in the viewer's local timezone.
export function formatDate(iso) {
  if (!iso) return null
  return new Date(iso).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

// Kickoff times are UTC instants; both helpers render in the viewer's timezone.
export function formatKickoffTime(iso) {
  return new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
}

// Local calendar day, e.g. "Saturday, October 31" — also used as the grouping key.
export function formatDay(iso) {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  })
}
