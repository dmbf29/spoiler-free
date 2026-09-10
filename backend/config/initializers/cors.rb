# Allow the React dev server (Vite) to call this API from the browser.
# In production, set FRONTEND_ORIGIN to the deployed frontend URL.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5180"),
      "http://127.0.0.1:5180"
    )

    resource "/api/*",
      headers: :any,
      methods: %i[get post patch put delete options head],
      credentials: false
  end
end
