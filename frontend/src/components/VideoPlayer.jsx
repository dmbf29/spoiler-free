// Renders the YouTube IFrame embed. Only mounted after the user opts in, so no
// YouTube network requests (or thumbnails) happen before playback. Unmounting
// this component (via onClose) removes the iframe and stops playback.
export default function VideoPlayer({ youtubeVideoId, title, onClose }) {
  const src = `https://www.youtube-nocookie.com/embed/${youtubeVideoId}?autoplay=1&rel=0&modestbranding=1`

  return (
    <div className="card__player">
      <iframe
        src={src}
        title={title || 'Highlight video'}
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowFullScreen
      />
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
