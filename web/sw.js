// Service Worker for Glimpse Media Viewer

const CACHE_NAME = "glimpse-media-viewer-v5.7";
const DYNAMIC_CACHE = "glimpse-media-dynamic-v5.7";

// Assets to cache on install
const STATIC_ASSETS = ["/", "/index.html", "/manifest.json", "/test.html"];

// Install event - cache static assets
self.addEventListener("install", (event) => {
  console.log("Service Worker: Installing");
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => {
        console.log("Service Worker: Caching static files");
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log("Service Worker: All static assets added to cache");
        return self.skipWaiting(); // Ensure the new service worker activates right away
      })
  );
});

// Activate event - clean up old caches
self.addEventListener("activate", (event) => {
  console.log("Service Worker: Activating");
  event.waitUntil(
    caches
      .keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              return (
                cacheName.startsWith("glimpse-media-") &&
                cacheName !== CACHE_NAME &&
                cacheName !== DYNAMIC_CACHE
              );
            })
            .map((cacheName) => {
              console.log("Service Worker: Clearing old cache:", cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        console.log("Service Worker: Claiming clients");
        return self.clients.claim(); // Take control of all clients
      })
  );
});

// Fetch event - serve from cache or network
self.addEventListener("fetch", (event) => {
  // Skip cross-origin requests
  if (!event.request.url.startsWith(self.location.origin)) {
    return;
  }

  // JSON data - network first, then cache
  if (
    event.request.url.includes("/data/") &&
    (event.request.url.endsWith(".json") || event.request.url.endsWith(".jpg"))
  ) {
    event.respondWith(networkFirstStrategy(event.request));
    return;
  }

  // HTML, CSS, and JS - cache first, then network
  event.respondWith(cacheFirstStrategy(event.request));
});

// Cache-first strategy: try cache, fall back to network
async function cacheFirstStrategy(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    // Cache successful responses for next time
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error("Fetch failed:", error);
    // If it's an HTML request, return a simple offline page
    if (request.headers.get("Accept").includes("text/html")) {
      return caches.match("/offline.html");
    }
    // For other resources, just return the error
    throw error;
  }
}

// Network-first strategy: try network, fall back to cache
async function networkFirstStrategy(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log("Network request failed, trying cache:", request.url);
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    console.error("No cached response available for:", request.url);
    throw error;
  }
}

// Simple offline fallback page
const OFFLINE_HTML = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Offline - Glimpse Media Viewer</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            background-color: #1a1a1a;
            color: #fff;
            text-align: center;
            padding: 40px 20px;
            margin: 0;
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .container {
            max-width: 500px;
        }
        h1 {
            color: #e5a00d;
            margin-bottom: 20px;
        }
        p {
            font-size: 18px;
            line-height: 1.6;
            margin-bottom: 30px;
        }
        .icon {
            font-size: 64px;
            margin-bottom: 30px;
        }
        button {
            background-color: #e5a00d;
            color: #000;
            border: none;
            padding: 12px 20px;
            border-radius: 24px;
            font-weight: bold;
            cursor: pointer;
            font-size: 16px;
            transition: background-color 0.3s;
        }
        button:hover {
            background-color: #f1b020;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📶</div>
        <h1>You're Offline</h1>
        <p>It looks like you're not connected to the internet. Glimpse Media Viewer needs a connection to show your Plex content.</p>
        <button onclick="window.location.reload()">Try Again</button>
    </div>
</body>
</html>
`;

// Create offline page on install
self.addEventListener("install", (event) => {
  const offlineRequest = new Request("/offline.html");
  event.waitUntil(
    fetch(offlineRequest)
      .catch(() => {
        return new Response(OFFLINE_HTML, {
          headers: { "Content-Type": "text/html" },
        });
      })
      .then((response) => {
        return caches.open(CACHE_NAME).then((cache) => {
          return cache.put(offlineRequest, response);
        });
      })
  );
});
