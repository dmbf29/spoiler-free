import { Navigate, Route, Routes } from 'react-router-dom'
import HighlightsPage from './pages/HighlightsPage.jsx'
import './App.css'

export default function App() {
  return (
    <div className="app">
      <header className="app__header">
        <h1 className="app__title">Spoiler Free Highlights</h1>
        <p className="app__tagline">
          Game highlights with no scores, no winners, no spoilers.
        </p>
      </header>

      <Routes>
        {/* URLs are bookmarkable: /, /:sportSlug, /:sportSlug/:competitionSlug */}
        <Route path="/" element={<HighlightsPage />} />
        <Route path="/:sportSlug" element={<HighlightsPage />} />
        <Route path="/:sportSlug/:competitionSlug" element={<HighlightsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </div>
  )
}
