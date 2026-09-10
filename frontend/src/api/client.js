const BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1'

async function request(path, params) {
  const url = new URL(`${BASE_URL}${path}`, window.location.origin)
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value != null && value !== '') url.searchParams.set(key, value)
    })
  }

  const response = await fetch(url, { headers: { Accept: 'application/json' } })
  if (!response.ok) {
    throw new Error(`API ${response.status} for ${path}`)
  }
  return response.json()
}

export const api = {
  // GET /api/v1/videos?sport=&competition=
  listVideos: ({ sport, competition } = {}) =>
    request('/videos', { sport, competition }),

  // GET /api/v1/sports
  listSports: () => request('/sports'),
}
