import { useEffect, useRef, useState } from 'react'

// Renders the YouTube IFrame embed. Only mounted after the user opts in, so no
// YouTube network requests (or thumbnails) happen before playback. Unmounting
// this component (via onClose) removes the iframe and stops playback.
//
// YouTube's embedded player shows its own title/channel overlay on top of the
// video independent of any player parameter — `controls=0` doesn't stop it,
// and neither does blocking every mouse/keyboard event from reaching the
// iframe (confirmed by testing: it still appears even when the iframe can't
// receive input at all). It's autonomous, undocumented behavior of their
// player, not a reaction to anything happening on our page, so there's no
// event or parameter we can use to suppress it. The only thing that reliably
// works is permanently painting over the strip where it renders — pixels we
// control, regardless of what YouTube's script decides to do on its side.
//
// That cover only exists in OUR document, though — it's not part of the
// iframe. So `iframe.requestFullscreen()` (which is what YouTube's own
// fullscreen button calls) would fullscreen just the iframe, leaving the
// cover behind and exposing the title. We block that button entirely
// (`fs=0`, and dropping `allowFullScreen` so the iframe has no fullscreen
// permission to invoke even if a button reappeared) and instead fullscreen
// our OWN wrapping element — the one that has the iframe *and* the cover as
// children — so the cover rides along into real, OS-level fullscreen too.
//
// Mobile Safari doesn't implement the Fullscreen API for arbitrary elements
// at all (only a bare <video>, via a different, non-standard method) — no
// parameter or polyfill changes that. Where the real API isn't there, we
// fall back to a CSS-only "fake fullscreen" that fixes the player over the
// whole viewport instead. It can't hide Safari's own address bar (nothing
// short of the real API can), but the video (and the cover) still expand to
// fill the screen.
export default function VideoPlayer({ youtubeVideoId, title, onClose }) {
  const containerRef = useRef(null)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [isFakeFullscreen, setIsFakeFullscreen] = useState(false)

  useEffect(() => {
    function handleFullscreenChange() {
      const fsElement = document.fullscreenElement || document.webkitFullscreenElement
      setIsFullscreen(fsElement === containerRef.current)
    }

    document.addEventListener('fullscreenchange', handleFullscreenChange)
    document.addEventListener('webkitfullscreenchange', handleFullscreenChange)
    return () => {
      document.removeEventListener('fullscreenchange', handleFullscreenChange)
      document.removeEventListener('webkitfullscreenchange', handleFullscreenChange)
    }
  }, [])

  // Fake fullscreen has no browser-native Escape handling, so wire it up
  // ourselves, and stop the page scrolling underneath while it's open.
  useEffect(() => {
    if (!isFakeFullscreen) return

    function handleKeyDown(event) {
      if (event.key === 'Escape') setIsFakeFullscreen(false)
    }

    document.addEventListener('keydown', handleKeyDown)
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.body.style.overflow = previousOverflow
    }
  }, [isFakeFullscreen])

  function toggleFullscreen() {
    const el = containerRef.current
    const requestNativeFullscreen = el.requestFullscreen || el.webkitRequestFullscreen

    if (!requestNativeFullscreen) {
      setIsFakeFullscreen((current) => !current)
      return
    }

    const fsElement = document.fullscreenElement || document.webkitFullscreenElement
    if (fsElement) {
      ;(document.exitFullscreen || document.webkitExitFullscreen)?.call(document)
    } else {
      requestNativeFullscreen.call(el)
    }
  }

  const src = `https://www.youtube-nocookie.com/embed/${youtubeVideoId}?autoplay=1&rel=0&modestbranding=1&fs=0`
  const expanded = isFullscreen || isFakeFullscreen

  return (
    <div
      className={`card__player${isFakeFullscreen ? ' card__player--fake-fullscreen' : ''}`}
      ref={containerRef}
    >
      <iframe
        src={src}
        title={title || 'Highlight video'}
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      />

      {/* Permanently covers the title/channel row YouTube draws at the top of
          its own player — see the comment above. `pointer-events: none` so it
          never blocks the real controls (play/pause/seek/volume, keyboard
          shortcuts) underneath. */}
      <div className="card__player-titleguard" aria-hidden="true" />

      <button
        type="button"
        className="card__player-fullscreen"
        onClick={toggleFullscreen}
        aria-label={expanded ? 'Exit fullscreen' : 'Fullscreen'}
      >
        <i className={`fa-solid ${expanded ? 'fa-compress' : 'fa-expand'}`} aria-hidden="true" />
      </button>

      {onClose && (
        <button
          type="button"
          className="card__player-close"
          onClick={onClose}
          aria-label="Close video"
        >
          &times;
        </button>
      )}
    </div>
  )
}
