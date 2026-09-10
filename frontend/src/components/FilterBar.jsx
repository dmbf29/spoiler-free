import { NavLink } from 'react-router-dom'

// `sports` is the payload from GET /api/v1/sports:
// [{ name, slug, competitions: [{ name, slug }] }]
export default function FilterBar({ sports, sportSlug }) {
  const activeSport = sports.find((s) => s.slug === sportSlug)

  return (
    <nav className="filters">
      <div className="filters__group">
        <NavLink to="/" end className={chipClass}>
          All sports
        </NavLink>
        {sports.map((sport) => (
          <NavLink key={sport.slug} to={`/${sport.slug}`} className={chipClass}>
            {sport.name}
          </NavLink>
        ))}
      </div>

      {activeSport && activeSport.competitions.length > 0 && (
        <>
          <span className="filters__divider" />
          <div className="filters__group">
            {activeSport.competitions.map((competition) => (
              <NavLink
                key={competition.slug}
                to={`/${activeSport.slug}/${competition.slug}`}
                className={chipClass}
              >
                {competition.name}
              </NavLink>
            ))}
          </div>
        </>
      )}
    </nav>
  )
}

function chipClass({ isActive }) {
  return isActive ? 'chip chip--active' : 'chip'
}
