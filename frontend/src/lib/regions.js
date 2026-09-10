// Turns the API's `region_restriction` ({ mode, regions } | null) into a compact
// UI hint: a Font Awesome icon class, a short label, and a full-text tooltip.
//
// We don't render country flags: flag emoji don't render on Windows, and the
// real-world "allowed" lists here are just the US plus its territories.

// US + territories + freely-associated states. An "allowed" list made up only of
// these reads, in practice, as "US only".
const US_FAMILY = new Set(['US', 'AS', 'GU', 'MP', 'PR', 'UM', 'VI', 'FM', 'MH', 'PW'])

const REGION_NAMES = {
  US: 'United States',
  GB: 'United Kingdom',
  CA: 'Canada',
  AU: 'Australia',
  IE: 'Ireland',
  NZ: 'New Zealand',
}

function nameFor(code) {
  return REGION_NAMES[code] || code
}

export function describeRegions(regionRestriction) {
  const regions = regionRestriction?.regions ?? []
  if (!regions.length) {
    return {
      icon: 'fa-globe',
      label: 'Plays anywhere',
      title: 'No region restrictions',
      restricted: false,
    }
  }

  const codes = regions.join(', ')

  if (regionRestriction.mode === 'blocked') {
    return {
      icon: 'fa-ban',
      label: 'Some regions blocked',
      title: `Blocked in: ${codes}`,
      restricted: true,
    }
  }

  // mode === 'allowed'
  let label
  if (regions.includes('US') && regions.every((code) => US_FAMILY.has(code))) {
    label = 'US only'
  } else if (regions.length === 1) {
    label = `${nameFor(regions[0])} only`
  } else {
    label = `${regions.length} regions only`
  }

  return {
    icon: 'fa-location-dot',
    label,
    title: `Plays only in: ${codes}`,
    restricted: true,
  }
}
