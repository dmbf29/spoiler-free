// Prev/next stepper over the weeks the API says have games.
export default function WeekPicker({ week, weeks, onChange }) {
  const index = weeks.indexOf(week)
  const prev = index > 0 ? weeks[index - 1] : null
  const next = index >= 0 && index < weeks.length - 1 ? weeks[index + 1] : null

  return (
    <div className="week-picker">
      <button
        className="btn btn--ghost"
        onClick={() => onChange(prev)}
        disabled={prev == null}
        aria-label="Previous week"
      >
        <i className="fa-solid fa-chevron-left" aria-hidden="true" />
      </button>
      <label className="week-picker__select">
        <span className="sr-only">Week</span>
        <select value={week ?? ''} onChange={(event) => onChange(Number(event.target.value))}>
          {weeks.map((w) => (
            <option key={w} value={w}>
              Week {w}
            </option>
          ))}
        </select>
      </label>
      <button
        className="btn btn--ghost"
        onClick={() => onChange(next)}
        disabled={next == null}
        aria-label="Next week"
      >
        <i className="fa-solid fa-chevron-right" aria-hidden="true" />
      </button>
    </div>
  )
}
