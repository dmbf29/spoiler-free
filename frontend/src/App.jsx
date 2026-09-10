import { Navigate, Route, Routes } from 'react-router-dom'
import HighlightsPage from './pages/HighlightsPage.jsx'
import './App.css'

export default function App() {
  return (
    <div className="app">
      <header className="app__header">
        <h1 className="app__title">Spoiler Free Highlights</h1>
        <p className="app__tagline">
          No scores, no spoilers, just action.
        </p>
        <a
          className="bmc-link"
          href="https://buymeacoffee.com/dougberks"
          target="_blank"
          rel="noopener noreferrer"
        >
          <img src="/buymeacoffee-logo.png" alt="" className="bmc-link__logo" />
          Buy me a coffee
        </a>
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
