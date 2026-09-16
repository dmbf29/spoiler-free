// Sport name preceded by its Font Awesome icon (icon class comes from the API:
// sport.icon, e.g. "fa-solid fa-futbol"). Falls back to just the name.
export default function SportLabel({ sport }) {
  if (!sport) return null

  return (
    <>
      {sport.icon && <i className={`sport-icon ${sport.icon}`} aria-hidden="true" />}
      {name && sport.name }
    </>
  )
}
