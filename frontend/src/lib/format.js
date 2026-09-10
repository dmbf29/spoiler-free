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
