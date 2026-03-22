const CACHE_NAME = "foliomed-v1";

// Pages and assets to pre-cache
const PRECACHE_URLS = [
  "/login",
  "/dashboard",
  "/patients",
];

// Install: pre-cache app shell
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS);
    })
  );
  self.skipWaiting();
});

// Activate: clean up old caches
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(
        names
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      )
    )
  );
  self.clients.claim();
});

// Fetch: Network-first for HTML, Cache-first for static assets
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== "GET") return;

  // Skip API routes, Supabase calls, and auth
  if (
    url.pathname.startsWith("/api/") ||
    url.hostname.includes("supabase") ||
    url.hostname.includes("google") ||
    url.hostname.includes("apple")
  ) {
    return;
  }

  // Static assets (JS, CSS, images, fonts): Cache-first
  if (
    url.pathname.startsWith("/_next/static/") ||
    url.pathname.startsWith("/icons/") ||
    url.pathname.match(/\.(js|css|woff2?|ttf|png|jpg|svg|webp|ico)$/)
  ) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        });
      })
    );
    return;
  }

  // HTML pages: Network-first with cache fallback
  if (request.headers.get("accept")?.includes("text/html")) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => {
          return caches.match(request).then((cached) => {
            if (cached) return cached;
            // Return a basic offline page
            return new Response(
              `<!DOCTYPE html>
              <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
              <title>FolioMed — Offline</title>
              <style>
                body { font-family: system-ui; background: #020617; color: #94a3b8;
                       display: flex; align-items: center; justify-content: center;
                       min-height: 100vh; margin: 0; text-align: center; }
                h1 { color: #e2e8f0; font-size: 1.5rem; }
                p { margin-top: 0.5rem; font-size: 0.875rem; }
                .icon { font-size: 3rem; margin-bottom: 1rem; }
              </style></head>
              <body><div>
                <div class="icon">📴</div>
                <h1>You're Offline</h1>
                <p>Check your connection and try again.<br>Cached data is available on previously visited pages.</p>
              </div></body></html>`,
              { headers: { "Content-Type": "text/html" } }
            );
          });
        })
    );
    return;
  }
});
